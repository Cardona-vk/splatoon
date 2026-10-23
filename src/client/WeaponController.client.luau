--!strict
-- src/client/WeaponController.client.luau
-- Controlador de arma del lado cliente: Input de disparo, efectos visuales locales y HUD de tinta

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()
local camera = workspace.CurrentCamera

-- Módulos compartidos
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponData = require(Shared:WaitForChild("WeaponData"))
local TeamColors = require(Shared:WaitForChild("TeamColors"))
local RemotesModule = require(Shared:WaitForChild("Remotes"))

-- RemoteEvents
local fireEvent = RemotesModule.Get("FireWeapon")
local hitMarkerEvent = RemotesModule.Get("HitMarker")
local inkUpdateEvent = RemotesModule.Get("InkUpdate")

-- ====================================================================
-- ESTADO DEL ARMA LOCAL
-- ====================================================================
local currentWeaponId = "Lanzatintas"  -- Arma por defecto
local isFiring = false
local isCharging = false
local chargeStartTime = 0
local lastFireTime = 0
local currentInk = 100
local maxInk = 100

local playerTeam = localPlayer:GetAttribute("Team") or "TeamA"

-- Referencia al personaje
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

-- ====================================================================
-- HUD DE TINTA (Barra visual en pantalla)
-- ====================================================================
local playerGui = localPlayer:WaitForChild("PlayerGui")

local function createInkHUD(): (Frame, Frame, TextLabel)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InkHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Contenedor principal
	local container = Instance.new("Frame")
	container.Name = "InkBarContainer"
	container.Size = UDim2.new(0, 220, 0, 28)
	container.Position = UDim2.new(0.5, -110, 1, -60)
	container.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	container.BackgroundTransparency = 0.2
	container.BorderSizePixel = 0
	container.Parent = screenGui

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 6)
	containerCorner.Parent = container

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = Color3.fromRGB(60, 65, 80)
	containerStroke.Thickness = 1.5
	containerStroke.Parent = container

	-- Barra de tinta (relleno)
	local inkBar = Instance.new("Frame")
	inkBar.Name = "InkFill"
	inkBar.Size = UDim2.new(1, -8, 1, -8)
	inkBar.Position = UDim2.new(0, 4, 0, 4)
	inkBar.BackgroundColor3 = TeamColors.GetColor(playerTeam)
	inkBar.BorderSizePixel = 0
	inkBar.Parent = container

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = inkBar

	-- Porcentaje texto
	local pctLabel = Instance.new("TextLabel")
	pctLabel.Name = "PctLabel"
	pctLabel.Size = UDim2.new(1, 0, 1, 0)
	pctLabel.BackgroundTransparency = 1
	pctLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	pctLabel.TextStrokeTransparency = 0.5
	pctLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	pctLabel.Font = Enum.Font.GothamBold
	pctLabel.TextSize = 14
	pctLabel.Text = "100%"
	pctLabel.Parent = container

	-- Icono de arma actual
	local weaponLabel = Instance.new("TextLabel")
	weaponLabel.Name = "WeaponLabel"
	weaponLabel.Size = UDim2.new(0, 220, 0, 18)
	weaponLabel.Position = UDim2.new(0.5, -110, 1, -82)
	weaponLabel.BackgroundTransparency = 1
	weaponLabel.TextColor3 = Color3.fromRGB(200, 210, 220)
	weaponLabel.Font = Enum.Font.GothamBold
	weaponLabel.TextSize = 12
	weaponLabel.Text = "🔫 Lanzatintas Escualo"
	weaponLabel.Parent = screenGui

	-- Retícula central simple
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.new(0, 24, 0, 24)
	crosshair.Position = UDim2.new(0.5, -12, 0.5, -12)
	crosshair.BackgroundTransparency = 1
	crosshair.Parent = screenGui

	-- Punto central
	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 4, 0, 4)
	dot.Position = UDim2.new(0.5, -2, 0.5, -2)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BorderSizePixel = 0
	dot.Parent = crosshair

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	-- Brazos de la retícula
	for _, offset in { {0, -10, 4, 2}, {0, 8, 4, 2}, {-10, 0, 2, 4}, {8, 0, 2, 4} } do
		local arm = Instance.new("Frame")
		arm.Size = UDim2.new(0, offset[3], 0, offset[4])
		arm.Position = UDim2.new(0.5, offset[1], 0.5, offset[2])
		arm.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		arm.BackgroundTransparency = 0.3
		arm.BorderSizePixel = 0
		arm.Parent = crosshair
	end

	return container, inkBar, pctLabel
end

local inkContainer, inkFill, inkPctLabel = createInkHUD()

