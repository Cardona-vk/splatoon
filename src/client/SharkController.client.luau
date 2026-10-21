--!strict
-- src/client/SharkController.client.luau
-- Controlador de Movimiento y Transformación al Homúnculo de Tinta (Sin Parpadeo)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local localPlayer = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid
local rootPart: BasePart = character:WaitForChild("HumanoidRootPart") :: BasePart

-- Parámetros de Configuración del Modo Tiburón
local NORMAL_SPEED = 16
local SHARK_SPEED = 34
local RAYCAST_DISTANCE = 5.0

-- Estado interno
local isInSharkMode = false
local playerTeam = localPlayer:GetAttribute("Team") or "TeamA"

-- Paleta de colores de tinta por equipo
local TEAM_INK_COLORS: { [string]: Color3 } = {
	["TeamA"] = Color3.fromRGB(0, 220, 255),    -- Cian Eléctrico
	["TeamB"] = Color3.fromRGB(255, 120, 0),    -- Naranja Coral
}

-- Almacén permanente de transparencias originales (capturadas una sola vez)
local defaultTransparencies: { [BasePart]: number } = {}
local defaultDecalTransparencies: { [Decal]: number } = {}

local activeHomunculus: Model? = nil
local animationConnection: RBXScriptConnection? = nil

-- Configuración de Raycast para detectar el suelo
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function updateRaycastFilter()
	if character then
		raycastParams.FilterDescendantsInstances = { character }
	end
end
updateRaycastFilter()

-- Captura las transparencias originales del personaje al aparecer
local function cacheCharacterTransparencies(char: Model)
	table.clear(defaultTransparencies)
	table.clear(defaultDecalTransparencies)

	for _, desc in char:GetDescendants() do
		if desc:IsA("BasePart") then
			if desc.Name == "HumanoidRootPart" then
				defaultTransparencies[desc] = 1
			else
				-- Solo guardar si no estaba ya oculto por error
				defaultTransparencies[desc] = if desc.Transparency < 1 then desc.Transparency else 0
			end
		elseif desc:IsA("Decal") then
			defaultDecalTransparencies[desc] = if desc.Transparency < 1 then desc.Transparency else 0
		end
	end
end

-- Capturar estado inicial
cacheCharacterTransparencies(character)

-- También capturar accesorios que carguen después
character.DescendantAdded:Connect(function(desc)
	if activeHomunculus and desc:IsDescendantOf(activeHomunculus) then
		return
	end
	if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
		if defaultTransparencies[desc] == nil then
			defaultTransparencies[desc] = 0
		end
		if isInSharkMode then
			desc.Transparency = 1
		end
	elseif desc:IsA("Decal") then
		if defaultDecalTransparencies[desc] == nil then
			defaultDecalTransparencies[desc] = 0
		end
		if isInSharkMode then
			desc.Transparency = 1
		end
	end
end)

local function getCurrentInkColor(): Color3
	return TEAM_INK_COLORS[tostring(playerTeam)] or Color3.fromRGB(0, 220, 255)
end

-- ====================================================================
-- DETECCIÓN DE TINTA AMIGA (Raycast Seguro)
-- ====================================================================
local function isStandingOnOwnTeamInk(): boolean
	if not rootPart or not character then
		return false
	end

	local origin = rootPart.Position
	local direction = Vector3.new(0, -RAYCAST_DISTANCE, 0)
	local result = workspace:Raycast(origin, direction, raycastParams)

	if not result or not result.Instance then
		return false
	end

	local hitPart = result.Instance

	-- 1. Atributo "InkTeam"
	local partTeam = hitPart:GetAttribute("InkTeam")
	if partTeam and partTeam == playerTeam then
		return true
	end

	-- 2. Tag de CollectionService
	if CollectionService:HasTag(hitPart, "Ink_" .. tostring(playerTeam)) then
		return true
	end

	-- 3. Modo compatibilidad / pruebas
	if hitPart:GetAttribute("FriendlyInk") == true then
		return true
	end

	return false
end

