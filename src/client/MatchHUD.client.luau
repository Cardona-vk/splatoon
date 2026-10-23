--!strict
-- src/client/MatchHUD.client.luau
-- Interfaz de Usuario para el Bucle de Partida (Temporizador, Barra Territorial y Victoria/Derrota)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TeamColors = require(Shared:WaitForChild("TeamColors"))
local RemotesModule = require(Shared:WaitForChild("Remotes"))

local matchStateEvent = RemotesModule.Get("MatchStateUpdate")
local territoryEvent = RemotesModule.Get("TerritoryUpdate")

-- ====================================================================
-- CREACIÓN DE INTERFAZ SUPERIOR (HUD DE PARTIDA)
-- ====================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MatchHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- 1. Contenedor del Temporizador Superior
local timerFrame = Instance.new("Frame")
timerFrame.Name = "TimerFrame"
timerFrame.Size = UDim2.new(0, 120, 0, 42)
timerFrame.Position = UDim2.new(0.5, -60, 0, 12)
timerFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
timerFrame.BackgroundTransparency = 0.2
timerFrame.BorderSizePixel = 0
timerFrame.Parent = screenGui

local timerCorner = Instance.new("UICorner")
timerCorner.CornerRadius = UDim.new(0, 8)
timerCorner.Parent = timerFrame

local timerStroke = Instance.new("UIStroke")
timerStroke.Color = Color3.fromRGB(60, 65, 80)
timerStroke.Thickness = 1.5
timerStroke.Parent = timerFrame

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(1, 0, 1, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextSize = 22
timerLabel.Text = "3:00"
timerLabel.Parent = timerFrame

-- 2. Barra Territorial de Porcentajes (% Cian vs % Naranja)
local territoryBarContainer = Instance.new("Frame")
territoryBarContainer.Name = "TerritoryBarContainer"
territoryBarContainer.Size = UDim2.new(0, 440, 0, 22)
territoryBarContainer.Position = UDim2.new(0.5, -220, 0, 60)
territoryBarContainer.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
territoryBarContainer.BorderSizePixel = 0
territoryBarContainer.Parent = screenGui

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 6)
barCorner.Parent = territoryBarContainer

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(60, 65, 80)
barStroke.Thickness = 1.5
barStroke.Parent = territoryBarContainer

-- Relleno Lado Cian (Izquierda)
local teamAFill = Instance.new("Frame")
teamAFill.Name = "TeamAFill"
teamAFill.Size = UDim2.new(0.5, 0, 1, 0)
teamAFill.Position = UDim2.new(0, 0, 0, 0)
teamAFill.BackgroundColor3 = GameConfig.TEAMS.TeamA.Color
teamAFill.BorderSizePixel = 0
teamAFill.Parent = territoryBarContainer

local cornerA = Instance.new("UICorner")
cornerA.CornerRadius = UDim.new(0, 6)
cornerA.Parent = teamAFill

-- Relleno Lado Naranja (Derecha)
local teamBFill = Instance.new("Frame")
teamBFill.Name = "TeamBFill"
teamBFill.Size = UDim2.new(0.5, 0, 1, 0)
teamBFill.Position = UDim2.new(0.5, 0, 0, 0)
teamBFill.BackgroundColor3 = GameConfig.TEAMS.TeamB.Color
teamBFill.BorderSizePixel = 0
teamBFill.Parent = territoryBarContainer

local cornerB = Instance.new("UICorner")
cornerB.CornerRadius = UDim.new(0, 6)
cornerB.Parent = teamBFill

-- Etiquetas con Porcentajes
local teamAPctLabel = Instance.new("TextLabel")
teamAPctLabel.Name = "TeamAPct"
teamAPctLabel.Size = UDim2.new(0, 90, 0, 20)
teamAPctLabel.Position = UDim2.new(0.5, -220, 0, 84)
teamAPctLabel.BackgroundTransparency = 1
teamAPctLabel.TextColor3 = GameConfig.TEAMS.TeamA.Color
teamAPctLabel.Font = Enum.Font.GothamBold
teamAPctLabel.TextSize = 16
teamAPctLabel.TextXAlignment = Enum.TextXAlignment.Left
teamAPctLabel.Text = "CIAN: 50.0%"
teamAPctLabel.Parent = screenGui

local teamBPctLabel = Instance.new("TextLabel")
teamBPctLabel.Name = "TeamBPct"
teamBPctLabel.Size = UDim2.new(0, 90, 0, 20)
teamBPctLabel.Position = UDim2.new(0.5, 130, 0, 84)
teamBPctLabel.BackgroundTransparency = 1
teamBPctLabel.TextColor3 = GameConfig.TEAMS.TeamB.Color
teamBPctLabel.Font = Enum.Font.GothamBold
teamBPctLabel.TextSize = 16
teamBPctLabel.TextXAlignment = Enum.TextXAlignment.Right
teamBPctLabel.Text = "50.0% :NARANJA"
teamBPctLabel.Parent = screenGui

