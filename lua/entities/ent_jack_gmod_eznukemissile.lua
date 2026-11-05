AddCSLuaFile()
ENT.Base = "ent_jack_gmod_eznukerocket"
ENT.Type = "anim"
ENT.Author = "Jackarunda"
ENT.Category = "JMod - EZ Explosives"
ENT.PrintName = "EZ Nuclear Missile"
ENT.Spawnable = true
ENT.AdminOnly = true
---
ENT.JModPreferredCarryAngles = Angle(0, 90, 0)
ENT.EZrackOffset = Vector(0, 0, -10)
ENT.EZrackAngles = Angle(0, 90, 180)
ENT.EZrocket = true

if CLIENT then
	language.Add("ent_jack_gmod_eznukemissile", "EZ Nuclear Missile")
end
