AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "ent_jack_gmod_ezfuellantern"
ENT.PrintName = "EZ Oil Lantern"
ENT.Category = "JMod - EZ Misc."
ENT.IconOverride = "materials/entities/ent_jack_gmod_ezfuellantern.png"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.FuelResource = JMod.EZ_RESOURCE_TYPES.OIL
ENT.EZconsumes = {JMod.EZ_RESOURCE_TYPES.OIL}

if CLIENT then
	language.Add("ent_jack_gmod_ezoillantern", "EZ Oil Lantern")
end
