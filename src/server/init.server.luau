--!strict
-- init.server.luau
-- Servidor principal del proyecto 'robloxito'

local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

print("======================================================")
print("  🤖 [ANTIGRAVITY] ¡CONEXIÓN CON ROBLOX STUDIO ACTIVA!")
print("  📁 Proyecto: robloxito sincronizado vía Rojo")
print("  🔫 Arma de prueba cargada en StarterPack")
print("======================================================")

-- Crear pedestal de bienvenida y demostración en el Workspace
local function createShowcasePedestal()
	local existing = Workspace:FindFirstChild("AltarAntigravity")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "AltarAntigravity"

	-- Base inferior
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = true
	base.Size = Vector3.new(6, 0.6, 6)
	base.Position = Vector3.new(0, 0.3, 0)
	base.Material = Enum.Material.SmoothPlastic
	base.Color = Color3.fromRGB(30, 30, 40)
	base.Parent = model

	-- Cilindro de luz
	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.Size = Vector3.new(1.8, 3, 3)
	pillar.CFrame = CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Material = Enum.Material.Neon
	pillar.Color = Color3.fromRGB(0, 200, 255)
	pillar.Parent = model

	-- Cristal / Objeto flotante
	local orb = Instance.new("Part")
	orb.Name = "OrbFlotante"
	orb.Shape = Enum.PartType.Ball
	orb.Anchored = true
	orb.CanCollide = false
	orb.Size = Vector3.new(1.8, 1.8, 1.8)
	orb.Position = Vector3.new(0, 3.8, 0)
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(0, 255, 170)
	orb.Parent = model

	local light = Instance.new("PointLight")
	light.Range = 15
	light.Brightness = 4
	light.Color = Color3.fromRGB(0, 255, 170)
	light.Parent = orb

	-- Partículas de energía
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 8
	emitter.Speed = NumberRange.new(1, 2)
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.LightEmission = 1
	emitter.Color = ColorSequence.new(Color3.fromRGB(0, 255, 200))
	emitter.Parent = orb

	-- Cartel flotante con información
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CartelInfo"
	billboard.Adornee = orb
	billboard.Size = UDim2.new(0, 280, 0, 75)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 0.25
	textLabel.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	textLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Text = "⚡ CONEXIÓN ANTIGRAVITY OK ⚡\n🎲 Arma en tu Inventario (Tecla 1)"
	textLabel.Parent = billboard
	billboard.Parent = orb

	-- ProximityPrompt para interactuar
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Obtener Arma de Prueba"
	prompt.ObjectText = "Pistola Aleatoria"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.Parent = orb

	prompt.Triggered:Connect(function(player)
		local tool = StarterPack:FindFirstChild("PistolaAleatoria")
		if tool then
			local clone = tool:Clone()
			clone.Parent = player:FindFirstChild("Backpack") or player.Character
			print(string.format("[Antigravity 🤖] ¡Arma entregada a %s vía Pedestal!", player.Name))
		end
	end)

	model.Parent = Workspace

	-- Animación de rotación del orbe flotante
	task.spawn(function()
		while orb.Parent do
			orb.CFrame = orb.CFrame * CFrame.Angles(0, math.rad(2), 0)
			task.wait(0.03)
		end
	end)
end

-- Asegurar que los jugadores que entren tengan equipo asignado y el arma en su mochila
local function onPlayerAdded(player: Player)
	player:SetAttribute("Team", "TeamA")

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		local tool = StarterPack:FindFirstChild("PistolaAleatoria")
		if tool and not player.Backpack:FindFirstChild(tool.Name) then
			local clone = tool:Clone()
			clone.Parent = player.Backpack
		end
	end)
end

-- Crear zona de tinta de prueba para probar el Modo Tiburón (SharkController)
local function createTestInkZone()
	local existing = Workspace:FindFirstChild("ZonaTintaPrueba")
	if existing then existing:Destroy() end

	local inkPad = Instance.new("Part")
	inkPad.Name = "ZonaTintaPrueba"
	inkPad.Anchored = true
	inkPad.CanCollide = true
	inkPad.Size = Vector3.new(24, 0.2, 24)
	inkPad.Position = Vector3.new(16, 0.1, 0)
	inkPad.Material = Enum.Material.Neon
	inkPad.Color = Color3.fromRGB(0, 200, 255)
	inkPad:SetAttribute("InkTeam", "TeamA") -- Marcada como tinta de TeamA
	inkPad.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 260, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = inkPad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
	label.TextColor3 = Color3.fromRGB(0, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = "🌊 TINTA ALIADA (TeamA)\nPisa aquí y mantén [Shift] para Modo Tiburón"
	label.Parent = billboard
	billboard.Parent = inkPad
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	onPlayerAdded(p)
end

-- Inicializar entorno
createShowcasePedestal()
createTestInkZone()
