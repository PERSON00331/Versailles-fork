AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "EZ Coolant Production Facility (CPF)"
ENT.Author = "Jackarunda"
ENT.Category = "JMod - EZ Machines"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Base = "ent_jack_gmod_ezmachine_base"
ENT.Model = "models/props_wasteland/coolingtank01.mdl"
ENT.Mass = 1000
ENT.SpawnHeight = 10
ENT.EZcolorable = true
ENT.EZupgradable = true
ENT.EZproduces = {
	[JMod.EZ_RESOURCE_TYPES.COOLANT] = true
}
ENT.EZconsumes = {
	JMod.EZ_RESOURCE_TYPES.BASICPARTS,
	JMod.EZ_RESOURCE_TYPES.POWER,
	JMod.EZ_RESOURCE_TYPES.WATER,
	JMod.EZ_RESOURCE_TYPES.CHEMICALS
}
ENT.StaticPerfSpecs = {
	MaxDurability = 250,
	MaxElectricity = 500,
	MaxWater = 500,
	MaxChemicals = 500
}
ENT.DynamicPerfSpecs = {
	Armor = 2
}

local STATE_BROKEN, STATE_OFF, STATE_ON = -1, 0, 1
local BASE_BATCH_TIME = 60
local BATCH_TIME_REDUCTION_PER_GRADE = 6
local WATER_PER_BATCH = 50
local CHEMICALS_PER_BATCH = 25
local COOLANT_PER_BATCH = 100

function ENT:CustomSetupDataTables()
	self:NetworkVar("Float", 1, "Progress")
	self:NetworkVar("Float", 2, "Water")
	self:NetworkVar("Float", 3, "Chemicals")
end

if SERVER then
	function ENT:CustomInit()
		self:SetProgress(0)
		self:SetWater(self.SpawnFull and self.MaxWater or 0)
		self:SetChemicals(self.SpawnFull and self.MaxChemicals or 0)
		self.NextProductionTime = 0
		self.NextFacilityThink = 0
	end

	function ENT:HasBatchInputs()
		return self:GetWater() >= WATER_PER_BATCH and self:GetChemicals() >= CHEMICALS_PER_BATCH
	end

	function ENT:GetBatchTime()
		return BASE_BATCH_TIME - math.max(self:GetGrade() - 1, 0) * BATCH_TIME_REDUCTION_PER_GRADE
	end

	function ENT:TurnOn(activator)
		if self:GetState() ~= STATE_OFF then return end
		if self:GetElectricity() <= 0 then
			JMod.Hint(activator, "need cpf power")
			return
		end
		if not self:HasBatchInputs() then
			JMod.Hint(activator, "need cpf supplies")
			return
		end

		if IsValid(activator) then self.EZstayOn = true end
		self.NextProductionTime = CurTime() + self:GetBatchTime()
		self:SetProgress(0)
		self:SetState(STATE_ON)
		self:EmitSound("buttons/button1.wav", 60, 80)
	end

	function ENT:TurnOff(activator)
		if self:GetState() ~= STATE_ON then return end
		self.EZstayOn = nil
		self:SetProgress(0)
		self:SetState(STATE_OFF)
		self:EmitSound("buttons/button18.wav", 60, 80)
	end

	function ENT:Use(activator)
		local OldOwner = JMod.GetEZowner(self)
		JMod.SetEZowner(self, activator)
		if IsValid(self.EZowner) and OldOwner ~= self.EZowner then
			JMod.Colorify(self)
		end

		if self:GetState() == STATE_BROKEN then
			JMod.Hint(activator, "destroyed", self)
		elseif JMod.IsAltUsing(activator) then
			self:ModConnections(activator)
		elseif self:GetState() == STATE_OFF then
			self:TurnOn(activator)
		elseif self:GetState() == STATE_ON then
			self:TurnOff(activator)
		end
	end

	function ENT:ProduceCoolant()
		self:SetWater(self:GetWater() - WATER_PER_BATCH)
		self:SetChemicals(self:GetChemicals() - CHEMICALS_PER_BATCH)
		self:SetProgress(0)

		local SpawnPos = Vector(0, 0, self:OBBMaxs().z + 20)
		local EjectionPos = Vector(0, 0, self:OBBMaxs().z)
		JMod.MachineSpawnResource(self, JMod.EZ_RESOURCE_TYPES.COOLANT, COOLANT_PER_BATCH, SpawnPos, Angle(0, 0, 0), EjectionPos, 300)
		self:EmitSound("snds_jack_gmod/ding.ogg", 80, 120)
	end

	function ENT:Think()
		local Time = CurTime()
		if self.NextFacilityThink <= Time then
			self.NextFacilityThink = Time + .25
			self:UpdateWireOutputs()

			if self:GetState() == STATE_ON then
				if not self:HasBatchInputs() then
					self:TurnOff()
				else
					self:ConsumeElectricity(.25)
					if self:GetState() == STATE_ON then
						if self.NextProductionTime <= Time then
							self:ProduceCoolant()
							if self:HasBatchInputs() then
								self.NextProductionTime = Time + self:GetBatchTime()
							else
								self:TurnOff()
							end
						else
							local BatchTime = self:GetBatchTime()
							local Remaining = self.NextProductionTime - Time
							self:SetProgress(math.Clamp((1 - Remaining / BatchTime) * 100, 0, 100))
						end
					end
				end
			end
		end

		self:NextThink(self.NextFacilityThink)
		return true
	end
