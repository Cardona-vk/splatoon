--!strict
-- src/shared/GameConfig.luau
-- Configuración global de la partida y reglas de juego

local GameConfig = {
	-- Tiempos de partida
	INTERMISSION_TIME = 10,     -- Segundos de espera / cuenta regresiva en el lobby
	MATCH_DURATION = 180,       -- 3 minutos de combate (estilo Splatoon)
	RESULTS_DURATION = 8,       -- Duración de la pantalla de victoria/derrota

	-- Equipos
	TEAMS = {
		TeamA = {
			Id = "TeamA",
			Name = "Tiburones Cian",
			Color = Color3.fromRGB(0, 220, 255),
			SpawnPosition = Vector3.new(0, 3, 70),
		},
		TeamB = {
			Id = "TeamB",
			Name = "Tiburones Naranja",
			Color = Color3.fromRGB(255, 120, 0),
			SpawnPosition = Vector3.new(0, 3, -70),
		},
	},

	-- Estados de juego
	GAME_STATES = {
		WAITING = "WAITING",            -- Esperando suficientes jugadores
		INTERMISSION = "INTERMISSION",  -- Cuenta regresiva para iniciar
		ACTIVE = "ACTIVE",              -- En combate (tiempo corriendo)
		ENDED = "ENDED",                -- Resultados / Fin de ronda
	},
}

return GameConfig

