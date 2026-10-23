--!strict
-- src/shared/TeamColors.luau
-- Configuración centralizada de equipos y sus colores de tinta

export type TeamConfig = {
	id: string,
	name: string,
	inkColor: Color3,
	spawnColor: Color3,
	enemySlowFactor: number,
}

local TeamColors = {}

local TEAMS: { [string]: TeamConfig } = {
	["TeamA"] = {
		id = "TeamA",
		name = "Tiburones Cian",
		inkColor = Color3.fromRGB(0, 220, 255),
		spawnColor = Color3.fromRGB(0, 160, 200),
		enemySlowFactor = 0.45,
	},
	["TeamB"] = {
		id = "TeamB",
		name = "Tiburones Naranja",
		inkColor = Color3.fromRGB(255, 120, 0),
		spawnColor = Color3.fromRGB(220, 90, 0),
		enemySlowFactor = 0.45,
	},
}

function TeamColors.Get(teamId: string): TeamConfig?
	return TEAMS[teamId]
end

function TeamColors.GetColor(teamId: string): Color3
	local team = TEAMS[teamId]
	return if team then team.inkColor else Color3.fromRGB(200, 200, 200)
end

function TeamColors.GetOpponent(teamId: string): string
	return if teamId == "TeamA" then "TeamB" else "TeamA"
end

function TeamColors.GetAll(): { [string]: TeamConfig }
	return TEAMS
end

return TeamColors

