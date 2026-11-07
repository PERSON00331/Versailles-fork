-- Jackarunda 2021
AddCSLuaFile()
ENT.Base = "ent_jack_gmod_ezherockettt"
ENT.Type = "anim"
ENT.Author = "Jackarunda"
ENT.Category = "JMod - EZ Explosives"
ENT.Information = "glhfggwpezpznore"
ENT.PrintName = "EZ Big Missile"
ENT.Spawnable = true
ENT.AdminOnly = true
---
ENT.JModPreferredCarryAngles = Angle(0, 0, 0)
ENT.EZrackOffset = Vector(0, 0, -10)
ENT.EZrackAngles = Angle(0, 0, 0)
ENT.EZrocket = true
---
local STRENGTH_MULTIPLIER = 2.3

-- Inherits the HE rocket motion controller. Only the differences below.
ENT.Model = "models/props_phx/torpedo.mdl"
ENT.Mass = 222
ENT.UpLiftMult = .54
ENT.FuelMax = 1000
--ENT.FuelBooster = 100
ENT.FuelBurn = 10
ENT.ThrustForce = 800000 * STRENGTH_MULTIPLIER
ENT.DetonationSpeed = 300
ENT.CollideDetState = 1 -- STATE_ARMED
ENT.BreakOdds = 5
ENT.ThrustJitter = 0
-- This rocket points/thrusts along its forward axis instead of -right.
ENT.UseClientModel = false
ENT.TurnStrength = 500
-- Effects
ENT.ThrustEffect = "eff_jack_gmod_rocketthrust"
ENT.TrailEffect = "eff_jack_gmod_rockettrail"--"eff_jack_gmod_ezexhaust"
ENT.TrailEffectScale = 4 * STRENGTH_MULTIPLIER
ENT.LaunchEffectScale = 2 * STRENGTH_MULTIPLIER
ENT.LaunchSoundVol = 90
ENT.LaunchSoundPitchMin = 85
ENT.LaunchSoundPitchMax = 95
---
local STATE_BROKEN, STATE_OFF, STATE_ARMED, STATE_LAUNCHED = -1, 0, 1, 2

if SERVER then
	function ENT:GetNoseDir()
		return self:GetForward()
	end

	-- Guidance: update the steering target from the locked entity each think.
	-- The base motion controller steers the nose toward self.TargetPosition.
	function ENT:GuidanceThink()
		if not IsValid(self.Target) then
			self.TargetPosition = self:WorldSpaceCenter() + self:GetForward() * 50000

			return
		end

		local SelfPos = self:WorldSpaceCenter()
		local TargetCenter = self.Target:WorldSpaceCenter()
		local DiffToTarget = TargetCenter - SelfPos
		local Dist = DiffToTarget:Length()
		local OurSpeed = self:GetVelocity():Length()
		local TheirVel = self.Target:GetVelocity()
		local LeadDir = TheirVel:GetNormalized()

		if OurSpeed < 1 then OurSpeed = 1 end
		-- Lead the target based on our travel time to it.
		self.TargetPosition = TargetCenter + LeadDir * ((Dist / OurSpeed) * TheirVel:Length())

		if Dist < 400 then
			self:Detonate()
		end
	end

	function ENT:OnLaunch()
		-- Lock onto the first valid target in front of the rocket.
		for k, v in pairs(ents.FindInCone(self:GetPos(), self:GetForward(), 50000, 0.7)) do
			print("Missile: OnLaunch", v:GetClass(), JMod.ShouldAttack(self, v, true, false))
			if JMod.ShouldAttack(self, v, true, false) then
				self.Target = v

				break
			end
		end
	end

	function ENT:Detonate()
		if self.NextDet > CurTime() then return end
		if self.Exploded then return end
		self.Exploded = true
		local SelfPos, Att, Dir = self:GetPos() + self:GetForward() * 50, JMod.GetEZowner(self), self:GetForward()
		JMod.Sploom(Att, SelfPos, 600 * STRENGTH_MULTIPLIER, 500 * STRENGTH_MULTIPLIER)
		JMod.FragSplosion(self, SelfPos, 50, 35 * STRENGTH_MULTIPLIER, 1000, Att, Dir, .45, nil, false)
		---
		util.ScreenShake(SelfPos, 1000 * STRENGTH_MULTIPLIER, 3, 2, 1500 * STRENGTH_MULTIPLIER)
		self:EmitSound("snd_jack_fragsplodeclose.ogg", 90, 100)
		---
		util.BlastDamage(game.GetWorld(), Att, SelfPos + Vector(0, 0, 50), 250 * STRENGTH_MULTIPLIER, 200 * STRENGTH_MULTIPLIER)

		for k, ent in pairs(ents.FindInSphere(SelfPos, 400 * STRENGTH_MULTIPLIER)) do
			if ent:GetClass() == "npc_helicopter" then
				ent:Fire("selfdestruct", "", math.Rand(0, 2))
			end
		end

		---
		JMod.WreckBuildings(self, SelfPos, 4 * STRENGTH_MULTIPLIER)
		JMod.BlastDoors(self, SelfPos, 4 * STRENGTH_MULTIPLIER)

		---
		timer.Simple(.2, function()
			local Tr = util.QuickTrace(SelfPos - Dir * 100, Dir * 300)

			if Tr.Hit then
				util.Decal("Scorch", Tr.HitPos + Tr.HitNormal, Tr.HitPos - Tr.HitNormal)
			end
		end)

		---
		self:Remove()
		local Ang = self:GetAngles()
		Ang:RotateAroundAxis(Ang:Right(), -90)

		timer.Simple(.1, function()
			ParticleEffect("500lb_air", SelfPos - Dir * 46, Ang)
			ParticleEffect("500lb_air", SelfPos - Dir * 115, Ang)
			ParticleEffect("500lb_air", SelfPos - Dir * 184, Ang)
		end)
	end
elseif CLIENT then
	function ENT:Initialize()
		self:SetModel(self.Model)
	end

	function ENT:Think()
		local Pos, Dir = self:GetPos(), -self:GetForward()
		local Time = CurTime()

		if self:GetState() == STATE_LAUNCHED then
			self.BurnoutTime = self.BurnoutTime or Time + 5
			if self.BurnoutTime > Time then
				local dlight = DynamicLight(self:EntIndex())

				if dlight then
					dlight.pos = Pos + Dir * 45
					dlight.r = 255
					dlight.g = 175
					dlight.b = 100
					dlight.brightness = 2
					dlight.Decay = 200
					dlight.Size = 400
					dlight.DieTime = Time + .5
				end
			end
		end
	end

	--
	local GlowSprite = Material("mat_jack_gmod_glowsprite")

	function ENT:Draw()
		local Pos, Ang, Dir = self:GetPos(), self:GetAngles(), -self:GetForward()
		local Time = CurTime()
		Ang:RotateAroundAxis(Ang:Up(), 90)
		self:DrawModel()

		if self:GetState() == STATE_LAUNCHED then
			self.BurnoutTime = self.BurnoutTime or Time + 5

			if self.BurnoutTime > Time then
				render.SetMaterial(GlowSprite)

				for i = 1, 10 do
					local Inv = 10 - i
					render.DrawSprite(Pos + Dir * (i * 10 + math.random(30, 40)), 5 * Inv, 5 * Inv, Color(255, 255 - i * 10, 255 - i * 20, 255))
				end
			end
		end
	end

	function ENT:OnRemove()
	end

	language.Add("ent_jack_gmod_ezmissile", "EZ Missile")
end
