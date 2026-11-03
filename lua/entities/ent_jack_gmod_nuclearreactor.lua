AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "ent_jack_gmod_ezmachine_base"
ENT.PrintName = "EZ Nuclear Reactor"
ENT.Author = "Jackarunda"
ENT.Category = "JMod - EZ Machines"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.Model = "models/props/de_nuke/coolingtank.mdl"
ENT.Mass = 8000
ENT.SpawnHeight = 30
ENT.EZcolorable = true
ENT.EZupgradable = true
ENT.EZpowerProducer = true
ENT.EZproduces = {
	[JMod.EZ_RESOURCE_TYPES.POWER] = true,
	[JMod.EZ_RESOURCE_TYPES.FISSILEMATERIAL] = true
}
ENT.MaxConnectionRange = 1000
ENT.JModPreferredCarryAngles = Angle(0, 0, 0)
ENT.EZconsumes = {
	JMod.EZ_RESOURCE_TYPES.BASICPARTS,
	JMod.EZ_RESOURCE_TYPES.WATER,
	JMod.EZ_RESOURCE_TYPES.URANIUM
}
ENT.StaticPerfSpecs = {
	MaxDurability = 500,
	MaxWater = 500,
	MaxUranium = 500
}
ENT.DynamicPerfSpecs = {
	Armor = 3
}

local STATE_BROKEN, STATE_OFF, STATE_ON = -1, 0, 1
local WATER_OUT_MELTDOWN_TIME = 120
local MIN_MANUAL_SHUTDOWN_PROGRESS = 30
local STEAM_INTERVAL = .5
local HEAT_RISE_TIME = 60
local HEAT_COOLDOWN_TIME = 30
local FALLOUT_PARTICLE_COUNT = 15
local FALLOUT_PARTICLE_RANGE = 1500

function ENT:StopReactorSound()
	if self.SoundLoop then
		self.SoundLoop:Stop()
		self.SoundLoop = nil
	end
end

function ENT:StopMeltdownAlarm()
	if self.MeltdownAlarmSound then
		self.MeltdownAlarmSound:Stop()
		self.MeltdownAlarmSound = nil
	end
end

function ENT:CustomSetupDataTables()
	self:NetworkVar("Float", 1, "Progress")
	self:NetworkVar("Float", 2, "Water")
	self:NetworkVar("Float", 3, "Uranium")
	self:NetworkVar("Float", 4, "Heat")
end

