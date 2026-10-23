--!strict
-- src/server/ProjectileSystem.server.luau
-- Sistema de proyectiles de tinta con impacto, pintura y daño (Servidor)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

-- Módulos compartidos
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponData = require(Shared:WaitForChild("WeaponData"))
local InkPainter = require(Shared:WaitForChild("InkPainter"))
local InkSystem = require(Shared:WaitForChild("InkSystem"))
local TeamColors = require(Shared:WaitForChild("TeamColors"))
local RemotesModule = require(Shared:WaitForChild("Remotes"))

RemotesModule.InitServer()
local fireEvent = RemotesModule.Get("FireWeapon")
local hitMarkerEvent = RemotesModule.Get("HitMarker")
local inkUpdateEvent = RemotesModule.Get("InkUpdate")

-- ====================================================================
-- TANQUES DE TINTA POR JUGADOR (Lado Servidor)
-- ====================================================================
local playerInkTanks: { [Player]: any } = {}

local function getOrCreateInkTank(player: Player)
	if not playerInkTanks[player] then
		playerInkTanks[player] = InkSystem.new()
	end
	return playerInkTanks[player]
end

Players.PlayerRemoving:Connect(function(player)
	playerInkTanks[player] = nil
end)

-- Recarga pasiva de tinta (cada frame de servidor)
RunService.Heartbeat:Connect(function(dt: number)
	for player, tank in playerInkTanks do
		if not player.Parent then continue end

		local char = player.Character
		local isShark = if char then (char:GetAttribute("IsSharkMode") == true) else false

		local prevPct = math.floor(tank:GetPercentage())
		tank:Update(dt, isShark)
		local newPct = math.floor(tank:GetPercentage())

		-- Solo notificar al cliente si cambió al menos 1%
		if newPct ~= prevPct then
			(inkUpdateEvent :: RemoteEvent):FireClient(player, tank:GetInk(), tank:GetMaxInk())
		end
	end
end)

-- ====================================================================
-- CONFIGURACIÓN DE PROYECTILES
-- ====================================================================
local GRAVITY = Vector3.new(0, -60, 0)  -- Gravedad personalizada para arco de tinta
local PROJECTILE_LIFETIME = 3.0

-- Raycast params genéricos (excluir carpeta de tinta y personajes al disparar)
local function createProjectileRayParams(shooter: Model?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}

	local inkFolder = workspace:FindFirstChild("InkSplats")
	if inkFolder then table.insert(exclude, inkFolder) end
	if shooter then table.insert(exclude, shooter) end

	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	return params
end

