local Flash = Material("sprites/mat_jack_basicglow")
function EFFECT:Init(data)
	local Pos, Scale = data:GetOrigin(), data:GetScale()
	if Scale <= 0 then Scale = 1 end
	self.Pos = Pos
	self.Scale = Scale
	local Time = CurTime()
	self.FlashTime = Time + .05
	self.CrackleTime = Time + .75
	self.DieTime = Time + 2.5
	self.Night = string.find(game.GetMap(), "night")
	local Emitter = ParticleEmitter(Pos)
	for i = 1, 30 do -- number of arms
		local Dir = (VectorRand() + Vector(0, 0, .2)):GetNormalized()
		local R, G, B
		local Rand = math.random(1, 3)
		if (Rand == 1) then
			R = 255
			G = 0
			B = 0
		elseif (Rand == 2) then
			R = 255
			G = 255
			B = 255
		else
			R = 0
			G = 0
			B = 255
		end
		for j = 1, 30 do
			local Girth = 1 - (j / 30)
			local particle = Emitter:Add("sprites/mat_jack_basicglow", Pos)
			if (particle) then -- glowing lights
				particle:SetVelocity(Dir * 2000 * Scale * Girth ^ .5)
				particle:SetAirResistance(100 / Scale)
				particle:SetGravity(Vector(0, 0, -400 * Scale * Girth ^ 2))
				particle:SetDieTime(math.Rand(4, 6) * Girth)
				particle:SetStartAlpha(255)
				particle:SetEndAlpha(0)
				particle:SetStartSize(50 * Scale * Girth)
				particle:SetEndSize(0)
				particle:SetRoll(math.Rand(-3, 3))
				particle:SetRollDelta(math.Rand(-3, 3))
				particle:SetLighting(false)
				local RealR, RealG, RealB = R, G, B
				if (j < 3) then
					RealR = 255
					RealG = 255
					RealB = 255
				end
				particle:SetColor(RealR, RealG, RealB)
				particle:SetCollide(false)
				if ((not self.Night) or (self.Night and math.random(1, 2) == 2)) then
					if (math.random(1, 2) == 1) then
						local sprite = table.Random({"particle/smokestack", "particles/smokey", "particle/particle_smokegrenade", "sprites/Smoke1", "sprites/Smoke2", "sprites/Smoke3"})
						local particle2 = Emitter:Add(sprite, Pos) -- trailing colored smoke
						if (particle2) then
							particle2:SetVelocity(Dir * 1000 * Scale * Girth ^ .5)
							particle2:SetAirResistance(50 / Scale)
							particle2:SetGravity(Vector(0, 0, -100 * Scale * Girth ^ 2) + JMod.Wind * 200)
							particle2:SetDieTime(math.Rand(4, 12))
							particle2:SetStartAlpha(50)
							particle2:SetEndAlpha(0)
							particle2:SetStartSize(0)
							particle2:SetEndSize(200 * Scale * Girth)
							particle2:SetRoll(math.Rand(-3, 3))
							particle2:SetRollDelta(math.Rand(-3, 3))
							particle2:SetColor(RealR, RealG, RealB)
							particle2:SetLighting(self.Night)
						end
						if (math.random(1, 8) == 2) then
							local sprite2 = table.Random({"particle/smokestack", "particles/smokey", "particle/particle_smokegrenade", "sprites/Smoke1", "sprites/Smoke2", "sprites/Smoke3"})
							local particle3 = Emitter:Add(sprite2, Pos) -- airburst smoke
							if (particle3) then
								particle3:SetVelocity(Dir * 1000 * Scale * Girth)
								particle3:SetAirResistance(150 / Scale)
								particle3:SetGravity(Vector(0, 0, -100 * Scale * Girth ^ 2) + JMod.Wind * 200)
								particle3:SetDieTime(math.Rand(2, 6))
								particle3:SetStartAlpha(50)
								particle3:SetEndAlpha(0)
								particle3:SetStartSize(30 * Scale * (1 - Girth))
								particle3:SetEndSize(60 * Scale * (1 - Girth))
								particle3:SetRoll(math.Rand(-3, 3))
								particle3:SetRollDelta(math.Rand(-3, 3))
								particle3:SetColor(RealR, RealG, RealB)
								particle3:SetLighting(true)
							end
						end
					end
				end
			end
		end
	end
	Emitter:Finish()
end
function EFFECT:Think()
	return self.DieTime > CurTime()
end
function EFFECT:Render()
	local Time = CurTime()
	if (self.DieTime > Time) then
		render.SetMaterial(Flash)
		if (self.FlashTime > Time) then
			local Dir = (self.Pos - EyePos()):GetNormalized()
			render.DrawSprite(self.Pos - Dir * 100, 1000 * self.Scale, 1000 * self.Scale, Color(255, 200, 150, 255))
		end
		if (self.CrackleTime < Time) then
			render.DrawSprite(self.Pos + VectorRand() * math.random(1, 750) * self.Scale, 100 * self.Scale, 100 * self.Scale, Color(255, 200, 75, 255))
			render.DrawSprite(self.Pos + VectorRand() * math.random(1, 750) * self.Scale, 50 * self.Scale, 50 * self.Scale, Color(255, 255, 255, 255))
		end
		return true
	end
	return false
end