if SERVER then
	function ENT:CustomInit()
		self:SetProgress(0)
		self:SetWater(self.SpawnFull and self.MaxWater or 0)
		self:SetUranium(self.SpawnFull and self.MaxUranium or 0)
		self:SetHeat(0)
		self.LastHeatUpdate = CurTime()
		self.NextReactorThink = 0
		self.NextMeltdownAlarm = 0
	end

	function ENT:Use(activator)
		local OldOwner = JMod.GetEZowner(self)
		JMod.SetEZowner(self, activator)
		if IsValid(self.EZowner) and OldOwner ~= self.EZowner then
			JMod.Colorify(self)
		end

		if self:GetState() == STATE_BROKEN then
			JMod.Hint(activator, "destroyed", self)
			return
		end

		if JMod.IsAltUsing(activator) then
			self:ModConnections(activator)
		elseif self:GetState() == STATE_OFF then
			self:TurnOn(activator)
		elseif self:GetState() == STATE_ON then
			self:TurnOff(activator)
		end
	end

	function ENT:TurnOn(activator)
		if self:GetState() ~= STATE_OFF then return end
		if self:GetWater() <= 0 then
			JMod.Hint(activator, "need reactor water")
			return
		end
		if self:GetUranium() < .5 then
			JMod.Hint(activator, "need reactor uranium")
			return
		end

		if IsValid(activator) then self.EZstayOn = true end
		self:SetState(STATE_ON)
		self.WaterOutTime = nil
		self.NextMeltdownAlarm = 0
		self:EmitSound("ambient/machines/thumper_startup1.wav")
		timer.Simple(.8, function()
			if not IsValid(self) or self:GetState() ~= STATE_ON then return end
			self.SoundLoop = CreateSound(self, "snds_jack_gmod/ezbhg_hum.wav")
			self.SoundLoop:Play()
			self.SoundLoop:SetSoundLevel(70)
			self.SoundLoop:ChangeVolume(.25)
		end)
	end

	function ENT:TurnOff(activator, forced)
		if self:GetState() ~= STATE_ON then return end
		if not forced and self:GetProgress() < MIN_MANUAL_SHUTDOWN_PROGRESS then
			JMod.Hint(activator, "reactor shutdown threshold")
			return
		end

		self.EZstayOn = nil
		self:ProduceResources()
		self:SetState(STATE_OFF)
		self.WaterOutTime = nil
		self.NextMeltdownAlarm = 0
		self:StopReactorSound()
		self:StopMeltdownAlarm()
		self:EmitSound("buttons/button18.wav", 60, 80)
	end

	function ENT:ProduceResources()
		local Progress = math.Clamp(self:GetProgress(), 0, 100)
		if Progress <= 0 then return end

		local EjectionPos = Vector(0, 0, self:OBBMaxs().z)
		local SpawnPos = EjectionPos + Vector(0, 0, 20)
		local PowerAmount = Progress >= MIN_MANUAL_SHUTDOWN_PROGRESS
			and 500 * Progress / 100
			or Progress * (.5 + 4.5 * Progress / MIN_MANUAL_SHUTDOWN_PROGRESS)
		local GradeMultiplier = JMod.EZ_GRADE_BUFFS[self:GetGrade()]
		self:SetProgress(0)
		JMod.MachineSpawnResource(self, JMod.EZ_RESOURCE_TYPES.FISSILEMATERIAL, 10 * Progress / 100 * GradeMultiplier, SpawnPos, Angle(0, 0, 0), EjectionPos, 300)
		JMod.MachineSpawnResource(self, JMod.EZ_RESOURCE_TYPES.POWER, PowerAmount * GradeMultiplier, SpawnPos, Angle(0, 0, 0), EjectionPos, 300)
		self:EmitSound("items/suitchargeok1.wav", 80, 120)
	end

	function ENT:Meltdown()
		if self.MeltingDown then return end
		self.MeltingDown = true
		self:SetState(STATE_BROKEN)
		self:StopReactorSound()
		self:StopMeltdownAlarm()

		local Moab = ents.Create("ent_jack_gmod_ezmoab")
		if not IsValid(Moab) then
			ErrorNoHalt("EZ Nuclear Reactor meltdown failed: could not create EZ Mega Bomb\n")
			return
		end

		local Pos, Owner = self:GetPos(), JMod.GetEZowner(self) or game.GetWorld()
		Moab:SetPos(Pos + self:GetUp() * 20)
		Moab:SetAngles(self:GetAngles())
		JMod.SetEZowner(Moab, Owner)
		Moab:Spawn()
		Moab:Activate()
		Moab:Detonate()

		local RadiationMultiplier = JMod.Config.Particles.NuclearRadiationMult
		local FalloutCount = math.max(0, math.min(FALLOUT_PARTICLE_COUNT, math.ceil(FALLOUT_PARTICLE_COUNT * RadiationMultiplier)))

		for i = 1, FalloutCount do
			local Fallout = ents.Create("ent_jack_gmod_ezfalloutparticle")
			if not IsValid(Fallout) then
				ErrorNoHalt("EZ Nuclear Reactor meltdown: could not create fallout particle\n")
				break
			end

			Fallout.AffectRange = FALLOUT_PARTICLE_RANGE
			Fallout:SetPos(Pos + VectorRand() * math.Rand(500, 2500))
			JMod.SetEZowner(Fallout, Owner)
			Fallout:Spawn()
			Fallout:Activate()
			Fallout.CurVel = VectorRand() * math.random(1, 500) + Vector(0, 0, 10 * RadiationMultiplier)
		end

		self:Remove()
	end

	function ENT:OnBreak()
		self:StopReactorSound()
		self:StopMeltdownAlarm()
	end

	function ENT:OnRemove()
		self:StopReactorSound()
		self:StopMeltdownAlarm()
	end

	function ENT:Think()
		local Time, State = CurTime(), self:GetState()
		self:UpdateWireOutputs()

		if State == STATE_ON and (self.NextSteamTime or 0) <= Time then
			local Steam = EffectData()
			Steam:SetOrigin(self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z)))
			Steam:SetNormal(self:GetUp())
			Steam:SetScale(1)
			local Phys = self:GetPhysicsObject()
			if IsValid(Phys) then Steam:SetStart(Phys:GetVelocity()) end
			util.Effect("eff_jack_gmod_ezsteam", Steam, true, true)
			self.NextSteamTime = Time + STEAM_INTERVAL
		end

		if self.NextReactorThink > Time then
			local NextThinkTime = self.NextReactorThink
			if State == STATE_ON and self.NextSteamTime then
				NextThinkTime = math.min(NextThinkTime, self.NextSteamTime)
			end
			self:NextThink(NextThinkTime)
			return true
		end
		self.NextReactorThink = Time + 1

		local HeatElapsed = math.max(Time - (self.LastHeatUpdate or Time), 0)
		self.LastHeatUpdate = Time
		if State == STATE_ON then
			local WaterFraction = math.Clamp(self:GetWater() / self.MaxWater, 0, 1)
			local HeatIncrease = (1 - WaterFraction) * 100 / HEAT_RISE_TIME * HeatElapsed
			self:SetHeat(math.min(self:GetHeat() + HeatIncrease, 100))

			if self:GetWater() <= 0 then
				self.WaterOutTime = self.WaterOutTime or Time
				if self.NextMeltdownAlarm <= Time then
					if not self.MeltdownAlarmSound then
						self.MeltdownAlarmSound = CreateSound(self, "snds_jack_gmod/klaxon_alarm_short.ogg")
					end
					self.MeltdownAlarmSound:SetSoundLevel(90)
					self.MeltdownAlarmSound:ChangeVolume(1)
					self.MeltdownAlarmSound:Play()
					timer.Simple(2, function()
						if IsValid(self) then self:StopMeltdownAlarm() end
					end)
					self.NextMeltdownAlarm = Time + 5
				end

				if Time - self.WaterOutTime >= WATER_OUT_MELTDOWN_TIME then
					self:Meltdown()
					return true
				end
			else
				self.WaterOutTime = nil
				self.NextMeltdownAlarm = 0

				if self:GetUranium() < .5 then
					self:TurnOff(nil, true)
				else
					local GradeMultiplier = JMod.EZ_GRADE_BUFFS[self:GetGrade()]
					self:SetWater(math.max(self:GetWater() - GradeMultiplier, 0))
					self:SetUranium(math.max(self:GetUranium() - .5 * GradeMultiplier, 0))
					self:SetProgress(self:GetProgress() + .5 * GradeMultiplier)

					if self:GetProgress() >= 100 then
						self:ProduceResources()
					end
				end
			end
		else
			self:SetHeat(math.max(self:GetHeat() - 100 / HEAT_COOLDOWN_TIME * HeatElapsed, 0))
		end

		self:NextThink(Time + 1)
		return true
	end
