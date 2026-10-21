--!strict
-- WeaponScript.server.luau
-- Arma Aleatoria de Prueba creada por Antigravity
local Tool = script.Parent :: Tool
local Handle = Tool:WaitForChild("Handle") :: BasePart

local Debris = game:GetService("Debris")

local RANDOM_COLORS = {
	Color3.fromRGB(255, 0, 128),  -- Magenta Neón
	Color3.fromRGB(0, 255, 255),  -- Cian Eléctrico
	Color3.fromRGB(255, 255, 0),  -- Amarillo Solar
	Color3.fromRGB(0, 255, 100),  -- Verde Radiactivo
	Color3.fromRGB(255, 80, 0),   -- Naranja Fuego
	Color3.fromRGB(180, 0, 255),  -- Púrpura Cósmico
}

local SOUND_IDS = {
	"rbxassetid://130113146", -- Pew
	"rbxassetid://138090596", -- Laser
	"rbxassetid://541909814", -- Blaster
}

local FUNNY_PHRASES = {
	"¡Pew pew! ¡Conexión con Antigravity 100% exitosa!",
	"¡Boom cuántico! Rojo y Roblox Studio están sincronizados.",
	"¡Disparo galáctico generado por IA!",
	"¡Energía aleatoria al máximo nivel!",
	"¡Test de arma superado con éxito!",
}

-- Configurar efectos visuales en el Handle
local light = Handle:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
light.Range = 14
light.Brightness = 3
light.Color = Color3.fromRGB(0, 200, 255)
light.Parent = Handle

local particles = Handle:FindFirstChildOfClass("ParticleEmitter") or Instance.new("ParticleEmitter")
particles.Rate = 12
particles.Speed = NumberRange.new(1, 3)
particles.Lifetime = NumberRange.new(0.5, 1)
particles.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.4),
	NumberSequenceKeypoint.new(1, 0),
})
particles.LightEmission = 1
particles.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
particles.Parent = Handle

local sound = Instance.new("Sound")
sound.SoundId = "rbxassetid://130113146"
sound.Volume = 0.8
sound.Parent = Handle

local canShoot = true
local COOLDOWN = 0.25

Tool.Activated:Connect(function()
	if not canShoot then return end
	canShoot = false

	local character = Tool.Parent :: Model?
	if not character then return end
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then return end

	-- Elegir color y frase aleatoria
	local chosenColor = RANDOM_COLORS[math.random(1, #RANDOM_COLORS)]
	local chosenPhrase = FUNNY_PHRASES[math.random(1, #FUNNY_PHRASES)]

	-- Cambiar color del arma en cada disparo
	Handle.Color = chosenColor
	light.Color = chosenColor
	particles.Color = ColorSequence.new(chosenColor)

	-- Sonido aleatorio de disparo
	sound.SoundId = SOUND_IDS[math.random(1, #SOUND_IDS)]
	sound.PlaybackSpeed = math.random(85, 125) / 100
	sound:Play()

	-- Crear proyectil láser
	local projectile = Instance.new("Part")
	projectile.Name = "LaserProjectile"
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(1.2, 1.2, 1.2)
	projectile.Material = Enum.Material.Neon
	projectile.Color = chosenColor
	projectile.CanCollide = false
	projectile.CFrame = CFrame.lookAt(Handle.Position, Handle.Position + humanoidRootPart.CFrame.LookVector * 10)
	projectile.Parent = workspace

	local projLight = Instance.new("PointLight")
	projLight.Range = 10
	projLight.Brightness = 4
	projLight.Color = chosenColor
	projLight.Parent = projectile

	-- Velocidad del proyectil
	local bodyVelocity = Instance.new("BodyVelocity")
	local direction = humanoidRootPart.CFrame.LookVector
	bodyVelocity.Velocity = direction * 120
	bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVelocity.Parent = projectile

	-- Despawn automático
	Debris:AddItem(projectile, 4)

	-- Imprimir mensaje en la consola de Roblox Studio
	print(string.format("[Antigravity 🤖] 💥 %s (Color: %s)", chosenPhrase, tostring(chosenColor)))

	-- Impacto
	local hitConnection: RBXScriptConnection? = nil
	hitConnection = projectile.Touched:Connect(function(hit)
		if hit:IsDescendantOf(character) then return end
		if hitConnection then
			hitConnection:Disconnect()
		end

		-- Crear explosión visual
		local explosion = Instance.new("Explosion")
		explosion.Position = projectile.Position
		explosion.BlastRadius = 6
		explosion.BlastPressure = 20000 -- Pequeño empuje divertido
		explosion.DestroyJointRadiusPercent = 0 -- No mata instantáneamente para pruebas
		explosion.Parent = workspace

		-- Efecto de partículas de impacto
		local impactPart = Instance.new("Part")
		impactPart.Anchored = true
		impactPart.CanCollide = false
		impactPart.Transparency = 1
		impactPart.Position = projectile.Position
		impactPart.Size = Vector3.new(1, 1, 1)
		impactPart.Parent = workspace

		local flash = Instance.new("PointLight")
		flash.Range = 20
		flash.Brightness = 8
		flash.Color = chosenColor
		flash.Parent = impactPart

		Debris:AddItem(impactPart, 0.5)
		projectile:Destroy()
	end)

	task.wait(COOLDOWN)
	canShoot = true
end)

Tool.Equipped:Connect(function()
	print("[Antigravity 🤖] 🔫 ¡Arma de prueba equipada con éxito en Roblox Studio!")
end)

Tool.Unequipped:Connect(function()
	print("[Antigravity 🤖] 📦 Arma guardada.")
end)