-- 3. Banner Central para Anuncios
local announcementBanner = Instance.new("Frame")
announcementBanner.Name = "AnnouncementBanner"
announcementBanner.Size = UDim2.new(1, 0, 0, 110)
announcementBanner.Position = UDim2.new(0, 0, 0.4, -55)
announcementBanner.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
announcementBanner.BackgroundTransparency = 0.2
announcementBanner.BorderSizePixel = 0
announcementBanner.Visible = false
announcementBanner.Parent = screenGui

local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Color3.fromRGB(0, 220, 255)
bannerStroke.Thickness = 2
bannerStroke.Parent = announcementBanner

local mainText = Instance.new("TextLabel")
mainText.Name = "MainText"
mainText.Size = UDim2.new(1, 0, 0.6, 0)
mainText.Position = UDim2.new(0, 0, 0.08, 0)
mainText.BackgroundTransparency = 1
mainText.TextColor3 = Color3.fromRGB(255, 255, 255)
mainText.Font = Enum.Font.GothamBlack
mainText.TextSize = 36
mainText.Text = "¡LISTOS!"
mainText.Parent = announcementBanner

local subText = Instance.new("TextLabel")
subText.Name = "SubText"
subText.Size = UDim2.new(1, 0, 0.35, 0)
subText.Position = UDim2.new(0, 0, 0.62, 0)
subText.BackgroundTransparency = 1
subText.TextColor3 = Color3.fromRGB(200, 220, 240)
subText.Font = Enum.Font.GothamBold
subText.TextSize = 18
subText.Text = "La partida iniciará pronto"
subText.Parent = announcementBanner

-- ====================================================================
-- FUNCIONES DE ANIMACIÓN Y FORMATO
-- ====================================================================
local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", mins, secs)
end

local function updateTerritoryDisplay(scores: { TeamA: number, TeamB: number })
	local aPct = scores.TeamA or 50.0
	local bPct = scores.TeamB or 50.0
	local ratio = math.clamp(aPct / 100, 0.05, 0.95)

	TweenService:Create(teamAFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Size = UDim2.new(ratio, 0, 1, 0)
	}):Play()

	TweenService:Create(teamBFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Position = UDim2.new(ratio, 0, 0, 0),
		Size = UDim2.new(1 - ratio, 0, 1, 0)
	}):Play()

	teamAPctLabel.Text = string.format("CIAN: %.1f%%", aPct)
	teamBPctLabel.Text = string.format("%.1f%% :NARANJA", bPct)
end

-- ====================================================================
-- ESCUCHA DE EVENTOS DESDE EL SERVIDOR
-- ====================================================================
territoryEvent.OnClientEvent:Connect(function(scores: { TeamA: number, TeamB: number })
	updateTerritoryDisplay(scores)
end)

matchStateEvent.OnClientEvent:Connect(function(data: { State: string, TimeLeft: number, Scores: any, Winner: string? })
	local state = data.State
	local secLeft = data.TimeLeft
	local myTeam = localPlayer:GetAttribute("Team") or "TeamA"

	if state == GameConfig.GAME_STATES.INTERMISSION then
		timerLabel.Text = tostring(secLeft)
		timerLabel.TextColor3 = Color3.fromRGB(255, 200, 60)

		announcementBanner.Visible = true
		mainText.Text = "¡PREPÁRATE!"
		mainText.TextColor3 = Color3.fromRGB(255, 220, 0)
		bannerStroke.Color = Color3.fromRGB(255, 220, 0)
		subText.Text = string.format("La batalla inicia en %d segundos...", secLeft)

	elseif state == GameConfig.GAME_STATES.ACTIVE then
		announcementBanner.Visible = false
		timerLabel.Text = formatTime(secLeft)

		if secLeft <= 30 then
			timerLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
			timerStroke.Color = Color3.fromRGB(255, 60, 60)
		else
			timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			timerStroke.Color = Color3.fromRGB(60, 65, 80)
		end

	elseif state == GameConfig.GAME_STATES.ENDED then
		timerLabel.Text = "0:00"
		announcementBanner.Visible = true

		local winner = data.Winner
		if winner == myTeam then
			mainText.Text = "🎉 ¡VICTORIA! 🎉"
			mainText.TextColor3 = Color3.fromRGB(0, 255, 160)
			bannerStroke.Color = Color3.fromRGB(0, 255, 160)
			subText.Text = "¡Tu equipo cubrió la mayor cantidad de territorio!"
		elseif winner == "Empate" then
			mainText.Text = "⚖️ ¡EMPATE! ⚖️"
			mainText.TextColor3 = Color3.fromRGB(255, 220, 0)
			bannerStroke.Color = Color3.fromRGB(255, 220, 0)
			subText.Text = "¡Ambos equipos consiguieron la misma cobertura!"
		else
			mainText.Text = "💥 ¡DERROTA! 💥"
			mainText.TextColor3 = Color3.fromRGB(255, 80, 80)
			bannerStroke.Color = Color3.fromRGB(255, 80, 80)
			subText.Text = "El equipo rival cubrió más terreno esta vez."
		end
	end

	if data.Scores then
		updateTerritoryDisplay(data.Scores)
	end
end)

print("[MatchHUD] ✅ Interfaz de partida y territorio conectada.")