-- ====================================================================
-- DISPARO DE PROYECTIL (Tipo Shooter - Lanzatintas)
-- ====================================================================
local function fireShooterProjectile(
	player: Player,
	origin: Vector3,
	direction: Vector3,
	weaponStats: WeaponData.WeaponStats,
	teamId: string
)
	local inkColor = TeamColors.GetColor(teamId)
	local character = player.Character
	local rayParams = createProjectileRayParams(character)

	-- Añadir dispersión aleatoria (spread)
	local spreadRad = math.rad(weaponStats.spread)
	local rx = (math.random() - 0.5) * 2 * spreadRad
	local ry = (math.random() - 0.5) * 2 * spreadRad
	local spreadDir = CFrame.new(Vector3.zero, direction) * CFrame.Angles(rx, ry, 0)
	local finalDir = spreadDir.LookVector

	-- Crear la gota de tinta (Part esférica)
	local projectile = Instance.new("Part")
	projectile.Name = "InkProjectile"
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(0.8, 0.8, 0.8)
	projectile.Material = Enum.Material.Neon
	projectile.Color = inkColor
	projectile.CanCollide = false
	projectile.CanTouch = false
	projectile.CanQuery = false
	projectile.CastShadow = false
	projectile.Anchored = false
	projectile.Massless = true
	projectile.Position = origin
	projectile.Parent = workspace

	-- Trail visual de la gota
	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, 0, 0.2)
	att0.Parent = projectile

	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, 0, -0.2)
	att1.Parent = projectile

	local trail = Instance.new("Trail")
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Lifetime = 0.15
	trail.MinLength = 0.05
	trail.Color = ColorSequence.new(inkColor)
	trail.LightEmission = 0.6
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = projectile

	-- Luz puntual
	local pLight = Instance.new("PointLight")
	pLight.Range = 6
	pLight.Brightness = 2
	pLight.Color = inkColor
	pLight.Parent = projectile

	-- Física: Velocidad inicial + gravedad simulada
	local velocity = finalDir * weaponStats.projectileSpeed
	local startTime = os.clock()
	local startPos = origin
	local hit = false

	-- Usar Heartbeat para simular el vuelo del proyectil con gravedad
	local moveConn: RBXScriptConnection
	moveConn = RunService.Heartbeat:Connect(function(dt: number)
		if hit then return end

		local elapsed = os.clock() - startTime

		-- Verificar tiempo de vida
		if elapsed > PROJECTILE_LIFETIME then
			hit = true
			moveConn:Disconnect()
			projectile:Destroy()
			return
		end

		-- Calcular nueva posición con gravedad
		local currentVel = velocity + GRAVITY * elapsed
		local newPos = startPos + velocity * elapsed + 0.5 * GRAVITY * elapsed * elapsed

		-- Raycast entre posición anterior y nueva para detectar impacto
		local prevPos = projectile.Position
		local moveDir = newPos - prevPos
		local moveDist = moveDir.Magnitude

		if moveDist > 0.05 then
			local rayResult = workspace:Raycast(prevPos, moveDir.Unit * (moveDist + 0.5), rayParams)

			if rayResult then
				hit = true
				moveConn:Disconnect()

				-- ¡PINTAR la superficie!
				InkPainter.Paint(
					rayResult.Position,
					rayResult.Normal,
					teamId,
					inkColor,
					weaponStats.paintRadius
				)

				-- Verificar daño a jugadores enemigos
				local hitPart = rayResult.Instance
				local hitCharacter = hitPart:FindFirstAncestorOfClass("Model")
				if hitCharacter then
					local hitHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
					local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
					if hitHumanoid and hitPlayer and hitPlayer ~= player then
						local hitTeam = hitPlayer:GetAttribute("Team")
						if hitTeam ~= teamId then
							hitHumanoid:TakeDamage(weaponStats.damage);
							-- Notificar al shooter que acertó
							(hitMarkerEvent :: RemoteEvent):FireClient(player, "hit", weaponStats.damage)
						end
					end
				end

				-- Efecto de impacto (partículas de salpicadura)
				local splashAtt = Instance.new("Attachment")
				splashAtt.WorldPosition = rayResult.Position
				splashAtt.Parent = workspace.Terrain

				local splashEmitter = Instance.new("ParticleEmitter")
				splashEmitter.Rate = 0
				splashEmitter.Speed = NumberRange.new(4, 10)
				splashEmitter.SpreadAngle = Vector2.new(50, 50)
				splashEmitter.Lifetime = NumberRange.new(0.2, 0.4)
				splashEmitter.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.6),
					NumberSequenceKeypoint.new(1, 0),
				})
				splashEmitter.Color = ColorSequence.new(inkColor)
				splashEmitter.LightEmission = 0.7
				splashEmitter.Parent = splashAtt
				splashEmitter:Emit(10)

				Debris:AddItem(splashAtt, 0.6)
				projectile:Destroy()
				return
			end
		end

		-- Mover proyectil
		projectile.CFrame = CFrame.new(newPos, newPos + currentVel.Unit)
	end)

	Debris:AddItem(projectile, PROJECTILE_LIFETIME + 0.5)
end