elseif CLIENT then
	local function DrawFacilityDisplay(pos, ang, power, water, chemicals, progress, batchTime, powerFraction, waterFraction, chemicalsFraction)
		cam.Start3D2D(pos, ang, .12)
			surface.SetDrawColor(10, 10, 10, 200)
			surface.DrawRect(-115, -12, 230, 186)
			draw.SimpleTextOutlined("CPF", "JMod-Display", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0))
			draw.SimpleTextOutlined("POWER " .. math.Round(power) .. "/500", "JMod-Display", 0, 28, JMod.GoodBadColor(powerFraction, true), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0))
			draw.SimpleTextOutlined("WATER " .. math.Round(water) .. "/500", "JMod-Display", 0, 56, JMod.GoodBadColor(waterFraction, true), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0))
			draw.SimpleTextOutlined("CHEMICALS " .. math.Round(chemicals) .. "/500", "JMod-Display", 0, 84, JMod.GoodBadColor(chemicalsFraction, true), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0))
			draw.SimpleTextOutlined("COOLANT +100 / " .. batchTime .. "s", "JMod-Display", 0, 112, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0))
			surface.SetDrawColor(50, 50, 50, 220)
			surface.DrawRect(-100, 148, 200, 8)
			surface.SetDrawColor(80, 190, 230, 240)
			surface.DrawRect(-100, 148, 200 * progress, 8)
		cam.End3D2D()
	end

	function ENT:Draw()
		self:DrawModel()
		if LocalPlayer():GetFOV() * EyePos():Distance(self:GetPos()) >= 90000 then return end

		local Mins, Maxs = self:OBBMins(), self:OBBMaxs()
		local CenterY, CenterZ = (Mins.y + Maxs.y) / 2, (Mins.z + Maxs.z) / 2
		local FrontPos = self:LocalToWorld(Vector(Mins.x - 2, CenterY, CenterZ))
		local BackPos = self:LocalToWorld(Vector(Maxs.x + 2, CenterY, CenterZ))
		local Water, Chemicals = self:GetWater(), self:GetChemicals()
		local Power = self:GetElectricity()
		local PowerFraction = math.Clamp(Power / self.MaxElectricity, 0, 1)
		local WaterFraction = math.Clamp(Water / self.MaxWater, 0, 1)
		local ChemicalsFraction = math.Clamp(Chemicals / self.MaxChemicals, 0, 1)
		local ProgressFraction = math.Clamp(self:GetProgress() / 100, 0, 1)
		local BatchTime = 60 - math.max(self:GetGrade() - 1, 0) * 6

		local Ang = self:GetAngles()
		Ang:RotateAroundAxis(Ang:Right(), 90)
		Ang:RotateAroundAxis(Ang:Up(), -90)
		DrawFacilityDisplay(FrontPos, Ang, Power, Water, Chemicals, ProgressFraction, BatchTime, PowerFraction, WaterFraction, ChemicalsFraction)
		Ang:RotateAroundAxis(Ang:Right(), 180)
		DrawFacilityDisplay(BackPos, Ang, Power, Water, Chemicals, ProgressFraction, BatchTime, PowerFraction, WaterFraction, ChemicalsFraction)
	end

	language.Add("ent_jack_gmod_ezcoolantproductionfacility", "EZ Coolant Production Facility (CPF)")
end