elseif CLIENT then
	local function DrawReactorDisplay(pos, ang, progress, water, uranium, heat)
		local ProgressR, ProgressG, ProgressB = JMod.GoodBadColor(progress / 100)
		local WaterR, WaterG, WaterB = JMod.GoodBadColor(water / 500)
		local UraniumR, UraniumG, UraniumB = JMod.GoodBadColor(uranium / 500)
		local HeatR, HeatG, HeatB = JMod.GoodBadColor(heat / 100)
		local HeatFraction = math.Clamp(heat / 100, 0, 1)

		cam.Start3D2D(pos, ang, .16)
		surface.SetDrawColor(10, 10, 10, 180)
		surface.DrawRect(-140, -8, 280, 196)
		draw.SimpleTextOutlined("PROGRESS", "JMod-Display", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0))
		draw.SimpleTextOutlined(tostring(math.Round(progress)) .. "%", "JMod-Display", 0, 32, Color(ProgressR, ProgressG, ProgressB), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0))
		draw.SimpleTextOutlined("WATER  " .. tostring(math.Round(water)) .. "/" .. 500, "JMod-Display", 0, 68, Color(WaterR, WaterG, WaterB), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0))
		draw.SimpleTextOutlined("URANIUM  " .. tostring(math.Round(uranium)) .. "/" .. 500, "JMod-Display", 0, 104, Color(UraniumR, UraniumG, UraniumB), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0))
		draw.SimpleTextOutlined("HEAT  " .. tostring(math.Round(heat)) .. "%", "JMod-Display", 0, 140, Color(HeatR, HeatG, HeatB), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0))
		surface.SetDrawColor(50, 50, 50, 220)
		surface.DrawRect(-130, 174, 260, 10)
		surface.SetDrawColor(HeatR, HeatG, HeatB, 240)
		surface.DrawRect(-130, 174, 260 * HeatFraction, 10)
		cam.End3D2D()
	end

	function ENT:Draw()
		local Ang, Pos = self:GetAngles(), self:GetPos()
		self:DrawModel()

		local Closeness = LocalPlayer():GetFOV() * EyePos():Distance(Pos)
		if Closeness >= 120000 then return end

		local Mins, Maxs = self:OBBMins(), self:OBBMaxs()
		local CenterY, CenterZ = (Mins.y + Maxs.y) / 2, (Mins.z + Maxs.z) / 2
		local FrontPos = self:LocalToWorld(Vector(Mins.x - 2, CenterY, CenterZ))
		local BackPos = self:LocalToWorld(Vector(Maxs.x + 2, CenterY, CenterZ))
		local Progress, Water, Uranium, Heat = self:GetProgress(), self:GetWater(), self:GetUranium(), self:GetHeat()

		Ang:RotateAroundAxis(Ang:Right(), 90)
		Ang:RotateAroundAxis(Ang:Up(), -90)
		DrawReactorDisplay(FrontPos, Ang, Progress, Water, Uranium, Heat)

		Ang:RotateAroundAxis(Ang:Right(), 180)
		DrawReactorDisplay(BackPos, Ang, Progress, Water, Uranium, Heat)
	end

	language.Add("ent_jack_gmod_nuclearreactor", "EZ Nuclear Reactor")
end
