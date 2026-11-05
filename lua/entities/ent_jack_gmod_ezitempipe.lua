AddCSLuaFile()
ENT.Type = "anim"
ENT.PrintName = "EZ Item Pipe"
ENT.Author = "Jackarunda"
ENT.Category = "JMod - EZ Pipes"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.NoSitAllowed = true
ENT.MaxConnectionRange = 1000
ENT.SourcePlugColor = Color(255, 0, 0)
ENT.IconOverride = "materials/entities/ent_jack_gmod_ezitempipe.png"

local function GetMachineOutputs(machine)
	local OutputSet = {}
	if istable(machine.EZproduces) then
		for Key, Value in pairs(machine.EZproduces) do
			local ResourceType = isnumber(Key) and Value or (Value and Key)
			if isstring(ResourceType) and JMod.EZ_RESOURCE_ENTITIES[ResourceType] then
				OutputSet[ResourceType] = true
			end
		end
	end

	for _, getterName in ipairs({"GetResourceType", "GetFluidType"}) do
		local getter = machine[getterName]
		if isfunction(getter) then
			local ResourceType = getter(machine)
			if isstring(ResourceType) and JMod.EZ_RESOURCE_ENTITIES[ResourceType] then
				OutputSet[ResourceType] = true
			end
		end
	end

	if machine.EZpowerProducer then
		OutputSet[JMod.EZ_RESOURCE_TYPES.POWER] = true
	end

	local Outputs = {}
	for ResourceType in pairs(OutputSet) do
		table.insert(Outputs, ResourceType)
	end
	table.sort(Outputs)
	return Outputs
end

local function GetAvailableMachineOutput(machine, outputs)
	local UsedOutputs = {}
	for _, className in ipairs({"ent_jack_gmod_ezitempipe", "ent_jack_gmod_ezitempipe_extended", "ent_jack_gmod_ezitempipe_wireless"}) do
		for _, pipe in ipairs(ents.FindByClass(className)) do
			if pipe.SourceEnt == machine and IsValid(pipe.SourceWeld) and pipe.ResourceType then
				UsedOutputs[pipe.ResourceType] = true
			end
		end
	end

	for Index, ResourceType in ipairs(outputs) do
		if not UsedOutputs[ResourceType] then
			return ResourceType, Index
		end
	end
end

