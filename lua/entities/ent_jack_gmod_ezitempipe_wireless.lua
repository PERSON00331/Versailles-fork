AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "ent_jack_gmod_ezitempipe"
ENT.PrintName = "EZ Wireless Item Pipe"
ENT.Category = "JMod - EZ Pipes"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.MaxConnectionRange = math.huge
ENT.SpawnRopeLength = 100000000
ENT.NoSpoolRope = true
ENT.NoInitialPickup = true
ENT.TransferDelayPer350 = .15
ENT.IconOverride = "materials/entities/ent_jack_gmod_ezitempipe.png"

if CLIENT then
	language.Add("ent_jack_gmod_ezitempipe_wireless", "EZ Wireless Item Pipe")
end
