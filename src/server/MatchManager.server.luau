--!strict
-- src/server/MatchManager.server.luau
-- Controlador de Rondas, Partidas, Spawns, Territorio y Efectos de Tinta Enemiga

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local InkPainter = require(Shared:WaitForChild("InkPainter"))
local TeamColors = require(Shared:WaitForChild("TeamColors"))
local RemotesModule = require(Shared:WaitForChild("Remotes"))

-- Inicializar Remotes
RemotesModule.InitServer()
local matchStateEvent = RemotesModule.Get("MatchStateUpdate")
local territoryEvent = RemotesModule.Get("TerritoryUpdate")

print("======================================================")
print("  🦈 [MatchManager] Inicializando Servidor de Partida")
print("======================================================")

-- ====================================================================
-- ASIGNACIÓN DE EQUIPOS
-- ====================================================================
local teamCounts = { TeamA = 0, TeamB = 0 }

local function assignTeam(): string
	if teamCounts.TeamA <= teamCounts.TeamB then
		teamCounts.TeamA += 1
		return "TeamA"
	else
		teamCounts.TeamB += 1
		return "TeamB"
	end
end

-- ====================================================================
-- ESTADO DE PARTIDA
-- ====================================================================
local currentState = GameConfig.GAME_STATES.INTERMISSION
local timeLeft = GameConfig.INTERMISSION_TIME
local teamScores = { TeamA = 50.0, TeamB = 50.0 }