if SERVER then
	function ENT:SpawnFunction(ply, tr)
		local Pipe = ents.Create(self.ClassName)
		if not IsValid(Pipe) then return end
		Pipe:SetPos(tr.HitPos + tr.HitNormal * 10)
		JMod.SetEZowner(Pipe, ply)
		Pipe:Spawn()
		Pipe:Activate()
		JMod.Hint(ply, self.ClassName)
		return Pipe
	end

	function ENT:CreatePlug(position, owner)
		local Plug = ents.Create("ent_jack_gmod_ezhook")
		if not IsValid(Plug) then return end
		Plug:SetPos(position)
		Plug:SetAngles(Angle(180, 0, 0))
		Plug.Model = "models/props_lab/tpplug.mdl"
		Plug.EZhookType = "ItemPipe"
		Plug.ItemPipeController = self
		JMod.SetEZowner(Plug, owner)
		Plug:Spawn()
		Plug:Activate()
		return Plug
	end

	function ENT:Initialize()
		self:SetNoDraw(true)
		self:SetNotSolid(true)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
		self:DrawShadow(false)
		self:SetNW2Bool("EZitempipeConnected", false)
		self.NextConnect = 0

		local Owner = JMod.GetEZowner(self)
		local Position = self:GetPos()
		self.SourcePlug = self:CreatePlug(Position, Owner)
		self.DestinationPlug = self:CreatePlug(Position + Vector(0, 0, 20), Owner)
		if not (IsValid(self.SourcePlug) and IsValid(self.DestinationPlug)) then
			self:Remove()
			return
		end
		self.SourcePlug:SetColor(self.SourcePlugColor)

		local SpoolConstraint, SpoolRope = constraint.Rope(self.SourcePlug, self.DestinationPlug, 0, 0, Vector(0, 0, 0), Vector(0, 0, 0), self.SpawnRopeLength or self.MaxConnectionRange, 0, 1000, self.NoSpoolRope and 0 or 3, "cable/cable2", false)
		if not IsValid(SpoolConstraint) then
			self:Remove()
			return
		end
		if self.NoSpoolRope and IsValid(SpoolRope) then SpoolRope:SetNoDraw(true) end
		self.SpoolRope = SpoolConstraint
		self.SourcePlug.Chain = SpoolConstraint
		self.DestinationPlug.Chain = SpoolConstraint

		if IsValid(Owner) and not self.NoInitialPickup then
			timer.Simple(.1, function()
				if IsValid(Owner) and IsValid(self.SourcePlug) and not self:GetNW2Bool("EZitempipeConnected") then
					Owner:PickupObject(self.SourcePlug)
				end
			end)
		end
	end

	function ENT:OnPipePlugCollision(plug, hitEntity, hitPos, hitNormal, player)
		if self:GetNW2Bool("EZitempipeConnected") or CurTime() < self.NextConnect then return end
		if not (IsValid(plug) and IsValid(hitEntity) and IsValid(player)) then return end
		if hitEntity == self.SourcePlug or hitEntity == self.DestinationPlug then return end
		self.NextConnect = CurTime() + 1

		if not IsValid(self.SourceEnt) then
			if plug ~= self.SourcePlug then
				JMod.Hint(player, "item pipe wrong order")
				return
			end

			if hitEntity.IsJackyEZcrate and hitEntity.GetResourceType then
				local ResourceType = hitEntity:GetResourceType()
				if not ResourceType or ResourceType == "generic" then
					JMod.Hint(player, "item pipe empty source")
					return
				end
				if not JMod.ShouldAllowControl(hitEntity, player, true) then
					JMod.Hint(player, "item pipe bad connection")
					return
				end
				self.ResourceType = ResourceType
			else
				local Outputs = GetMachineOutputs(hitEntity)
				if #Outputs == 0 then
					JMod.Hint(player, "item pipe wrong order")
					return
				end
				if not JMod.ShouldAllowControl(hitEntity, player, true) then
					JMod.Hint(player, "item pipe bad connection")
					return
				end
				local ResourceType, OutputIndex = GetAvailableMachineOutput(hitEntity, Outputs)
				if not ResourceType then
					JMod.Hint(player, "item pipe all outputs connected")
					return
				end
				self.OutputTypes = Outputs
				self.OutputTypeIndex = OutputIndex
				self.ResourceType = ResourceType
			end

			plug:SetPos(hitPos + hitNormal * 20)
			plug:SetAngles(hitNormal:Angle())
			local SourceWeld = constraint.Weld(plug, hitEntity, 0, 0, 5000, false, false)
			if not IsValid(SourceWeld) then
				JMod.Hint(player, "item pipe bad connection")
				return
			end

			self.SourceEnt = hitEntity
			self.SourceWeld = SourceWeld
			self.SourcePlugPos = hitEntity:WorldToLocal(plug:GetPos())
			self.SourcePlug = plug
			JMod.SetEZowner(self, player)
			if self.NoSpoolRope and IsValid(self.SpoolRope) then
				self.SpoolRope:Remove()
				self.SpoolRope = nil
				self.SourcePlug.Chain = SourceWeld
				self.DestinationPlug.Chain = SourceWeld
			end
			JMod.Hint(player, "item pipe source attached")
			if self.OutputTypes and #self.OutputTypes > 1 then
				JMod.Hint(player, "item pipe output select")
			end
			local OutputInstruction = self.OutputTypes and #self.OutputTypes > 1 and " This pipe is auto-assigned an unused output." or ""
			player:PrintMessage(HUD_PRINTCENTER, "Source attached: " .. string.upper(self.ResourceType) .. "." .. OutputInstruction .. " Pick up the second plug and connect the destination.")
			player:DropObject()

			local OtherPlug = self.DestinationPlug
			timer.Simple(.1, function()
				if IsValid(player) and IsValid(OtherPlug) and IsValid(self) and not self:GetNW2Bool("EZitempipeConnected") then
					player:PickupObject(OtherPlug)
				end
			end)
			return
		end

		if plug ~= self.DestinationPlug then
			JMod.Hint(player, "item pipe wrong order")
			return
		end

		local Source = self.SourceEnt
		local ResourceType = self.ResourceType
		local SourceIsCrate = Source.IsJackyEZcrate
		local DestinationIsCrate = hitEntity.IsJackyEZcrate
		local Compatible

		if SourceIsCrate then
			Compatible = hitEntity.TryLoadResource and (
				(DestinationIsCrate
					and hitEntity.GetResourceType
					and (hitEntity:GetResourceType() == "generic" or hitEntity:GetResourceType() == ResourceType))
				or (not DestinationIsCrate
					and hitEntity.EZconsumes
					and table.HasValue(hitEntity.EZconsumes, ResourceType))
			)
		else
			Compatible = DestinationIsCrate
				and hitEntity.GetResourceType
				and (hitEntity:GetResourceType() == "generic" or hitEntity:GetResourceType() == ResourceType)
				and hitEntity.TryLoadResource
		end

		if not Compatible then
			JMod.Hint(player, SourceIsCrate and "item pipe bad connection" or "item pipe wrong order")
			return
		end
		if not JMod.ShouldAllowControl(Source, player, true) or not JMod.ShouldAllowControl(hitEntity, player, true) then
			JMod.Hint(player, "item pipe bad connection")
			return
		end

		plug:SetPos(hitPos + hitNormal * 20)
		plug:SetAngles(hitNormal:Angle())
		local DestinationWeld = constraint.Weld(plug, hitEntity, 0, 0, 5000, false, false)
		if not IsValid(DestinationWeld) then
			JMod.Hint(player, "item pipe bad connection")
			return
		end

		local SourcePlugPos = Source:WorldToLocal(self.SourcePlug:GetPos())
		local DestinationPlugPos = hitEntity:WorldToLocal(plug:GetPos())
		local Distance = self.SourcePlug:GetPos():Distance(plug:GetPos())
		if Distance > self.MaxConnectionRange then
			DestinationWeld:Remove()
			JMod.Hint(player, "item pipe bad connection")
			return
		end

		local Cable = JMod.CreateResourceConnection(Source, hitEntity, ResourceType, SourcePlugPos, DestinationPlugPos, Distance + 20, nil, DestinationIsCrate, self.NoSpoolRope)
		if not IsValid(Cable) then
			DestinationWeld:Remove()
			JMod.Hint(player, "item pipe bad connection")
			return
		end

		local CableData = Cable:GetTable()
		CableData.EZitempipe = true
		CableData.EZitempipeEntity = self
		Cable:SetTable(CableData)
		Cable.EZitempipe = true
		Cable.EZitempipeEntity = self

		if IsValid(self.SpoolRope) then self.SpoolRope:Remove() end
		self.SpoolRope = nil
		self.ResourceCable = Cable
		self.DestinationWeld = DestinationWeld
		self.DestinationEnt = hitEntity
		self.DestinationPlug = plug
		plug.Chain = Cable
		self.SourcePlug.Chain = Cable
		self:SetNW2Bool("EZitempipeConnected", true)
		self:SetNW2String("EZitempipeResource", ResourceType)
		JMod.SetEZowner(self, player)

		player:DropObject()
		self:EmitSound("buttons/lightswitch2.wav", 60, 110)
		JMod.Hint(player, "item pipe connected")
		player:PrintMessage(HUD_PRINTCENTER, "Item Pipe connected: " .. string.upper(ResourceType) .. ". Flow is Source > Destination.")
	end

	function ENT:ShowOutput(plug, player)
		if self:GetNW2Bool("EZitempipeConnected")
			or (plug ~= self.SourcePlug and plug ~= self.DestinationPlug)
			or not IsValid(self.SourceEnt)
			or not self.ResourceType then return end
		player:PrintMessage(HUD_PRINTCENTER, "Item Pipe output assigned: " .. string.upper(self.ResourceType))
	end

	function ENT:RemovePipe(player)
		if not self:GetNW2Bool("EZitempipeConnected") and not IsValid(self.SourceEnt) then return end
		if IsValid(player) and not JMod.ShouldAllowControl(self, player, true) then
			JMod.Hint(player, "item pipe bad connection")
			return
		end
		if IsValid(player) then JMod.Hint(player, "item pipe disconnected") end
		self:Remove()
	end

	function ENT:Think()
		if not self:GetNW2Bool("EZitempipeConnected") then
			self:NextThink(CurTime() + .5)
			return true
		end

		local ValidPipe = IsValid(self.SourceEnt)
			and IsValid(self.DestinationEnt)
			and IsValid(self.SourcePlug)
			and IsValid(self.DestinationPlug)
			and IsValid(self.ResourceCable)
			and JMod.ConnectionValid(self.SourceEnt, self.DestinationEnt, self.ResourceCable)
		if not ValidPipe then
			JMod.Hint(JMod.GetEZowner(self), "item pipe not working")
			self:Remove()
			return
		end
		if self.SourceEnt.IsJackyEZcrate then
			local SourceType = self.SourceEnt:GetResourceType()
			if SourceType ~= "generic" and SourceType ~= self.ResourceType then
				JMod.Hint(JMod.GetEZowner(self), "item pipe not working")
				self:Remove()
				return
			end
		end

		local TransferInterval = 1 + (self.TransferDelay or 0)
		if self.SourceEnt.IsJackyEZcrate then
			JMod.DistributeItemPipeResources(self.SourceEnt, self.DestinationEnt, self.ResourceType)
			if self.TransferDelayPer350 then
				local Distance = self.SourcePlug:GetPos():Distance(self.DestinationPlug:GetPos())
				TransferInterval = TransferInterval + math.floor(Distance / 350) * self.TransferDelayPer350
			end
		end

		self:NextThink(CurTime() + TransferInterval)
		return true
	end

	function ENT:OnRemove()
		if IsValid(self.ResourceCable) then self.ResourceCable:Remove() end
		if IsValid(self.SpoolRope) then self.SpoolRope:Remove() end
		if IsValid(self.SourceWeld) then self.SourceWeld:Remove() end
		if IsValid(self.DestinationWeld) then self.DestinationWeld:Remove() end
		if IsValid(self.SourcePlug) then self.SourcePlug:Remove() end
		if IsValid(self.DestinationPlug) then self.DestinationPlug:Remove() end
	end
elseif CLIENT then
	function ENT:Draw()
	end

	language.Add("ent_jack_gmod_ezitempipe", "EZ Item Pipe")
end
