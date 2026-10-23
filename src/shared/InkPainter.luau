--!strict
-- src/shared/InkPainter.luau
-- Sistema de pintado de superficies con tinta (estilo Splatoon)
-- Crea manchas de tinta en el suelo/paredes al impactar proyectiles.
-- Las manchas llevan el atributo "InkTeam" para que SharkController las detecte.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local InkPainter = {}

-- Carpeta contenedora de todas las manchas de tinta en Workspace
local INK_FOLDER_NAME = "InkSplats"

-- Configuración visual de las manchas
local SPLAT_THICKNESS = 0.12         -- Grosor de la mancha (muy delgada)
local SPLAT_LIFETIME = 0             -- 0 = permanente hasta fin de ronda
local MAX_SPLATS = 3000              -- Límite global para rendimiento
local OVERLAP_CLEANUP_RADIUS = 1.8   -- Radio mínimo para limpiar manchas solapadas del mismo equipo
local RANDOM_SCALE_MIN = 0.7         -- Factor mínimo de escala aleatoria
local RANDOM_SCALE_MAX = 1.3         -- Factor máximo de escala aleatoria

-- Obtener o crear la carpeta de manchas de tinta
local function getInkFolder(): Folder
	local folder = workspace:FindFirstChild(INK_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = INK_FOLDER_NAME
		folder.Parent = workspace
	end
	return folder :: Folder
end

-- Contar manchas actuales
local function getSplatCount(): number
	local folder = getInkFolder()
	return #folder:GetChildren()
end

-- Eliminar las manchas más antiguas si se excede el límite
local function enforceMaxSplats()
	local folder = getInkFolder()
	local children = folder:GetChildren()
	local excess = #children - MAX_SPLATS

	if excess > 0 then
		-- Ordenar por tiempo de creación (las más antiguas primero)
		table.sort(children, function(a, b)
			local timeA = a:GetAttribute("CreatedAt") or 0
			local timeB = b:GetAttribute("CreatedAt") or 0
			return timeA < timeB
		end)

		for i = 1, math.min(excess + 50, #children) do -- Eliminar un lote extra para no llamar cada frame
			children[i]:Destroy()
		end
	end
end

-- Limpiar manchas enemigas cercanas (sobreescritura de territorio)
local function overwriteEnemyInk(position: Vector3, radius: number, teamId: string)
	local folder = getInkFolder()
	local radiusSq = radius * radius

	for _, splat in folder:GetChildren() do
		if not splat:IsA("BasePart") then continue end

		local splatTeam = splat:GetAttribute("InkTeam")
		if splatTeam == teamId then continue end -- No tocar las del mismo equipo

		local distSq = (splat.Position - position).Magnitude ^ 2
		if distSq < radiusSq then
			splat:Destroy()
		end
	end
end

-- ====================================================================
-- CREAR MANCHA PRINCIPAL DE TINTA
-- ====================================================================
function InkPainter.Paint(
	position: Vector3,
	normal: Vector3,
	teamId: string,
	inkColor: Color3,
	radius: number
)
	-- Limpiar exceso si es necesario
	if getSplatCount() >= MAX_SPLATS then
		enforceMaxSplats()
	end

	local folder = getInkFolder()

	-- Sobreescribir tinta enemiga cercana
	overwriteEnemyInk(position, radius * 1.2, teamId)

	-- 1. Mancha central grande
	local scale = RANDOM_SCALE_MIN + math.random() * (RANDOM_SCALE_MAX - RANDOM_SCALE_MIN)
	local diameter = radius * 2 * scale

	local splat = Instance.new("Part")
	splat.Name = "InkSplat"
	splat.Shape = Enum.PartType.Cylinder
	splat.Anchored = true
	splat.CanCollide = false
	splat.CanTouch = false
	splat.CanQuery = true   -- Los Raycasts del SharkController SÍ deben detectarlas
	splat.CastShadow = false
	splat.Material = Enum.Material.SmoothPlastic
	splat.Color = inkColor
	splat.TopSurface = Enum.SurfaceType.Smooth
	splat.BottomSurface = Enum.SurfaceType.Smooth

	-- Orientar el cilindro a lo largo de la normal de la superficie
	-- El cilindro de Roblox está orientado en el eje X por defecto
	local upVector = if math.abs(normal.Y) > 0.95 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local right = normal:Cross(upVector).Unit
	local forward = right:Cross(normal).Unit

	-- Rotar el cilindro para que su eje (X) se alinee con la normal de la superficie
	splat.Size = Vector3.new(SPLAT_THICKNESS, diameter, diameter)
	splat.CFrame = CFrame.fromMatrix(
		position + normal * (SPLAT_THICKNESS * 0.5),
		normal,
		forward
	)

	-- Atributos para detección de equipo y limpieza
	splat:SetAttribute("InkTeam", teamId)
	splat:SetAttribute("CreatedAt", os.clock())
	CollectionService:AddTag(splat, "Ink_" .. teamId)
	CollectionService:AddTag(splat, "InkSplat")

	if SPLAT_LIFETIME > 0 then
		Debris:AddItem(splat, SPLAT_LIFETIME)
	end

	splat.Parent = folder

	-- 2. Salpicaduras satélite menores (2-4 gotas alrededor)
	local numDroplets = math.random(2, 4)
	for i = 1, numDroplets do
		local angle = math.random() * math.pi * 2
		local dist = radius * (0.6 + math.random() * 0.8)
		local dropletScale = 0.3 + math.random() * 0.4

		-- Calcular posición del satélite en el plano de la superficie
		local offset = right * (math.cos(angle) * dist) + forward * (math.sin(angle) * dist)
		local dropletPos = position + offset

		-- Verificar que el satélite toque una superficie sólida (no flotar en el aire)
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = { workspace }

		-- Lanzar un ray corto a lo largo de -normal para encontrar suelo cercano
		local checkRay = workspace:Raycast(dropletPos + normal * 2, -normal * 4, rayParams)
		if not checkRay then continue end

		local droplet = Instance.new("Part")
		droplet.Name = "InkDroplet"
		droplet.Shape = Enum.PartType.Cylinder
		droplet.Anchored = true
		droplet.CanCollide = false
		droplet.CanTouch = false
		droplet.CanQuery = true
		droplet.CastShadow = false
		droplet.Material = Enum.Material.SmoothPlastic
		droplet.Color = inkColor
		droplet.TopSurface = Enum.SurfaceType.Smooth
		droplet.BottomSurface = Enum.SurfaceType.Smooth

		local dropDiameter = radius * dropletScale * 2
		droplet.Size = Vector3.new(SPLAT_THICKNESS, dropDiameter, dropDiameter)
		droplet.CFrame = CFrame.fromMatrix(
			checkRay.Position + checkRay.Normal * (SPLAT_THICKNESS * 0.5),
			checkRay.Normal,
			forward
		)

		droplet:SetAttribute("InkTeam", teamId)
		droplet:SetAttribute("CreatedAt", os.clock())
		CollectionService:AddTag(droplet, "Ink_" .. teamId)
		CollectionService:AddTag(droplet, "InkSplat")

		if SPLAT_LIFETIME > 0 then
			Debris:AddItem(droplet, SPLAT_LIFETIME)
		end

		droplet.Parent = folder
	end
end

-- ====================================================================
-- PINTAR LÍNEA DE TINTA (Para el Francotirador / estela de disparo)
-- ====================================================================
function InkPainter.PaintLine(
	startPos: Vector3,
	endPos: Vector3,
	teamId: string,
	inkColor: Color3,
	radius: number,
	spacing: number?
)
	local step = spacing or (radius * 1.4)
	local direction = (endPos - startPos)
	local distance = direction.Magnitude
	if distance < 0.1 then return end

	local unitDir = direction.Unit
	local numSteps = math.floor(distance / step)

	for i = 0, numSteps do
		local pos = startPos + unitDir * (i * step)

		-- Raycast hacia abajo para encontrar la superficie
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		local inkFolder = getInkFolder()
		rayParams.FilterDescendantsInstances = { inkFolder }

		local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -10, 0), rayParams)
		if hit then
			InkPainter.Paint(hit.Position, hit.Normal, teamId, inkColor, radius * (0.6 + math.random() * 0.3))
		end
	end