-- ====================================================================
-- CONSTRUCCIÓN DE LA ARENA PROCEDURAL
-- ====================================================================
local function setupArena()
	print("[MatchManager] 🏗️ Construyendo arena en Workspace...")

	local existing = Workspace:FindFirstChild("BattleArena")
	if existing then existing:Destroy() end

	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "BattleArena"
	arenaFolder.Parent = Workspace

	-- 1. Suelo central de la arena
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Anchored = true
	floor.CanCollide = true
	floor.Size = Vector3.new(100, 2, 170)
	floor.Position = Vector3.new(0, 0, 0)
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = Color3.fromRGB(48, 52, 64)
	floor.Parent = arenaFolder

	-- Torre / Plataforma central elevada
	local centerTower = Instance.new("Part")
	centerTower.Name = "CenterTower"
	centerTower.Anchored = true
	centerTower.CanCollide = true
	centerTower.Size = Vector3.new(20, 5, 20)
	centerTower.Position = Vector3.new(0, 3.5, 0)
	centerTower.Material = Enum.Material.SmoothPlastic
	centerTower.Color = Color3.fromRGB(72, 78, 94)
	centerTower.Parent = arenaFolder

	-- Rampas para subir a la torre central
	local function createRamp(pos: Vector3, rotY: number)
		local ramp = Instance.new("WedgePart")
		ramp.Name = "Ramp"
		ramp.Anchored = true
		ramp.CanCollide = true
		ramp.Size = Vector3.new(14, 5, 18)
		ramp.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotY), 0)
		ramp.Material = Enum.Material.SmoothPlastic
		ramp.Color = Color3.fromRGB(62, 68, 82)
		ramp.Parent = arenaFolder
	end

	createRamp(Vector3.new(0, 3.5, 19), 0)
	createRamp(Vector3.new(0, 3.5, -19), 180)

	-- Muros de cobertura laterales
	local function createCover(pos: Vector3, size: Vector3)
		local cover = Instance.new("Part")
		cover.Name = "CoverWall"
		cover.Anchored = true
		cover.CanCollide = true
		cover.Size = size
		cover.Position = pos
		cover.Material = Enum.Material.SmoothPlastic
		cover.Color = Color3.fromRGB(58, 64, 76)
		cover.Parent = arenaFolder
	end

	createCover(Vector3.new(24, 3, 30), Vector3.new(10, 5, 16))
	createCover(Vector3.new(-24, 3, -30), Vector3.new(10, 5, 16))
	createCover(Vector3.new(-24, 3, 30), Vector3.new(10, 5, 16))
	createCover(Vector3.new(24, 3, -30), Vector3.new(10, 5, 16))

	-- 2. Spawns protegidos para cada equipo
	for teamId, config in GameConfig.TEAMS do
		local spawnPad = Instance.new("Part")
		spawnPad.Name = "Spawn_" .. teamId
		spawnPad.Anchored = true
		spawnPad.CanCollide = true
		spawnPad.Size = Vector3.new(22, 1.5, 22)
		spawnPad.Position = config.SpawnPosition - Vector3.new(0, 2, 0)
		spawnPad.Material = Enum.Material.Neon
		spawnPad.Color = config.Color
		spawnPad:SetAttribute("InkTeam", teamId)
		spawnPad:SetAttribute("FriendlyInk", true)
		spawnPad.Parent = arenaFolder

		-- Cartel flotante sobre cada base
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 260, 0, 55)
		billboard.StudsOffset = Vector3.new(0, 4, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = spawnPad

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 0.2
		label.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
		label.TextColor3 = config.Color
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = string.format("BASE %s", string.upper(config.Name))
		label.Parent = billboard
		billboard.Parent = spawnPad
	end

	print("[MatchManager] ✅ Arena procedural creada exitosamente.")
end

-- ====================================================================
-- CONTROL DE JUGADORES (Spawns, Movimiento y Salud)
-- ====================================================================
local function teleportPlayerToSpawn(player: Player)
	local teamId = player:GetAttribute("Team") :: string?
	if not teamId or not GameConfig.TEAMS[teamId] then return end

	local char = player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			local spawnPos = GameConfig.TEAMS[teamId].SpawnPosition
			root.CFrame = CFrame.lookAt(spawnPos, Vector3.new(0, spawnPos.Y, 0))
			humanoid.Health = humanoid.MaxHealth
		end
	end
end

local function teleportAllPlayersToSpawns()
	for _, player in Players:GetPlayers() do
		teleportPlayerToSpawn(player)
	end
end

local function setPlayersMovementLocked(locked: boolean)
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = if locked then 0 else 16
				humanoid.JumpPower = if locked then 0 else 50
			end
		end
	end
end

-- ====================================================================
-- EVENTOS DE JUGADORES
-- ====================================================================
local function onPlayerAdded(player: Player)
	local team = assignTeam()
	player:SetAttribute("Team", team)

	local teamConfig = TeamColors.Get(team)
	local teamName = if teamConfig then teamConfig.name else team
	print(string.format("[MatchManager] 🎮 %s asignado a: %s", player.Name, teamName))

	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		teleportPlayerToSpawn(player)

		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = if currentState == GameConfig.GAME_STATES.ACTIVE then 16 else 0
		end
	end)

	-- Enviar estado actual de partida al jugador que recién entra
	task.wait(0.5)
	matchStateEvent:FireClient(player, {
		State = currentState,
		TimeLeft = timeLeft,
		Scores = teamScores,
	})
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	onPlayerAdded(p)
end

Players.PlayerRemoving:Connect(function(player)
	local team = player:GetAttribute("Team") :: string?
	if team and teamCounts[team] then
		teamCounts[team] = math.max(0, teamCounts[team] - 1)
	end
end)

-- ====================================================================
-- PENALIZACIÓN POR TINTA ENEMIGA (Heartbeat continuo)
-- ====================================================================
local ENEMY_INK_SPEED = 7
local ENEMY_INK_DAMAGE = 8
local NORMAL_SPEED = 16
local INK_CHECK_DISTANCE = 5.0

RunService.Heartbeat:Connect(function(dt: number)
	if currentState ~= GameConfig.GAME_STATES.ACTIVE then return end

	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then continue end

		local humanoid = char:FindFirstChildOfClass("Humanoid")
		local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not rootPart or humanoid.Health <= 0 then continue end

		-- Si está en modo tiburón, SharkController gobierna su velocidad
		if char:GetAttribute("IsSharkMode") == true then continue end

		local playerTeam = player:GetAttribute("Team") :: string?
		if not playerTeam then continue end

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { char }
		rayParams.IgnoreWater = true

		local result = Workspace:Raycast(rootPart.Position, Vector3.new(0, -INK_CHECK_DISTANCE, 0), rayParams)

		if result and result.Instance then
			local splatTeam = result.Instance:GetAttribute("InkTeam")
			if splatTeam and splatTeam ~= playerTeam then
				humanoid.WalkSpeed = ENEMY_INK_SPEED
				humanoid:TakeDamage(ENEMY_INK_DAMAGE * dt)
			else
				humanoid.WalkSpeed = NORMAL_SPEED
			end
		else
			humanoid.WalkSpeed = NORMAL_SPEED
		end
	end
end)