-- ====================================================================
-- EFECTOS DE SALPICADURA (Sin crear Parts para evitar colisiones con el raycast)
-- ====================================================================
local function playSplashEffect(position: Vector3, isEnter: boolean)
	local inkColor = getCurrentInkColor()

	-- Usamos un Attachment en Terrain para que NUNCA interfiera con el raycast de suelo
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain

	local splashEmitter = Instance.new("ParticleEmitter")
	splashEmitter.Rate = 0
	splashEmitter.Speed = NumberRange.new(if isEnter then 6 else 10, if isEnter then 12 else 18)
	splashEmitter.SpreadAngle = Vector2.new(45, 45)
	splashEmitter.Lifetime = NumberRange.new(0.3, 0.5)
	splashEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	splashEmitter.Color = ColorSequence.new(inkColor)
	splashEmitter.LightEmission = 0.8
	splashEmitter.Parent = attachment

	splashEmitter:Emit(if isEnter then 25 else 32)
	Debris:AddItem(attachment, 0.8)

	-- Sonido acuático
	local sound = Instance.new("Sound")
	sound.SoundId = if isEnter then "rbxassetid://131237241" else "rbxassetid://2801263"
	sound.Volume = 0.85
	sound.PlaybackSpeed = if isEnter then 1.25 else 1.15
	sound.Parent = rootPart
	sound:Play()
	Debris:AddItem(sound, 1.2)
end

-- ====================================================================
-- CREACIÓN DEL HOMÚNCULO DE TINTA (Con CanQuery = false para no bloquear Raycasts)
-- ====================================================================
local function createInkHomunculus(): Model
	local inkColor = getCurrentInkColor()

	local model = Instance.new("Model")
	model.Name = "InkHomunculus"

	local function setupNonCollidable(part: BasePart)
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false -- Impide que cualquier Raycast golpee esta pieza
		part.Massless = true
		part.CastShadow = false
	end

	-- 1. Cuerpo Principal
	local body = Instance.new("Part")
	body.Name = "HomunculusBody"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2.4, 1.8, 3.2)
	body.Material = Enum.Material.SmoothPlastic
	body.Color = inkColor
	setupNonCollidable(body)

	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 2.5
	light.Color = inkColor
	light.Parent = body

	-- 2. Aleta dorsal
	local fin = Instance.new("Part")
	fin.Name = "DorsalFin"
	fin.Size = Vector3.new(0.35, 1.3, 1.5)
	fin.Material = Enum.Material.SmoothPlastic
	fin.Color = inkColor
	setupNonCollidable(fin)

	local finMesh = Instance.new("SpecialMesh")
	finMesh.MeshType = Enum.MeshType.Wedge
	finMesh.Scale = Vector3.new(0.35, 1.1, 1.3)
	finMesh.Parent = fin

	local finWeld = Instance.new("Weld")
	finWeld.Part0 = body
	finWeld.Part1 = fin
	finWeld.C0 = CFrame.new(0, 0.9, -0.2) * CFrame.Angles(0, math.rad(180), 0)
	finWeld.Parent = fin
	fin.Parent = model

	-- 3. Cola articulada
	local tail = Instance.new("Part")
	tail.Name = "SharkTail"
	tail.Size = Vector3.new(0.3, 1.1, 1.4)
	tail.Material = Enum.Material.SmoothPlastic
	tail.Color = inkColor
	setupNonCollidable(tail)

	local tailMesh = Instance.new("SpecialMesh")
	tailMesh.MeshType = Enum.MeshType.Wedge
	tailMesh.Scale = Vector3.new(0.3, 1.0, 1.2)
	tailMesh.Parent = tail

	local tailMotor = Instance.new("Motor6D")
	tailMotor.Name = "TailMotor"
	tailMotor.Part0 = body
	tailMotor.Part1 = tail
	tailMotor.C0 = CFrame.new(0, 0.2, 1.6)
	tailMotor.Parent = body
	tail.Parent = model

	-- 4. Ojos caricaturescos
	local function createEye(offset: Vector3): Part
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.55, 0.55, 0.55)
		eye.Material = Enum.Material.SmoothPlastic
		eye.Color = Color3.fromRGB(255, 255, 255)
		setupNonCollidable(eye)

		local pupil = Instance.new("Part")
		pupil.Name = "Pupil"
		pupil.Shape = Enum.PartType.Ball
		pupil.Size = Vector3.new(0.28, 0.28, 0.28)
		pupil.Material = Enum.Material.SmoothPlastic
		pupil.Color = Color3.fromRGB(15, 15, 20)
		setupNonCollidable(pupil)

		local pupilWeld = Instance.new("WeldConstraint")
		pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -0.18)
		pupilWeld.Part0 = eye
		pupilWeld.Part1 = pupil
		pupilWeld.Parent = pupil
		pupil.Parent = eye

		local eyeWeld = Instance.new("Weld")
		eyeWeld.Part0 = body
		eyeWeld.Part1 = eye
		eyeWeld.C0 = CFrame.new(offset.X, offset.Y, offset.Z)
		eyeWeld.Parent = eye
		eye.Parent = model

		return eye
	end

	createEye(Vector3.new(0.55, 0.45, -0.9))
	createEye(Vector3.new(-0.55, 0.45, -0.9))

	-- 5. Partículas de estela al nadar
	local trailEmitter = Instance.new("ParticleEmitter")
	trailEmitter.Name = "SwimInkTrail"
	trailEmitter.Rate = 30
	trailEmitter.Speed = NumberRange.new(2, 4)
	trailEmitter.SpreadAngle = Vector2.new(30, 30)
	trailEmitter.Lifetime = NumberRange.new(0.35, 0.6)
	trailEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.0),
		NumberSequenceKeypoint.new(1, 0),
	})
	trailEmitter.Color = ColorSequence.new(inkColor)
	trailEmitter.LightEmission = 0.8
	trailEmitter.Parent = body

	-- 6. Soldar al personaje
	local rootWeld = Instance.new("Motor6D")
	rootWeld.Name = "HomunculusRootMotor"
	rootWeld.Part0 = rootPart
	rootWeld.Part1 = body
	rootWeld.C0 = CFrame.new(0, -1.8, 0)
	rootWeld.Parent = body

	body.Parent = model
	model.Parent = character

	return model
