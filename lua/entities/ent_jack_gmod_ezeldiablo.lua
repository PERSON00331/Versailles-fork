AddCSLuaFile()
ENT.Base = "ent_jack_gmod_ezfirework"
ENT.Type = "anim"
ENT.Author = "Jackarunda"
ENT.Category = "JMod - EZ Explosives"
ENT.Information = "glhfggwpezpznore"
ENT.PrintName = "El Diablo"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.AdminOnly = true
ENT.ModelScale = 5
ENT.ExplosionScale = 10
ENT.ThrustForce = 1000000

if CLIENT then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetModelScale(self.ModelScale, 0)
	end

	language.Add("ent_jack_gmod_ezeldiablo", "El Diablo")
end
