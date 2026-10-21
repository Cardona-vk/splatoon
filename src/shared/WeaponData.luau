--!strict
-- src/shared/WeaponData.luau
-- Catálogo y especificaciones de armas para Shark Paint Battle

export type WeaponStats = {
	id: string,
	name: string,
	category: "Shooter" | "Charger",
	description: string,

	-- Estadísticas de Combate
	damage: number,                   -- Daño base por impacto
	inkCost: number,                  -- Tinta consumida por disparo (0 - 100)
	fireRate: number,                 -- Disparos por segundo
	cooldown: number,                 -- Tiempo de espera entre disparos (1 / fireRate)
	range: number,                    -- Alcance efectivo en studs
	projectileSpeed: number,          -- Velocidad de la gota/proyectil de tinta (studs/s)
	paintRadius: number,              -- Radio de la mancha de pintura en el suelo/pared
	spread: number,                   -- Desviación del disparo en grados

	-- Atributos especiales
	requiresCharge: boolean,          -- Si requiere mantener presionado para cargar
	chargeTime: number?,              -- Tiempo en segundos para carga completa
	minDamage: number?,               -- Daño con disparo rápido (sin cargar)
	maxDamage: number?,               -- Daño con carga máxima
	pierce: boolean?,                 -- Si el disparo atraviesa enemigos
}

local WeaponData = {}

local WEAPONS: { [string]: WeaponStats } = {
	-- 1. Lanzatintas (Inspirado en el Splattershot)
	-- Arma balanceada: Cadencia media, consumo medio, alcance medio
	["Lanzatintas"] = {
		id = "Lanzatintas",
		name = "Lanzatintas Escualo",
		category = "Shooter",
		description = "Arma estándar multipropósito. Equilibrio perfecto entre cobertura de pintura y combate medio.",
		damage = 36.0,                -- Elimina en ~3 disparos (100 HP)
		inkCost = 2.1,                -- Permite ~47 disparos con tanque lleno
		fireRate = 7.5,               -- 7.5 disparos por segundo
		cooldown = 1 / 7.5,           -- ~0.133 segundos entre disparos
		range = 65.0,                 -- Alcance medio (65 studs)
		projectileSpeed = 160.0,      -- Velocidad media
		paintRadius = 4.2,            -- Buen radio de cobertura
		spread = 4.5,                 -- Ligera dispersión
		requiresCharge = false,
	},

	-- 2. Francotirador (Inspirado en el Splat Charger)
	-- Arma de precisión: Daño alto, disparo lento/cargado, largo alcance, alto consumo
	["Francotirador"] = {
		id = "Francotirador",
		name = "Francotiburon Cargador",
		category = "Charger",
		description = "Rifle de largo alcance. Dispara un torrente concentrado de pintura de alta presión y letalidad.",
		damage = 160.0,               -- Elimina de 1 disparo cargado (100 HP)
		inkCost = 18.0,               -- Alto consumo de tinta (~5 disparos con carga completa)
		fireRate = 1.0,               -- 1 disparo por segundo
		cooldown = 1.0,               -- 1 segundo tras disparar
		range = 150.0,                -- Largo alcance (150 studs)
		projectileSpeed = 320.0,      -- Alta velocidad casi instantánea
		paintRadius = 6.5,            -- Mancha grande y lineal
		spread = 0.5,                 -- Máxima precisión
		requiresCharge = true,
		chargeTime = 1.1,             -- 1.1 segundos para carga máxima
		minDamage = 40.0,             -- Daño si se suelta inmediatamente
		maxDamage = 160.0,            -- Daño cargado al 100%
		pierce = true,                -- Atraviesa enemigos en carga completa
	},
}

-- Obtener las estadísticas de un arma por su ID
function WeaponData.Get(weaponId: string): WeaponStats?
	return WEAPONS[weaponId]
end

-- Obtener la lista completa de armas disponibles
function WeaponData.GetAll(): { [string]: WeaponStats }
	return WEAPONS
end

-- Verificar si un arma existe en el catálogo
function WeaponData.Exists(weaponId: string): boolean
	return WEAPONS[weaponId] ~= nil
end

return WeaponData

