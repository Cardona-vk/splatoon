--!strict
-- src/shared/InkSystem.luau
-- Sistema de gestión del depósito de tinta (Estilo Splatoon / Shark Paint Battle)

export type InkTankConfig = {
	maxInk: number?,
	baseRechargeRate: number?,     -- Tinta recuperada por segundo (caminando / parado)
	sharkRechargeRate: number?,    -- Tinta recuperada por segundo en Modo Tiburón
	rechargeDelay: number?,        -- Tiempo de espera tras disparar antes de iniciar recarga pasiva
}

export type InkTank = {
	currentInk: number,
	maxInk: number,
	baseRechargeRate: number,
	sharkRechargeRate: number,
	rechargeDelay: number,
	lastUsedTime: number,

	-- Métodos
	Consume: (self: InkTank, amount: number) -> boolean,
	Recharge: (self: InkTank, amount: number) -> number,
	Update: (self: InkTank, dt: number, isSharkMode: boolean) -> number,
	GetInk: (self: InkTank) -> number,
	GetMaxInk: (self: InkTank) -> number,
	GetPercentage: (self: InkTank) -> number,
	CanAfford: (self: InkTank, amount: number) -> boolean,
	Reset: (self: InkTank) -> (),
	SetChangedCallback: (self: InkTank, callback: (current: number, max: number, percentage: number) -> ()) -> (),
}

local InkSystem = {}
local InkTankClass = {}
InkTankClass.__index = InkTankClass

local DEFAULT_MAX_INK = 100
local DEFAULT_BASE_RECHARGE = 4.0      -- 4% por segundo en estado normal
local DEFAULT_SHARK_RECHARGE = 33.3     -- ~3 segundos para recarga completa en Modo Tiburón
local DEFAULT_RECHARGE_DELAY = 0.65     -- 0.65s de espera tras consumir tinta

-- Crea una nueva instancia de depósito de tinta
function InkSystem.new(config: InkTankConfig?): InkTank
	local cfg = config or {}
	local max = cfg.maxInk or DEFAULT_MAX_INK
	local baseRate = cfg.baseRechargeRate or DEFAULT_BASE_RECHARGE
	local sharkRate = cfg.sharkRechargeRate or DEFAULT_SHARK_RECHARGE
	local delay = cfg.rechargeDelay or DEFAULT_RECHARGE_DELAY

	local self = setmetatable({
		currentInk = max,
		maxInk = max,
		baseRechargeRate = baseRate,
		sharkRechargeRate = sharkRate,
		rechargeDelay = delay,
		lastUsedTime = 0,
		_onChanged = nil :: ((current: number, max: number, percentage: number) -> ())?,
	}, InkTankClass)

	return (self :: any) :: InkTank
end

-- Consume una cantidad determinada de tinta. Devuelve true si la operación fue exitosa.
function InkTankClass:Consume(amount: number): boolean
	if amount <= 0 then
		return true
	end

	if self.currentInk >= amount then
		self.currentInk = math.clamp(self.currentInk - amount, 0, self.maxInk)
		self.lastUsedTime = os.clock()

		self:_fireChanged()
		return true
	end

	return false
end

-- Recarga directa de tinta (por ejemplo, al recoger un potenciador o recarga instantánea)
function InkTankClass:Recharge(amount: number): number
	if amount <= 0 then
		return self.currentInk
	end

	self.currentInk = math.clamp(self.currentInk + amount, 0, self.maxInk)
	self:_fireChanged()
	return self.currentInk
end

-- Actualiza la recarga continua en cada fotograma o ciclo de servidor
-- dt: delta time en segundos transcurridos
-- isSharkMode: si el jugador se encuentra sumergido en tinta de su equipo
function InkTankClass:Update(dt: number, isSharkMode: boolean): number
	if self.currentInk >= self.maxInk then
		return self.currentInk
	end

	-- Verificar si pasó el retraso tras disparar
	local now = os.clock()
	if (now - self.lastUsedTime) < self.rechargeDelay and not isSharkMode then
		return self.currentInk
	end

	-- En Modo Tiburón la recarga es rápida e ignora el retraso de disparo
	local rate = if isSharkMode then self.sharkRechargeRate else self.baseRechargeRate
	local added = rate * dt

	self.currentInk = math.clamp(self.currentInk + added, 0, self.maxInk)
	self:_fireChanged()
	return self.currentInk
end

-- Devuelve la cantidad de tinta actual
function InkTankClass:GetInk(): number
	return self.currentInk
end

-- Devuelve la capacidad máxima
function InkTankClass:GetMaxInk(): number
	return self.maxInk
end

-- Devuelve el porcentaje actual (0 - 100)
function InkTankClass:GetPercentage(): number
	if self.maxInk <= 0 then
		return 0
	end
	return (self.currentInk / self.maxInk) * 100
end

-- Comprueba si el jugador tiene suficiente tinta sin consumirla
function InkTankClass:CanAfford(amount: number): boolean
	return self.currentInk >= amount
end

-- Restablece la tinta al máximo
function InkTankClass:Reset(): ()
	self.currentInk = self.maxInk
	self.lastUsedTime = 0
	self:_fireChanged()
end

-- Registra un callback para escuchar cambios de tinta (ideal para UI)
function InkTankClass:SetChangedCallback(callback: (current: number, max: number, percentage: number) -> ()): ()
	self._onChanged = callback
	-- Emitir estado inicial
	callback(self.currentInk, self.maxInk, self:GetPercentage())
end

-- Notificador interno
function InkTankClass:_fireChanged(): ()
	if self._onChanged then
		self._onChanged(self.currentInk, self.maxInk, self:GetPercentage())
	end
end

return InkSystem