end

-- ====================================================================
-- LIMPIEZA TOTAL (Fin de ronda)
-- ====================================================================
function InkPainter.ClearAll()
	local folder = workspace:FindFirstChild(INK_FOLDER_NAME)
	if folder then
		folder:ClearAllChildren()
	end
end

-- ====================================================================
-- CÁLCULO DE TERRITORIO (Porcentaje de mapa cubierto por cada equipo)
-- ====================================================================
function InkPainter.CalculateTerritory(): { [string]: number }
	local folder = workspace:FindFirstChild(INK_FOLDER_NAME)
	if not folder then
		return { TeamA = 0, TeamB = 0 }
	end

	local areaTotals: { [string]: number } = {}

	for _, splat in folder:GetChildren() do
		if not splat:IsA("BasePart") then continue end

		local team = splat:GetAttribute("InkTeam")
		if not team then continue end

		-- Estimar área por la superficie del cilindro (πr²)
		local diameter = math.max(splat.Size.Y, splat.Size.Z)
		local r = diameter * 0.5
		local area = math.pi * r * r

		areaTotals[team] = (areaTotals[team] or 0) + area
	end

	local totalArea = 0
	for _, v in areaTotals do
		totalArea += v
	end

	local percentages: { [string]: number } = {}
	if totalArea > 0 then
		for team, area in areaTotals do
			percentages[team] = math.floor((area / totalArea) * 1000 + 0.5) / 10
		end
	end

	return percentages
end

return InkPainter