-- Actualizar barra de tinta
local function updateInkBar(ink: number, max: number)
	currentInk = ink
	maxInk = max
	local pct = if max > 0 then (ink / max) else 0

	TweenService:Create(inkFill, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
		Size = UDim2.new(pct, -8 * pct, 1, -8),
	}):Play()

	inkPctLabel.Text = string.format("%d%%", math.floor(pct * 100 + 0.5))

	-- Cambiar color si tinta baja
	if pct < 0.2 then
		inkFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	elseif pct < 0.4 then
		inkFill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	else
		inkFill.BackgroundColor3 = TeamColors.GetColor(playerTeam)
	end
end

-- ====================================================================
-- EFECTO VISUAL LOCAL DE DISPARO (Muzzle Flash)
-- ====================================================================
local function playMuzzleFlash(origin: Vector3, color: Color3)
	local att = Instance.new("Attachment")
	att.WorldPosition = origin
	att.Parent = workspace.Terrain

	local flash = Instance.new("ParticleEmitter")
	flash.Rate = 0
	flash.Speed = NumberRange.new(8, 15)
	flash.SpreadAngle = Vector2.new(20, 20)
	flash.Lifetime = NumberRange.new(0.08, 0.15)
	flash.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	flash.Color = ColorSequence.new(color)
	flash.LightEmission = 1
	flash.Parent = att
	flash:Emit(5)

	local Debris = game:GetService("Debris")
	Debris:AddItem(att, 0.3)
end

-- ====================================================================
-- EFECTO DE HIT MARKER
-- ====================================================================
local function showHitMarker(hitType: string)
	local marker = Instance.new("TextLabel")
	marker.Name = "HitMarker"
	marker.Size = UDim2.new(0, 60, 0, 30)
	marker.Position = UDim2.new(0.5, -30, 0.5, -40)
	marker.BackgroundTransparency = 1
	marker.TextColor3 = if hitType == "kill" then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(255, 255, 100)
	marker.Font = Enum.Font.GothamBold
	marker.TextSize = if hitType == "kill" then 22 else 18
	marker.Text = if hitType == "kill" then "💀 SPLAT!" else "✕"
	marker.TextStrokeTransparency = 0.4
	marker.Parent = playerGui:FindFirstChild("InkHUD")

	TweenService:Create(marker, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -30, 0.5, -70),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	local Debris = game:GetService("Debris")
	Debris:AddItem(marker, 0.7)
end

hitMarkerEvent.OnClientEvent:Connect(function(hitType: string, _damage: number)
	showHitMarker(hitType)
end)

-- ====================================================================
-- BARRA DE CARGA DEL FRANCOTIRADOR
-- ====================================================================
local chargeBarGui: ScreenGui? = nil
local chargeBarFill: Frame? = nil

local function getOrCreateChargeBar(): Frame
	if chargeBarFill then return chargeBarFill end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ChargeBarGui"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	chargeBarGui = gui

	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, 6, 0, 100)
	container.Position = UDim2.new(0.5, 20, 0.5, -50)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	container.BackgroundTransparency = 0.3
	container.BorderSizePixel = 0
	container.Visible = false
	container.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = container

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, -2, 0, 0)
	fill.Position = UDim2.new(0, 1, 1, -1)
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.BackgroundColor3 = TeamColors.GetColor(playerTeam)
	fill.BorderSizePixel = 0
	fill.Parent = container

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 2)
	fillCorner.Parent = fill

	chargeBarFill = fill
	return fill
end

local function updateChargeBar(percent: number, visible: boolean)
	local fill = getOrCreateChargeBar()
	local container = fill.Parent :: Frame
	container.Visible = visible

	if visible then
		fill.Size = UDim2.new(1, -2, math.clamp(percent, 0, 1), -2)

		if percent >= 1 then
			fill.BackgroundColor3 = Color3.fromRGB(255, 255, 100)
		else
			fill.BackgroundColor3 = TeamColors.GetColor(playerTeam)
		end
	end
end

-- ====================================================================
-- SELECCIÓN DE ARMAS (Teclas 1 y 2)
-- ====================================================================
local function switchWeapon(weaponId: string)
	if not WeaponData.Exists(weaponId) then return end
	currentWeaponId = weaponId
	isFiring = false
	isCharging = false

	local weapon = WeaponData.Get(weaponId)
	if weapon then
		local weaponLabel = playerGui:FindFirstChild("InkHUD") and (playerGui.InkHUD :: ScreenGui):FindFirstChild("WeaponLabel")
		if weaponLabel and weaponLabel:IsA("TextLabel") then
			local icon = if weapon.category == "Charger" then "🎯" else "🔫"
			weaponLabel.Text = icon .. " " .. weapon.name
		end
	end

	updateChargeBar(0, false)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.One then
		switchWeapon("Lanzatintas")
	elseif input.KeyCode == Enum.KeyCode.Two then
		switchWeapon("Francotirador")
	end
