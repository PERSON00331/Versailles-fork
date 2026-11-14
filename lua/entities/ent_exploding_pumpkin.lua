
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Exploding Pumpkin"
ENT.Author = "spooky"
ENT.Spawnable = true
ENT.Category = "JMod - EZ Misc."

if CLIENT then
    language.Add("ent_exploding_pumpkin", "Exploding Pumpkin")

    killicon.Add("ent_exploding_pumpkin","jmod/spade/pumpkin",Color(255, 128, 0, 255))

    net.Receive("ExplodingPumpkinThrowSound", function()
        surface.PlaySound("pumpkin_throw.wav")
    end)
end

if SERVER then
    util.AddNetworkString("ExplodingPumpkinThrowSound")

    local GibModels = {
        "models/props_outland/pumpkin01_chunk01b.mdl",
        "models/props_outland/pumpkin01_chunk01a.mdl",
        "models/props_outland/pumpkin01_chunk02a.mdl"
    }

    function ENT:Initialize()
        self:SetModel("models/props_outland/pumpkin01_explosive.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local Phys = self:GetPhysicsObject()

        if IsValid(Phys) then
            Phys:Wake()
            Phys:SetMass(150)
        end

        self:SetOwner(NULL)
        self.WasHeld = false
        self.Exploded = false
    end

    function ENT:Use(activator, caller)
        if not IsValid(activator) or not activator:IsPlayer() then return end

        if self:IsPlayerHolding() then
            activator:DropObject()
        else
            self:SetOwner(activator)
            activator:PickupObject(self)
        end
    end

    function ENT:GravGunOnPickedUp(ply)
        if IsValid(ply) and ply:IsPlayer() then
            self:SetOwner(ply)
        end
    end

    function ENT:OnPhysgunPickup(ply)
        if IsValid(ply) and ply:IsPlayer() then
            self:SetOwner(ply)
        end
    end

    function ENT:Think()
        local Held = self:IsPlayerHolding()

        if self.WasHeld and not Held then
            local Phys = self:GetPhysicsObject()
            local Owner = self:GetOwner()

            if IsValid(Phys) then
                local AimDir

                if IsValid(Owner) and Owner:IsPlayer() then
                    AimDir = Owner:EyeAngles():Forward()
                else
                    AimDir = Phys:GetVelocity():GetNormalized()
                end

                if AimDir:LengthSqr() > 0 then
                    Phys:ApplyForceCenter(AimDir * 900000)

                    if IsValid(Owner) and Owner:IsPlayer() then
                        Owner:SetVelocity(-AimDir * 769)

                        net.Start("ExplodingPumpkinThrowSound")
                        net.Send(Owner)
                    end
                end
            end
        end

        self.WasHeld = Held

        self:NextThink(CurTime() + 0.05)
        return true
    end

    function ENT:PhysicsCollide(data, phys)
        if self.Exploded then return end

        if data.HitEntity and data.HitEntity:IsPlayer() and data.Speed < 300 then
            return
        end

        if data.Speed > 450 then
            self:Explode()
        end
    end

    function ENT:Explode()
        if self.Exploded then return end

        self.Exploded = true

        local Pos = self:GetPos()
        local Radius = 250
        local Attacker = self:GetOwner()

        if not IsValid(Attacker) or not Attacker:IsPlayer() then
            Attacker = self
        end

        for _, ent in ipairs(ents.FindInSphere(Pos, Radius)) do
            if not IsValid(ent) then continue end

            if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
                local DistFrac = 1 - math.Clamp(Pos:Distance(ent:GetPos()) / Radius, 0, 1)
                local DmgAmount = math.Round(120 * DistFrac)

                if DmgAmount > 0 then
                    local DmgInfo = DamageInfo()

                    DmgInfo:SetDamage(DmgAmount)
                    DmgInfo:SetDamageType(DMG_BLAST)
                    DmgInfo:SetAttacker(Attacker)
                    DmgInfo:SetInflictor(self)
                    DmgInfo:SetDamagePosition(Pos)

                    ent:TakeDamageInfo(DmgInfo)
                end
            end
        end

        self:EmitSound("ambient/explosions/explode_4.wav", 100, 100)
        self:EmitSound("BaseExplosionEffect.Sound")

        local EffectData = EffectData()
        EffectData:SetOrigin(Pos)

        util.Effect("Explosion", EffectData)

        for i = 1, math.random(2, 4) do
            local Gib = ents.Create("prop_physics")

            if not IsValid(Gib) then continue end

            Gib:SetModel(GibModels[math.random(#GibModels)])
            Gib:SetPos(Pos + VectorRand() * 5)
            Gib:SetAngles(AngleRand())
            Gib:Spawn()
            Gib:Activate()

            local Phys = Gib:GetPhysicsObject()

            if IsValid(Phys) then
                Phys:Wake()

                Phys:SetVelocity(
                    VectorRand() * math.random(300, 700) +
                    Vector(0, 0, math.random(200, 500))
                )

                Phys:AddAngleVelocity(VectorRand() * 500)
            end

            SafeRemoveEntityDelayed(Gib, 8)
        end

        SafeRemoveEntity(self)
    end
end
