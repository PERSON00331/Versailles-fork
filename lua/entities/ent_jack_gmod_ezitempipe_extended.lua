AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "ent_jack_gmod_ezitempipe"
ENT.PrintName = "EZ Extended Item Pipe"
ENT.Category = "JMod - EZ Pipes"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.MaxConnectionRange = 2000
ENT.TransferDelay = .69
ENT.IconOverride = "materials/entities/ent_jack_gmod_ezitempipe.png"

if CLIENT then
	language.Add("ent_jack_gmod_ezitempipe_extended", "EZ Extended Item Pipe")
end