end)

-- ====================================================================
-- LÓGICA DE DISPARO
-- ====================================================================
local function getAimDirection(): Vector3
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	return ray.Direction.Unit
end

local function getFireOrigin(): Vector3
	if not rootPart then return Vector3.zero end
	return rootPart.Position + rootPart.CFrame.LookVector * 2 + Vector3.new(0, 1, 0)
end

local function tryFire()
	local weapon = WeaponData.Get(currentWeaponId)
	if not weapon then return end

	local now = os.clock()
	if (now - lastFireTime) < weapon.cooldown then return end

	-- En modo tiburón no se puede disparar
	if character and character:GetAttribute("IsSharkMode") == true then return end

	-- Verificar tinta local (estimación, el servidor valida de verdad)
	if currentInk < weapon.inkCost then return end

	lastFireTime = now
	currentInk = math.max(0, currentInk - weapon.inkCost)
	updateInkBar(currentInk, maxInk)

	local origin = getFireOrigin()
	local direction = getAimDirection()
	local inkColor = TeamColors.GetColor(playerTeam)

	-- Enviar al servidor
	fireEvent:FireServer(currentWeaponId, origin, direction, nil)

	-- Efecto visual local inmediato (responsividad)
	playMuzzleFlash(origin, inkColor)
end

local function tryChargerFire(chargePercent: number)
	local weapon = WeaponData.Get(currentWeaponId)
	if not weapon then return end

	if character and character:GetAttribute("IsSharkMode") == true then return end

	local inkCost = weapon.inkCost * math.clamp(chargePercent, 0.2, 1)
	if currentInk < inkCost then return end

	lastFireTime = os.clock()
	currentInk = math.max(0, currentInk - inkCost)
	updateInkBar(currentInk, maxInk)

	local origin = getFireOrigin()
	local direction = getAimDirection()
	local inkColor = TeamColors.GetColor(playerTeam)

	fireEvent:FireServer(currentWeaponId, origin, direction, chargePercent)
	playMuzzleFlash(origin, inkColor)
end

-- ====================================================================
-- ENTRADA DE RATÓN (MouseButton1)
-- ====================================================================
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	local weapon = WeaponData.Get(currentWeaponId)
	if not weapon then return end

	if weapon.requiresCharge then
		-- Iniciar carga del Francotirador
		isCharging = true
		chargeStartTime = os.clock()
		updateChargeBar(0, true)
	else
		-- Disparo continuo del Lanzatintas
		isFiring = true
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	if isCharging then
		-- Soltar = Disparar el Francotirador con la carga acumulada
		local weapon = WeaponData.Get(currentWeaponId)
		if weapon and weapon.chargeTime then
			local elapsed = os.clock() - chargeStartTime
			local chargePercent = math.clamp(elapsed / weapon.chargeTime, 0, 1)
			tryChargerFire(chargePercent)
		end
		isCharging = false
		updateChargeBar(0, false)
	end

	isFiring = false
end)

-- ====================================================================
-- BUCLE DE DISPARO CONTINUO Y CARGA
-- ====================================================================
RunService.RenderStepped:Connect(function()
	-- Disparo automático continuo (Shooter)
	if isFiring then
		tryFire()
	end

	-- Actualizar barra de carga (Charger)
	if isCharging then
		local weapon = WeaponData.Get(currentWeaponId)
		if weapon and weapon.chargeTime then
			local elapsed = os.clock() - chargeStartTime
			local chargePercent = math.clamp(elapsed / weapon.chargeTime, 0, 1)
			updateChargeBar(chargePercent, true)
		end
	end
end)

-- ====================================================================
-- RECIBIR ACTUALIZACIONES DE TINTA DESDE EL SERVIDOR
-- ====================================================================
inkUpdateEvent.OnClientEvent:Connect(function(ink: number, max: number)
	updateInkBar(ink, max)
end)

-- ====================================================================
-- GESTIÓN DE RESPAWN
-- ====================================================================
local function onCharacterAdded(newCharacter: Model)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	rootPart = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	isFiring = false
	isCharging = false
	currentInk = maxInk
	updateInkBar(currentInk, maxInk)
	updateChargeBar(0, false)
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)

localPlayer:GetAttributeChangedSignal("Team"):Connect(function()
	playerTeam = localPlayer:GetAttribute("Team") or "TeamA"
	updateInkBar(currentInk, maxInk)
end)

print("[WeaponController] 🔫 Controlador de armas inicializado. [1] Lanzatintas | [2] Francotirador")