-- ====================================================================
-- BUCLE PRINCIPAL DE PARTIDA (State Machine)
-- ====================================================================
task.spawn(function()
	-- Construir arena inmediatamente
	setupArena()

	while true do
		-- 1. FASE DE INTERMISIÓN / PREPARACIÓN
		currentState = GameConfig.GAME_STATES.INTERMISSION
		timeLeft = GameConfig.INTERMISSION_TIME
		InkPainter.ClearAll()
		teleportAllPlayersToSpawns()
		setPlayersMovementLocked(true)

		print(string.format("[MatchManager] ⏳ Nueva partida iniciando en %d segundos...", timeLeft))

		while timeLeft > 0 do
			matchStateEvent:FireAllClients({
				State = currentState,
				TimeLeft = timeLeft,
				Scores = teamScores,
			})
			task.wait(1)
			timeLeft -= 1
		end

		-- 2. FASE ACTIVA (3 MINUTOS)
		currentState = GameConfig.GAME_STATES.ACTIVE
		timeLeft = GameConfig.MATCH_DURATION
		setPlayersMovementLocked(false)

		print("[MatchManager] 🏁 ¡¡PARTIDA INICIADA!! Tiempo: 3:00")

		local territoryUpdateTimer = 0

		while timeLeft > 0 do
			matchStateEvent:FireAllClients({
				State = currentState,
				TimeLeft = timeLeft,
				Scores = teamScores,
			})

			-- Recalcular territorio cada 2 segundos
			territoryUpdateTimer += 1
			if territoryUpdateTimer >= 2 then
				territoryUpdateTimer = 0
				local currentPct = InkPainter.CalculateTerritory()
				local aScore = currentPct["TeamA"] or 0
				local bScore = currentPct["TeamB"] or 0
				local total = aScore + bScore

				if total > 0 then
					teamScores.TeamA = math.floor((aScore / total) * 1000 + 0.5) / 10
					teamScores.TeamB = math.floor((bScore / total) * 1000 + 0.5) / 10
				else
					teamScores.TeamA = 50.0
					teamScores.TeamB = 50.0
				end

				territoryEvent:FireAllClients(teamScores)
			end

			task.wait(1)
			timeLeft -= 1
		end

		-- 3. FASE DE FIN DE PARTIDA
		currentState = GameConfig.GAME_STATES.ENDED
		timeLeft = GameConfig.RESULTS_DURATION
		setPlayersMovementLocked(true)

		local finalPct = InkPainter.CalculateTerritory()
		local finalA = finalPct["TeamA"] or 0
		local finalB = finalPct["TeamB"] or 0
		local finalTotal = finalA + finalB

		if finalTotal > 0 then
			teamScores.TeamA = math.floor((finalA / finalTotal) * 1000 + 0.5) / 10
			teamScores.TeamB = math.floor((finalB / finalTotal) * 1000 + 0.5) / 10
		end

		local winner = "Empate"
		if teamScores.TeamA > teamScores.TeamB then
			winner = "TeamA"
		elseif teamScores.TeamB > teamScores.TeamA then
			winner = "TeamB"
		end

		print(string.format("[MatchManager] 🏆 FIN DE PARTIDA. Ganador: %s (Cian: %.1f%% vs Naranja: %.1f%%)", winner, teamScores.TeamA, teamScores.TeamB))

		matchStateEvent:FireAllClients({
			State = currentState,
			TimeLeft = timeLeft,
			Scores = teamScores,
			Winner = winner,
		})

		task.wait(GameConfig.RESULTS_DURATION)
	end
end)

print("[MatchManager] ✅ Servidor y bucle de juego listo.")
