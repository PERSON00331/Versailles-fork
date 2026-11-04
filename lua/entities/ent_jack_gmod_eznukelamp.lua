AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "ent_jack_gmod_ezoillantern"
ENT.PrintName = "EZ Nuclear Lamp"
ENT.Category = "JMod - EZ Misc."
ENT.IconOverride = "materials/entities/ent_jack_gmod_ezfuellantern.png"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.SelfPowered = true
ENT.EZconsumes = {}
ENT.FuelResource = nil
ENT.ProjectedLightBrightness = 1.8
ENT.ProjectedLightRange = 1800
ENT.DynamicLightBrightness = .36
ENT.DynamicLightRange = 2700

if CLIENT then
	language.Add("ent_jack_gmod_eznukelamp", "EZ Nuclear Lamp")
end