end

-- ====================================================================
-- GESTIÓN DE VISIBILIDAD GARANTIZADA DEL PERSONAJE
-- ====================================================================
local function setCharacterSubmerged(submerged: boolean)
	if not character then return end

	for _, desc in character:GetDescendants() do
		-- Ignorar partes del homúnculo
		if activeHomunculus and desc:IsDescendantOf(activeHomunculus) then
			continue
		end

		if desc:IsA("BasePart") then
			if desc.Name == "HumanoidRootPart" then
				desc.Transparency = 1
			else
				-- Restaurar exactamente su transparencia predeterminada (por defecto 0)
				desc.Transparency = if submerged then 1 else (defaultTransparencies[desc] or 0)
			end
		elseif desc:IsA("Decal") then
			desc.Transparency = if submerged then 1 else (defaultDecalTransparencies[desc] or 0)
		end
	end
end

-- ====================================================================
-- ACTIVACIÓN Y DESACTIVACIÓN DEL MODO TIBURÓN
-- ====================================================================
local function enterSharkMode()
	if isInSharkMode then return end
	isInSharkMode = true

	-- Efecto de salpicadura y sonido
	playSplashEffect(rootPart.Position - Vector3.new(0, 2, 0), true)

	-- 1. Aumentar velocidad
	humanoid.WalkSpeed = SHARK_SPEED

	-- 2. Crear Homúnculo y ocultar humanoide
	activeHomunculus = createInkHomunculus()
	setCharacterSubmerged(true)

	-- 3. Animación de natación en vivo
	local startTime = os.clock()
	if animationConnection then
		animationConnection:Disconnect()
	end

	animationConnection = RunService.RenderStepped:Connect(function()
		if not activeHomunculus or not rootPart or not character then return end

		local currentBody = activeHomunculus:FindFirstChild("HomunculusBody") :: BasePart?
		local tailMotor = currentBody and currentBody:FindFirstChild("TailMotor") :: Motor6D?
		local rootMotor = currentBody and currentBody:FindFirstChild("HomunculusRootMotor") :: Motor6D?

		if not currentBody or not rootMotor then return end

		local elapsed = os.clock() - startTime
		local velocity = rootPart.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local isMoving = speed > 1.5

		if isMoving then
			local swimFreq = 16
			local tailAngle = math.sin(elapsed * swimFreq) * math.rad(28)
			local bodyRoll = math.sin(elapsed * swimFreq) * math.rad(6)
			local bodyBob = math.abs(math.cos(elapsed * swimFreq)) * 0.15

			if tailMotor then
				tailMotor.C1 = CFrame.Angles(0, tailAngle, 0)
			end

			rootMotor.C0 = CFrame.new(0, -1.8 + bodyBob, 0) * CFrame.Angles(math.rad(-8), 0, bodyRoll)
		else
			local breathe = math.sin(elapsed * 4) * 0.08
			if tailMotor then
				tailMotor.C1 = CFrame.Angles(0, math.sin(elapsed * 3) * math.rad(8), 0)
			end

			rootMotor.C0 = CFrame.new(0, -1.8 + breathe, 0)
		end
	end)

	character:SetAttribute("IsSharkMode", true)
