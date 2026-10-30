local SmokeMaterial = "particle/smokestack"

function EFFECT:Init(data)
	local Pos = data:GetOrigin()
	local Emitter = ParticleEmitter(Pos)

	for i = 1, 50 do
		local Height = math.Rand(0, 1300)
		local Radius

		if Height < 850 then
			Radius = math.Rand(80, 220) + Height * .12
		else
			local CapProgress = (Height - 850) / 450
			Radius = math.sqrt(math.Rand(0, 1)) * (700 - CapProgress * 300)
		end

		local Angle = math.Rand(0, math.pi * 2)
		local SpawnPos = Pos + Vector(math.cos(Angle) * Radius, math.sin(Angle) * Radius, Height)
		local Particle = Emitter:Add(SmokeMaterial, SpawnPos)

		if Particle then
			local HorizontalSpeed = Height < 850 and math.Rand(-35, 35) or math.Rand(-100, 100)
			Particle:SetVelocity(Vector(math.cos(Angle) * HorizontalSpeed, math.sin(Angle) * HorizontalSpeed, math.Rand(30, 100)))
			Particle:SetAirResistance(80)
			Particle:SetGravity(Vector(0, 0, 10))
			Particle:SetDieTime(math.Rand(15, 17))
			Particle:SetStartAlpha(190)
			Particle:SetEndAlpha(0)
			local Size = math.Rand(250, 450)
			Particle:SetStartSize(Size)
			Particle:SetEndSize(Size * math.Rand(2, 3))
			Particle:SetRoll(math.Rand(-3, 3))
			Particle:SetRollDelta(math.Rand(-.2, .2))
			Particle:SetLighting(false)
			local Shade = math.Rand(45, 80)
			Particle:SetColor(Shade, Shade, Shade)
			Particle:SetCollide(false)
		end
	end

	Emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