-- ====================================================================
-- DISPARO DE PROYECTIL (Tipo Charger - Francotirador)
-- ====================================================================
local function fireChargerProjectile(
	player: Player,
	origin: Vector3,
	direction: Vector3,
	weaponStats: WeaponData.WeaponStats,
	teamId: string,
	chargePercent: number
)
	local inkColor = TeamColors.GetColor(teamId)
	local character = player.Character
	local rayParams = createProjectileRayParams(character)

	-- Dispersión reducida según carga
	local spreadRad = math.rad(weaponStats.spread * (1.2 - chargePercent))
	local rx = (math.random() - 0.5) * 2 * spreadRad
	local ry = (math.random() - 0.5) * 2 * spreadRad
	local spreadDir = CFrame.new(Vector3.zero, direction) * CFrame.Angles(rx, ry, 0)
	local finalDir = spreadDir.LookVector

	-- Daño interpolado según porcentaje de carga
	local damage = (weaponStats.minDamage or weaponStats.damage)
		+ ((weaponStats.maxDamage or weaponStats.damage) - (weaponStats.minDamage or weaponStats.damage)) * chargePercent

	-- Alcance interpolado
	local range = weaponStats.range * (0.3 + 0.7 * chargePercent)

	-- Raycast instantáneo (hitscan) a lo largo del rayo de disparo
	local rayResult = workspace:Raycast(origin, finalDir * range, rayParams)
	local endPos = if rayResult then rayResult.Position else (origin + finalDir * range)

	-- Crear efecto visual del rayo láser de tinta
	local beamPart = Instance.new("Part")
	beamPart.Name = "ChargerBeam"
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.CanTouch = false
	beamPart.CanQuery = false
	beamPart.CastShadow = false
	beamPart.Material = Enum.Material.Neon
	beamPart.Color = inkColor
	beamPart.Transparency = 0.3

	local beamLength = (endPos - origin).Magnitude
	beamPart.Size = Vector3.new(0.3 + chargePercent * 0.4, 0.3 + chargePercent * 0.4, beamLength)
	beamPart.CFrame = CFrame.lookAt(origin, endPos) * CFrame.new(0, 0, -beamLength / 2)
	beamPart.Parent = workspace

	local beamLight = Instance.new("PointLight")
	beamLight.Range = 12
	beamLight.Brightness = 4
	beamLight.Color = inkColor
	beamLight.Parent = beamPart

	-- Desaparecer el rayo gradualmente
	task.spawn(function()
		for i = 1, 8 do
			task.wait(0.03)
			beamPart.Transparency = 0.3 + (i / 8) * 0.7
		end
		beamPart:Destroy()
	end)

	-- Pintar línea de tinta a lo largo del rayo
	local paintRadius = weaponStats.paintRadius * (0.4 + 0.6 * chargePercent)
	InkPainter.PaintLine(origin, endPos, teamId, inkColor, paintRadius)

	-- Si impactó algo
	if rayResult then
		-- Pintar zona de impacto
		InkPainter.Paint(rayResult.Position, rayResult.Normal, teamId, inkColor, paintRadius * 1.5)

		-- Daño a enemigos
		local hitPart = rayResult.Instance
		local hitCharacter = hitPart:FindFirstAncestorOfClass("Model")
		if hitCharacter then
			local hitHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
			local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
			if hitHumanoid and hitPlayer and hitPlayer ~= player then
				local hitTeam = hitPlayer:GetAttribute("Team")
				if hitTeam ~= teamId then
					hitHumanoid:TakeDamage(damage);
					(hitMarkerEvent :: RemoteEvent):FireClient(player, "kill", damage)
				end
			end
		end

		-- Efecto de impacto
		local splashAtt = Instance.new("Attachment")
		splashAtt.WorldPosition = rayResult.Position
		splashAtt.Parent = workspace.Terrain

		local splashEmitter = Instance.new("ParticleEmitter")
		splashEmitter.Rate = 0
		splashEmitter.Speed = NumberRange.new(6, 16)
		splashEmitter.SpreadAngle = Vector2.new(60, 60)
		splashEmitter.Lifetime = NumberRange.new(0.3, 0.5)
		splashEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.0),
			NumberSequenceKeypoint.new(1, 0),
		})
		splashEmitter.Color = ColorSequence.new(inkColor)
		splashEmitter.LightEmission = 0.8
		splashEmitter.Parent = splashAtt
		splashEmitter:Emit(20)
		Debris:AddItem(splashAtt, 0.7)
	end
end

-- ====================================================================
-- ESCUCHA DE DISPAROS DESDE LOS CLIENTES
-- ====================================================================
-- Anti-spam: Cooldown por jugador
local playerCooldowns: { [Player]: number } = {};

(fireEvent :: RemoteEvent).OnServerEvent:Connect(function(
	player: Player,
	weaponId: any,
	originVec: any,
	directionVec: any,
	chargePercent: any
)
	-- Validaciones de seguridad
	if typeof(weaponId) ~= "string" then return end
	if typeof(originVec) ~= "Vector3" then return end
	if typeof(directionVec) ~= "Vector3" then return end

	local weapon = WeaponData.Get(weaponId)
	if not weapon then return end

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- Validar que el origen no esté demasiado lejos del jugador (anti-exploit)
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end
	if (originVec - rootPart.Position).Magnitude > 15 then return end

	-- Verificar cooldown
	local now = os.clock()
	local lastFire = playerCooldowns[player] or 0
	if (now - lastFire) < weapon.cooldown * 0.8 then return end -- 80% para lag tolerance
	playerCooldowns[player] = now

	-- Equipo del jugador
	local teamId = player:GetAttribute("Team") :: string?
	if not teamId then return end

	-- Consumir tinta
	local inkTank = getOrCreateInkTank(player)
	local inkCost = weapon.inkCost
	if weapon.requiresCharge and typeof(chargePercent) == "number" then
		inkCost = weapon.inkCost * math.clamp(chargePercent, 0.2, 1.0)
	end

	if not inkTank:Consume(inkCost) then
		-- Sin tinta: notificar al cliente
		(inkUpdateEvent :: RemoteEvent):FireClient(player, inkTank:GetInk(), inkTank:GetMaxInk())
		return
	end

	-- Notificar tinta actualizada
	(inkUpdateEvent :: RemoteEvent):FireClient(player, inkTank:GetInk(), inkTank:GetMaxInk())

	-- Disparar según el tipo de arma
	local direction = directionVec.Unit

	if weapon.category == "Charger" then
		local charge = if typeof(chargePercent) == "number" then math.clamp(chargePercent, 0, 1) else 0.3
		fireChargerProjectile(player, originVec, direction, weapon, teamId, charge)
	else
		fireShooterProjectile(player, originVec, direction, weapon, teamId)
	end
end)

-- Limpiar cooldowns al salir
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player] = nil
end)

print("[ProjectileSystem] 🎯 Sistema de proyectiles y pintura inicializado.")