end

local function exitSharkMode()
	if not isInSharkMode then return end
	isInSharkMode = false

	-- Detener animación
	if animationConnection then
		animationConnection:Disconnect()
		animationConnection = nil
	end

	-- Salpicadura de salida
	playSplashEffect(rootPart.Position - Vector3.new(0, 2, 0), false)

	-- 1. Restaurar velocidad
	humanoid.WalkSpeed = NORMAL_SPEED

	-- 2. Restaurar aspecto del personaje PRIMERO (antes de destruir el modelo)
	setCharacterSubmerged(false)

	-- 3. Eliminar modelo del homúnculo
	if activeHomunculus then
		activeHomunculus:Destroy()
		activeHomunculus = nil
	end

	character:SetAttribute("IsSharkMode", false)
end

-- ====================================================================
-- BUCLE PRINCIPAL (Comprobación Real de Teclado y Tinta)
-- ====================================================================
RunService.Heartbeat:Connect(function()
	if not character or not humanoid or humanoid.Health <= 0 then
		if isInSharkMode then
			exitSharkMode()
		end
		return
	end

	-- Comprobación directa del estado físico de la tecla Shift Izquierdo
	local isHoldingShift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)

	if isHoldingShift then
		local onInk = isStandingOnOwnTeamInk()
		if onInk and not isInSharkMode then
			enterSharkMode()
		elseif not onInk and isInSharkMode then
			exitSharkMode()
		end
	else
		-- Si no se está presionando Shift, bajo NINGÚN motivo debe estar en Shark Mode
		if isInSharkMode then
			exitSharkMode()
		end
	end
end)

-- ====================================================================
-- GESTIÓN DE RESPAWN DEL PERSONAJE
-- ====================================================================
local function onCharacterAdded(newCharacter: Model)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	rootPart = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	isInSharkMode = false

	if animationConnection then
		animationConnection:Disconnect()
		animationConnection = nil
	end
	if activeHomunculus then
		activeHomunculus:Destroy()
		activeHomunculus = nil
	end

	updateRaycastFilter()
	task.wait(0.2) -- Pequeño margen para que carguen accesorios de avatar
	cacheCharacterTransparencies(newCharacter)
	setCharacterSubmerged(false)
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)

localPlayer:GetAttributeChangedSignal("Team"):Connect(function()
	playerTeam = localPlayer:GetAttribute("Team") or "TeamA"
end)

print("[SharkController] ✅ Sistema de Homúnculo estabilizado sin parpadeo.")
