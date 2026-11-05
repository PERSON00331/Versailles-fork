-- EZ Radio Code --
JMod.EZ_RADIO_STATIONS = JMod.EZ_RADIO_STATIONS or {}
JMod.NotifyAllMsgs = {
	["normal"] = {
		["good drop"] = "good drop, package away, returning to base",
		["drop failed"] = "drop failed, pilot could not locate a good drop position for the reported coordinates. Aircraft is RTB",
		["drop soon"] = "be advised, aircraft on site, drop imminent",
		["ready"] = "attention, this outpost is now ready to carry out delivery missions"
	},
	["bff"] = {
		["good drop"] = "AIGHT we dropped it, watch out yo",
		["drop failed"] = "yo WHERE THE DROP SITE AT THO soz i gotta get back to base",
		["drop soon"] = "ay dudes watch yo head we abouta drop the box",
		["ready"] = "aight we GOOD TO GO out here jus tell us whatchya need anytime"
	}
}

local function CreateRadioStation(teamID)
	return {
		state = JMod.EZ_STATION_STATE_READY,
		nextDeliveryTime = 0,
		nextReadyTime = 0,
		deliveryLocation = nil,
		deliveryType = nil,
		deliveryAmount = nil,
		teamID = teamID,
		nextNotifyTime = 0,
		notified = false,
		restrictedPackageStock = {},
		restrictedPackageDelivering = nil,
		restrictedPackageDeliveryTime = 0,
		outpostDirection = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0):GetNormalized(),
		lastCaller = nil
	}
end

local function FindEZradios() 
	local Radios = {}
	for _, v in ents.Iterator() do
		if v.EZradio and (v.EZradio == true) then
			table.insert(Radios, v)
		end
	end

	return Radios
end

function JMod.NotifyAllRadios(stationID, msgID, direct)
	local Station = JMod.EZ_RADIO_STATIONS[stationID]

	for _, radio in ipairs(FindEZradios()) do
		if (radio:GetState() > JMod.EZ_STATE_OFF) and (radio:GetOutpostID() == stationID) then
			if msgID then
				if direct then
					radio:Speak(msgID)
				else
					local Personality = radio:GetVoice() or "normal"
					radio:Speak(JMod.NotifyAllMsgs[Personality][msgID])
				end
			end

			radio:SetState(Station.state)
		end
	end
end

function JMod.FindDropPosFromSignalOrigin(origin)
	local Height, Attempts, Pos, AcceptTFVonly = 0, 0, origin + Vector(0, 0, 200), false

	while (Attempts < 1000) and not (Height > 5000) do
		Height = Height + 100
		local TestPos = origin + Vector(0, 0, Height)
		local Contents = util.PointContents(TestPos)
		local IsEmpty = Contents == CONTENTS_EMPTY -- fuck bitwise ops for 0
		local IsTFV = bit.band(Contents, CONTENTS_TESTFOGVOLUME) == CONTENTS_TESTFOGVOLUME

		if IsTFV then
			-- if we ever detect testfogvolume, assume the mapmaker used it properly
			-- and from that point on, accept only tfv as an indication of empty space
			AcceptTFVonly = true
			-- otherwise, accept both tfv and contents_empty
		end

		if AcceptTFVonly then
			if IsTFV then
				Pos = TestPos
			else
				return Pos
			end
		else
			if IsEmpty or IsTFV then
				Pos = TestPos
			else
				return Pos
			end
		end
	end

	return Pos
end

local NextRadioThink = 0

hook.Add("Think", "JMod_RADIO_THINK", function()
	local Time = CurTime()
	if Time < NextRadioThink then return end
	NextRadioThink = Time + 5

	for stationID, station in pairs(JMod.EZ_RADIO_STATIONS) do
		if station.state == JMod.EZ_STATION_STATE_DELIVERING then
			if station.nextDeliveryTime < Time then
				station.nextReadyTime = Time + math.ceil(JMod.Config.RadioSpecs.DeliveryTimeMult * math.Rand(30, 60) * 3)
				station.state = JMod.EZ_STATION_STATE_BUSY
				local DropPos = JMod.FindDropPosFromSignalOrigin(station.deliveryLocation)

				local AlternateDelivery, ReturnToBaseModifier = hook.Run("JMod_OnRadioDeliver", stationID, DropPos)

				if AlternateDelivery ~= nil then
					if AlternateDelivery == true then
						JMod.NotifyAllRadios(stationID, "good drop")
					else
						JMod.NotifyAllRadios(stationID, "drop failed")
					end
					if isnumber(ReturnToBaseModifier) then
						station.nextDeliveryTime = Time + math.ceil(ReturnToBaseModifier)
					end

					return 
				end
				
				if DropPos then
					local DropVelocity = station.outpostDirection
					DropVelocity = DropVelocity * 400
					local Eff = EffectData()
					Eff:SetOrigin(DropPos)
					Eff:SetStart(DropVelocity)
					util.Effect("eff_jack_gmod_jetflyby", Eff, true, true)
					local PackageInfo = JMod.Config.RadioSpecs.AvailablePackages[station.deliveryType]
					local DeliveryItems = station.deliveryResults or (PackageInfo and PackageInfo.results)
					local DeliveryCategory = station.deliveryCategory or (PackageInfo and PackageInfo.category)
					local DeliveryAmount = station.deliveryAmount
					station.deliveryAmount = nil
					station.deliveryResults = nil
					station.deliveryCategory = nil

					if DeliveryAmount then
						local ResourceClass

						if isstring(DeliveryItems) then
							ResourceClass = DeliveryItems
						elseif istable(DeliveryItems) then
							for _, result in ipairs(DeliveryItems) do
								local class = istable(result) and result[1] or result
								if isstring(class) then
									for _, resourceEntity in pairs(JMod.EZ_RESOURCE_ENTITIES) do
										if resourceEntity == class then
											ResourceClass = class
											break
										end
									end
								end
								if ResourceClass then break end
							end
						end

						if DeliveryCategory == "Resources" and ResourceClass then
							local MaxResource = math.max(1, 100 * ((JMod.Config.ResourceEconomy and JMod.Config.ResourceEconomy.MaxResourceMult) or 1))
							local Remaining = DeliveryAmount
							DeliveryItems = {}

							while Remaining > 0 do
								local Amount = math.min(Remaining, MaxResource)
								table.insert(DeliveryItems, {ResourceClass, 1, Amount})
								Remaining = Remaining - Amount
							end
						end
					end
					local IsChrimsas = JMod.GetHoliday() == "Christmas"

					timer.Simple(.9, function()
						local Box = ents.Create("ent_jack_aidbox")
						Box:SetPos(DropPos)
						Box.InitialVel = -DropVelocity * math.random(1, 3)
						Box.Contents = DeliveryItems
						Box.NoFadeIn = true
						Box:SetDTBool(0, "true")
						Box:Spawn()
						Box:SetPackageName(station.deliveryType)
						---
						sound.Play((IsChrimsas and "snd_jack_flyby_drop_Christmas.ogg") or "snd_jack_flyby_drop.ogg", DropPos, 150, 100)

						for k, playa in pairs(ents.FindInSphere(DropPos, 6000)) do
							if playa:IsPlayer() then
								sound.Play((IsChrimsas and "snd_jack_flyby_drop_Christmas.ogg") or "snd_jack_flyby_drop.ogg", playa:GetShootPos(), 50, 100)
							end
						end

						JMod.NotifyAllRadios(stationID, "good drop")
					end)
				else
					JMod.NotifyAllRadios(stationID, "drop failed")
				end
			elseif (station.nextNotifyTime < Time) and not station.notified then
				station.notified = true
				JMod.NotifyAllRadios(stationID, "drop soon")
			end
		elseif station.state == JMod.EZ_STATION_STATE_BUSY then
			if station.nextReadyTime < Time then
				station.state = JMod.EZ_STATION_STATE_READY
				JMod.NotifyAllRadios(stationID, "ready")
			end
		end

		if station.restrictedPackageDelivering then
			if station.restrictedPackageDeliveryTime < Time then
				table.insert(station.restrictedPackageStock, station.restrictedPackageDelivering)
				JMod.NotifyAllRadios(stationID, "attention, this outpost has received a special shipment of " .. station.restrictedPackageDelivering .. " from regional HQ", true)
				station.restrictedPackageDelivering = nil
				station.restrictedPackageDeliveryTime = 0
			end
		end
	end
end)

function JMod.EZradioEstablish(transceiver, teamID, reassign)
	local AlliedStations = {}

	for k, v in pairs(JMod.EZ_RADIO_STATIONS) do
		if v.teamID == teamID then
			table.insert(AlliedStations, k)
		end
	end

	local MaximumOutposts = JMod.Config.RadioSpecs.MaximumOutpostCount or 3
	local MinimumOutposts = math.min(JMod.Config.RadioSpecs.StartingOutpostCount or 0, MaximumOutposts)
	if (#AlliedStations < MinimumOutposts) then
		for i = 1, math.min(MinimumOutposts - #AlliedStations, MaximumOutposts - #AlliedStations) do
			table.insert(JMod.EZ_RADIO_STATIONS, CreateRadioStation(teamID))
			table.insert(AlliedStations, #JMod.EZ_RADIO_STATIONS)
		end
	end

	local OriginalStation, ChosenStation = transceiver:GetOutpostID(), nil

	if not(reassign) and (OriginalStation ~= 0) and (JMod.EZ_RADIO_STATIONS[OriginalStation] and (JMod.EZ_RADIO_STATIONS[OriginalStation].teamID == teamID)) and (JMod.EZ_RADIO_STATIONS[OriginalStation].state == JMod.EZ_STATION_STATE_READY) then
		return
	end

	if not ChosenStation then
		for k, id in pairs(AlliedStations) do
			local station = JMod.EZ_RADIO_STATIONS[id]

			if (station.state == JMod.EZ_STATION_STATE_READY) then
				ChosenStation = id
				break
			end
		end
	end

	if ChosenStation then
		transceiver:SetOutpostID(ChosenStation)
	end
end

-- this is on the global table for third-party use
function JMod.AddNewRadioOutpost(teamID)
	local MaximumOutposts = JMod.Config.RadioSpecs.MaximumOutpostCount or 3
	local AlliedOutpostCount = 0

	for _, station in pairs(JMod.EZ_RADIO_STATIONS) do
		if station.teamID == teamID then
			AlliedOutpostCount = AlliedOutpostCount + 1
		end
	end

	if AlliedOutpostCount >= MaximumOutposts then return false end

	table.insert(JMod.EZ_RADIO_STATIONS, CreateRadioStation(teamID))

	local TeamName = team.GetName(tonumber(teamID))

	if TeamName == "" then
		TeamName = player.GetByAccountID(tonumber(teamID)):Name()
	else
		TeamName = "Team " .. TeamName
	end

	for k, ply in player.Iterator() do
		ply:PrintMessage(HUD_PRINTTALK, TeamName .. " has gained a radio outpost.")
	end

	return true
end

local ActiveSalePackage
local DefaultSaleItems = {
	{
		name = "centrifuge",
		category = "Machines",
		result = "ent_jack_gmod_ezcentrifuge",
		amount = 1,
		DeliveryTimeMult = 2,
		Weight = 1
	},
	{
		name = "smelting furnace",
		category = "Machines",
		result = "ent_jack_gmod_ezfurnace",
		amount = 1,
		DeliveryTimeMult = 1.5,
		Weight = 2
	},
	{
		name = "oil refinery",
		category = "Machines",
		result = "ent_jack_gmod_ezrefinery",
		amount = 1,
		DeliveryTimeMult = 2.5,
		Weight = 1
	}
}

local function RefreshRadioSale()
	local RadioSpecs = JMod.Config.RadioSpecs
	if not istable(RadioSpecs.SaleItems) then
		if RadioSpecs.SaleItems ~= nil then
			ErrorNoHalt("JMod radio SaleItems config must be a table; using the default sale items.\n")
		end
		RadioSpecs.SaleItems = {}
	end

	if #RadioSpecs.SaleItems == 0 then
		RadioSpecs.SaleItems = table.FullCopy(DefaultSaleItems)
	end

	local AvailablePackages = RadioSpecs.AvailablePackages

	if ActiveSalePackage then
		AvailablePackages[ActiveSalePackage] = nil
		ActiveSalePackage = nil
	end

	local SaleItems = RadioSpecs.SaleItems
	local ValidSaleItems = {}

	for _, Sale in ipairs(SaleItems) do
		if istable(Sale) and isstring(Sale.name) and isstring(Sale.category) and isstring(Sale.result)
			and isnumber(Sale.amount) and Sale.amount >= 1 and Sale.amount == math.floor(Sale.amount)
			and (Sale.Weight == nil or (isnumber(Sale.Weight) and Sale.Weight > 0))
			and (Sale.DeliveryTimeMult == nil or (isnumber(Sale.DeliveryTimeMult) and Sale.DeliveryTimeMult > 0)) then
			table.insert(ValidSaleItems, Sale)
		else
			ErrorNoHalt("JMod radio sale item is invalid; expected name, category, result, positive integer amount, positive weight, and positive delivery time multiplier.\n")
		end
	end

	local SaleChance = RadioSpecs.SaleChance or 0.35
	if not isnumber(SaleChance) or SaleChance < 0 or SaleChance > 1 then
		ErrorNoHalt("JMod radio SaleChance must be between 0 and 1; using 0.35.\n")
		SaleChance = 0.35
	end
	if #ValidSaleItems > 0 and math.Rand(0, 1) < SaleChance then
		local TotalWeight = 0
		for _, Sale in ipairs(ValidSaleItems) do
			TotalWeight = TotalWeight + (Sale.Weight or 1)
		end

		local WeightRoll = math.Rand(0, TotalWeight)
		local Sale
		for _, Candidate in ipairs(ValidSaleItems) do
			WeightRoll = WeightRoll - (Candidate.Weight or 1)
			if WeightRoll <= 0 then
				Sale = Candidate
				break
			end
		end
		Sale = Sale or ValidSaleItems[#ValidSaleItems]
		local SaleName = string.lower(Sale.name)
		local PackageName = "sale: " .. SaleName
		local SaleDuration = RadioSpecs.SaleDuration or 300
		if not isnumber(SaleDuration) or SaleDuration <= 0 then
			ErrorNoHalt("JMod radio SaleDuration must be a positive number of seconds; using 300 seconds.\n")
			SaleDuration = 300
		end
		AvailablePackages[PackageName] = {
			description = "Limited-time deal: " .. Sale.amount .. " " .. Sale.name .. ".",
			category = "Sales",
			results = {{Sale.result, Sale.amount}},
			saleItemName = SaleName,
			DeliveryTimeMult = Sale.DeliveryTimeMult or 1,
			saleExpiresAt = CurTime() + SaleDuration
		}
		ActiveSalePackage = PackageName

		local Message = "!! " .. string.upper(Sale.name) .. " is on sale !!"
		for _, Player in player.Iterator() do
			Player:PrintMessage(HUD_PRINTTALK, Message)
		end

		timer.Simple(SaleDuration, function()
			local CurrentSale = JMod.Config.RadioSpecs.AvailablePackages[PackageName]
			if not CurrentSale or CurrentSale.saleExpiresAt > CurTime() then return end

			JMod.Config.RadioSpecs.AvailablePackages[PackageName] = nil
			if ActiveSalePackage == PackageName then
				ActiveSalePackage = nil
			end
			JMod.CraftablesSync()
		end)
	end

	JMod.CraftablesSync()
end

local SaleInterval = JMod.Config.RadioSpecs.SaleInterval or 900
if not isnumber(SaleInterval) or SaleInterval <= 0 then
	ErrorNoHalt("JMod radio SaleInterval must be a positive number of seconds; using 900 seconds.\n")
	SaleInterval = 900
end
timer.Create("JMod_RadioSale", SaleInterval, 0, RefreshRadioSale)

-- this is also on the global table for third-party use
function JMod.RemoveRadioOutPost(teamID)
	local RemovedOutpost = nil
	for k, v in pairs(JMod.EZ_RADIO_STATIONS) do
		if v.teamID == teamID then
			table.remove(JMod.EZ_RADIO_STATIONS, k)
			RemovedOutpost = k
			break
		end
	end

	for _, radio in ipairs(FindEZradios()) do
		if radio:GetOutpostID() == RemovedOutpost then
			radio:StartConnecting()
		end
	end

	local TeamName = team.GetName(tonumber(teamID))

	if TeamName == "" then
		TeamName = player.GetByAccountID(tonumber(teamID)):Name()
	else
		TeamName = "Team " .. TeamName
	end

	for k, ply in player.Iterator() do
		ply:PrintMessage(HUD_PRINTTALK, TeamName .. " has lost a radio outpost.")
	end
end

concommand.Add("jmod_debug_addoutpost", function(ply, cmd, args)
	if not ply:IsUserGroup("superadmin") then return end
	local Team = 0

	if engine.ActiveGamemode() == "sandbox" and ply:Team() == TEAM_UNASSIGNED then
		Team = ply:AccountID()
	else
		Team = ply:Team()
	end

	if not JMod.AddNewRadioOutpost(tostring(Team)) then
		local MaximumOutposts = JMod.Config.RadioSpecs.MaximumOutpostCount or 3
		ply:PrintMessage(HUD_PRINTTALK, "Your team has reached the maximum of " .. MaximumOutposts .. " radio outposts.")
	end
end, nil, "Adds another radio outpost for your team.")

concommand.Add("jmod_debug_removeoutpost", function(ply, cmd, args)
	if not ply:IsUserGroup("superadmin") then return end
	local Team = 0

	if engine.ActiveGamemode() == "sandbox" and ply:Team() == TEAM_UNASSIGNED then
		Team = ply:AccountID()
	else
		Team = ply:Team()
	end

	JMod.RemoveRadioOutPost(tostring(Team))
end, nil, "Removes a radio outpost for your team.")

local function GetPlayerFromNick(nickname)
	if not nickname then return nil end
	nickname = string.lower(nickname)
	for _, v in ents.Iterator() do
		if not(IsValid(v)) and (v:IsPlayer()) and (string.lower(v:Nick())) == nickname then

			return v
		end
	end
	
	return nil
end

concommand.Add("jmod_airdropplayer", function(ply, cmd, args) 
	if not ply:IsUserGroup("superadmin") then return end
	
	local TargetPly, TargetPos, Punish = GetPlayerFromNick(args[1]), ply:GetPos(), false

	if not(IsValid(TargetPly)) then 
		TargetPly = ply 
	end
	if isnumber(tonumber(args[2])) then
		TargetPos = Vector(tonumber(args[2]), tonumber(args[3]) or 0, tonumber(args[4]) or 0)
		Punish = tobool(args[5])
	elseif tobool(args[2]) then
		Punish = tobool(args[2])
	end

	local DropPos = JMod.FindDropPosFromSignalOrigin(TargetPos)

	if DropPos then
		TargetPly:ExitVehicle()
		--TargetPly:SetPos(DropPos)
		TargetPly:SetNoDraw(true)
		local DropVelocity = VectorRand()
		DropVelocity.z = 0
		DropVelocity:Normalize()
		DropVelocity = DropVelocity * 400
		local Eff = EffectData()
		Eff:SetOrigin(DropPos)
		Eff:SetStart(DropVelocity)
		util.Effect("eff_jack_gmod_jetflyby", Eff, true, true)

		timer.Simple(0.9, function()
			local Box = ents.Create("ent_jack_aidbox")
			Box:SetPos(DropPos)
			Box.InitialVel = -DropVelocity * 10
			--Box.Contents = {"ent_jack_gmod_eztoolbox"}
			Box.NoFadeIn = true
			Box:SetDTBool(0, "true")
			Box:Spawn()
			----- Create the chair
			Box.Pod = ents.Create("prop_vehicle_prisoner_pod")
			Box.Pod:SetModel("models/vehicles/prisoner_pod_inner.mdl")
			local Ang, Up, Right, Forward = Box:GetAngles(), Box:GetUp(), Box:GetRight(), Box:GetForward()
			Box.Pod:SetPos(Box:GetPos() - Up * 30)
			Ang:RotateAroundAxis(Up, 0)
			Ang:RotateAroundAxis(Forward, 0)
			Box.Pod:SetAngles(Ang)
			Box.Pod:Spawn()
			Box.Pod:Activate()
			Box.Pod:SetParent(Box)
			Box.Pod:SetNoDraw(true)
			Box.Pod:SetThirdPersonMode(true)
			------
			Box:SetPackageName(ply:Nick())
			TargetPly:EnterVehicle(Box.Pod)
			---
			sound.Play("snd_jack_flyby_drop.ogg", DropPos, 150, 100)

			for k, playa in pairs(ents.FindInSphere(DropPos, 6000)) do
				if playa:IsPlayer() then
					sound.Play("snd_jack_flyby_drop.ogg", playa:GetShootPos(), 50, 100)
				end
			end
		end)
	end
end, nil, "Airdrops specified player on specified location")

hook.Add("PlayerLeaveVehicle", "JMod_PlayerPackageExit", function( ply, veh )
	local Box = veh:GetParent()
	if (IsValid(Box)) and (Box:GetClass() == "ent_jack_aidbox") then
		ply:SetPos(Box:GetPos())
		Box:Use(ply)
		ply:SetNoDraw(false)
	end
end)

local function GetArticle(word)
	local FirstLetter = string.sub(word, 1, 1)

	if table.HasValue({"a", "e", "i", "o", "u"}, FirstLetter) then
		return "an"
	else
		return "a"
	end
end

local function GetTimeString(seconds)
	local Minutes, Seconds, Result = math.floor(seconds / 60), math.floor(seconds % 60), ""

	if Minutes > 0 then
		Result = Minutes .. " minutes"

		if Seconds > 0 then
			Result = Result .. ", " .. Seconds .. " seconds"
		end
	elseif Seconds > 0 then
		Result = Seconds .. " seconds"
	end

	return Result
end

--[[
hook.Add("JMod_RadioDelivery","jackatest",function(owner,radio,package,tiem,pos)
	return 4,pos
end)
--]]

local function TryFindSky(ent)
	local TestPos = ent.GetShootPos and ent:GetShootPos() or ent:LocalToWorld(Vector(0, 0, 45))

	for i = 1, 10 do
		local Dir = ent:LocalToWorldAngles(Angle(-90 + i * 9, 0, 0)):Forward()

		--debugoverlay.Line(TestPos, TestPos + Dir * 9e9, 2, Color(0, 89, 255), true)
		local HitSky = util.TraceLine({
			start = TestPos,
			endpos = TestPos + Dir * 9e9,
			filter = {ent},
			mask = MASK_OPAQUE
		}).HitSky

		if HitSky then return true end
	end

	return false
end

local function StartDelivery(pkg, transceiver, id, bff, ply, deliveryTime, quantity, deliveryTimeMult, quantityTimeScale)
	local Station = JMod.EZ_RADIO_STATIONS[id]
	Station.lastCaller = transceiver
	local Time = CurTime()
	local DeliveryTime, Pos = deliveryTime or math.ceil(JMod.Config.RadioSpecs.DeliveryTimeMult * math.Rand(30, 60)), transceiver:GetPos()
	if quantity then
		DeliveryTime = math.ceil(DeliveryTime * (1 + (quantityTimeScale or 3) * (quantity - 1) / 224))
	end
	if isnumber(deliveryTimeMult) and deliveryTimeMult > 0 then
		DeliveryTime = math.ceil(DeliveryTime * deliveryTimeMult)
	end
	local PlyPos = ply:GetPos()
	-- Check to see if the player or the transceiver has a better drop position
	--print(TryFindSky(ply))
	for i = 0, 20 do
		local RandVec = VectorRand()
		RandVec.z = 0
		local Dir = (vector_up + RandVec):GetNormalized()
		local TrResult = util.QuickTrace(PlyPos, Dir * 9e9, {ply, transceiver})
		if TrResult.HitSky then
			Pos = PlyPos
			break
		end
	end
	local newTime, newPos = hook.Run("JMod_RadioDelivery", ply, transceiver, pkg, DeliveryTime, Pos)
	DeliveryTime = newTime or DeliveryTime
	Pos = newPos or Pos
	JMod.Hint(ply, "aid wait")
	Station.state = JMod.EZ_STATION_STATE_DELIVERING
	Station.nextDeliveryTime = Time + DeliveryTime
	Station.deliveryLocation = Pos
	Station.deliveryType = pkg
	local PackageInfo = JMod.Config.RadioSpecs.AvailablePackages[pkg]
	local DeliveryResults = PackageInfo and PackageInfo.results
	Station.deliveryResults = istable(DeliveryResults) and table.FullCopy(DeliveryResults) or DeliveryResults
	Station.deliveryCategory = PackageInfo and PackageInfo.category or nil
	Station.deliveryAmount = quantity
	Station.notified = false
	Station.nextNotifyTime = Time + (DeliveryTime - 5)
	JMod.NotifyAllRadios(id) -- do a notify to update all radio states
	if quantity then
		if bff then return "ayo GOOD COPY homie, we sendin " .. quantity .. " units of " .. pkg .. " right over to " .. math.Round(Pos.x) .. " " .. math.Round(Pos.y) .. " " .. math.Round(Pos.z) .. " in prolly like " .. GetTimeString(DeliveryTime) end
		return "roger wilco, sending " .. quantity .. " units of " .. pkg .. " to coordinates " .. math.Round(Pos.x) .. ", " .. math.Round(Pos.z) .. "; ETA " .. GetTimeString(DeliveryTime)
	end
	if bff then return "ayo GOOD COPY homie, we sendin " .. GetArticle(pkg) .. " " .. pkg .. " box right over to " .. math.Round(Pos.x) .. " " .. math.Round(Pos.y) .. " " .. math.Round(Pos.z) .. " in prolly like " .. GetTimeString(DeliveryTime) end

	return "roger wilco, sending " .. GetArticle(pkg) .. " " .. pkg .. " package to coordinates " .. math.Round(Pos.x) .. ", " .. math.Round(Pos.z) .. "; ETA " .. GetTimeString(DeliveryTime)
end

function JMod.EZradioRequest(transceiver, id, ply, pkg, bff, quantity)
	local PackageInfo, Station, Time = JMod.Config.RadioSpecs.AvailablePackages[pkg], JMod.EZ_RADIO_STATIONS[id], CurTime()
	if not Station then return "No station with that ID" end
	if Station.state ~= JMod.EZ_STATION_STATE_READY
		and Station.state ~= JMod.EZ_STATION_STATE_DELIVERING
		and Station.state ~= JMod.EZ_STATION_STATE_BUSY then
		ErrorNoHalt("JMod radio outpost " .. tostring(id) .. " has invalid state " .. tostring(Station.state) .. "; resetting it to ready.\n")
		Station.state = JMod.EZ_STATION_STATE_READY
	end
	if PackageInfo and PackageInfo.saleItemName and PackageInfo.saleExpiresAt and PackageInfo.saleExpiresAt <= Time then
		JMod.Config.RadioSpecs.AvailablePackages[pkg] = nil
		if ActiveSalePackage == pkg then
			ActiveSalePackage = nil
		end
		JMod.CraftablesSync()
		return "That limited-time deal has expired."
	end
	if not PackageInfo then return "No package with that name" end
	if quantity ~= nil and PackageInfo.category == "Resources" then
		local MaxOrderAmount = JMod.GetEZradioResourceOrderLimit(PackageInfo)
		if not isnumber(quantity) or quantity ~= math.floor(quantity) or quantity < 1 or quantity > MaxOrderAmount then
			return "Resource orders for " .. pkg .. " must be between 1 and " .. MaxOrderAmount .. " units"
		end
	elseif quantity ~= nil then
		return "Only resource orders can specify a quantity"
	end
	JMod.NotifyAllRadios(id) -- do a notify to update all radio states
	transceiver.BFFd = bff
	local override, msg = hook.Run("JMod_CanRadioRequest", ply, transceiver, pkg)
	if override == false then return msg or "negative on that request." end

	if Station.state == JMod.EZ_STATION_STATE_DELIVERING then
		local DeliveryTime = (Station.nextDeliveryTime - Time) * math.Rand(.8, 1.2)
		if bff then return "no can do bro, we deliverin somethin else. Give us " .. GetTimeString(DeliveryTime) .. " yea?" end

		return "negative on that request, we're currently delivering another package; ETA " .. GetTimeString(DeliveryTime)
	elseif Station.state == JMod.EZ_STATION_STATE_BUSY then
		local ReadyTime = (Station.nextReadyTime - Time)
		if bff then return "nah fam we ain't ready yet try agin in " .. GetTimeString(ReadyTime) .. " alr?" end

		return "negative on that request, the delivery team will be back in " .. GetTimeString(ReadyTime) .. "."
	elseif Station.state == JMod.EZ_STATION_STATE_READY then
		if table.HasValue(JMod.Config.RadioSpecs.RestrictedPackages, pkg) then
			if not JMod.Config.RadioSpecs.RestrictedPackagesAllowed then
				if bff then
					return "can't do that fam, HQ is dry and so are we"
				else
					return "negative on that request, neither we nor regional HQ have any of that at this time"
				end
			end

			if pkg == "antimatter" then
				local SupplyChance = JMod.Config.RadioSpecs.AntimatterSupplyChance or 0.5
				if math.Rand(0, 1) >= SupplyChance then
					if bff then
						return "nah fam, antimatter is out of stock and not available right now"
					end

					return "negative, antimatter is out of stock and not available right now"
				end

				return StartDelivery(pkg, transceiver, id, bff, ply, 20 * 60, quantity, nil, 1)
			end

			if table.HasValue(Station.restrictedPackageStock, pkg) then
				table.RemoveByValue(Station.restrictedPackageStock, pkg)

				return StartDelivery(pkg, transceiver, id, bff, ply, nil, quantity)
			else
				if Station.restrictedPackageDelivering then
					if bff then
						return "bro, HQ is busy with another special shipment, you gotta wait some more"
					else
						return "negative on that request, we don't have any of that in stock and HQ is currently delivering another special shipment"
					end
				else
					Station.restrictedPackageDelivering = pkg
					local DeliveryTime = JMod.Config.RadioSpecs.RestrictedPackageShipTime * math.Rand(.8, 1.2)
					Station.restrictedPackageDeliveryTime = Time + DeliveryTime

					if bff then
						return "homie, we gon get you that special delivery straight from HQ. give us " .. GetTimeString(DeliveryTime) .. " yea?"
					else
						return "roger, we don't have any of that in stock but we've ordered it from regional HQ, it'll be at this outpost in " .. GetTimeString(DeliveryTime)
					end
				end
			end
		else
			local Response = StartDelivery(pkg, transceiver, id, bff, ply, nil, quantity, PackageInfo.DeliveryTimeMult)

			if PackageInfo.saleItemName then
				JMod.Config.RadioSpecs.AvailablePackages[pkg] = nil
				if ActiveSalePackage == pkg then
					ActiveSalePackage = nil
				end
				JMod.CraftablesSync()
			end

			return Response
		end
	end
end

hook.Add("PlayerSay", "JMod_PLAYERSAY", function(ply, txt)
	if not IsValid(ply) then return end
	if not ply:Alive() then return end

	if txt == "hi everyone" then
		JMod.Hint(ply, "idiot")
	end

	local lowerTxt = string.lower(txt)
	local trimmedTxt = string.Trim(lowerTxt)
	local RadioRequestText = string.match(trimmedTxt, "^.-:%s*(supply%s+radio:.*)$")
		or string.match(trimmedTxt, "^.-:%s*(aid%s+radio:.*)$")
		or string.match(trimmedTxt, "^.-:%s*(heyo%s*:.*)$")
		or trimmedTxt
	local IsRadioRequest = string.match(RadioRequestText, "^supply%s+radio:") ~= nil
		or string.match(RadioRequestText, "^aid%s+radio:") ~= nil
		or string.match(RadioRequestText, "^heyo%s*:")

	if IsRadioRequest then
		local NearbyRadio, AuthorizedRadio, ReadyRadio
		local NearestDistance = 300 * 300
		local NearestAuthorizedDistance = NearestDistance
		local NearestReadyDistance = NearestDistance

		for _, radio in ipairs(FindEZradios()) do
			local Distance = radio:GetPos():DistToSqr(ply:GetPos())
			if Distance <= 300 * 300 and (not IsValid(NearbyRadio) or Distance < NearestDistance) then
				NearbyRadio = radio
				NearestDistance = Distance
			end

			if Distance <= 300 * 300 and radio:UserIsAuthorized(ply) then
				if not IsValid(AuthorizedRadio) or Distance < NearestAuthorizedDistance then
					AuthorizedRadio = radio
					NearestAuthorizedDistance = Distance
				end

				if radio:GetState() >= JMod.EZ_STATION_STATE_READY
					and (not IsValid(ReadyRadio) or Distance < NearestReadyDistance) then
					ReadyRadio = radio
					NearestReadyDistance = Distance
				end
			end
		end

		local Radio = ReadyRadio or AuthorizedRadio or NearbyRadio
		if not IsValid(Radio) then
			ply:PrintMessage(HUD_PRINTCENTER, "No Aid Radio in range")
			return ""
		end

		if not Radio:UserIsAuthorized(ply) then
			ply:PrintMessage(HUD_PRINTCENTER, "You are not authorized to use this Aid Radio")
			return ""
		end

		if Radio:GetState() < JMod.EZ_STATION_STATE_READY then
			ply:PrintMessage(HUD_PRINTCENTER, "Aid Radio is not connected yet; turn it on and wait for connection")
			return ""
		end

		if not Radio:EZreceiveSpeech(ply, RadioRequestText) then
			ply:PrintMessage(HUD_PRINTCENTER, "Aid Radio could not process the request; check its power and sky access")
		end

		return ""
	end

	for _, v in pairs(ents.FindInSphere(ply:GetPos(), 200)) do
		if v.EZreceiveSpeech and v:EZreceiveSpeech(ply, txt) then return "" end
	end

	if JMod.PlyHasArmorEff(ply, "teamComms") then
		for _, data in pairs(ply.EZarmor.items) do
			local Info = JMod.ArmorTable[data.name]
			if not Info then continue end

			if Info.eff and Info.eff.teamComms then
				local SubtractAmt = JMod.Config.Armor.DegradationMult / 2
				data.chrg.power = math.Clamp(data.chrg.power - SubtractAmt, 0, 9e9)

				if data.chrg.power <= Info.chrg.power * .25 then
					JMod.EZarmorWarning(ply, "armor's electrical charge is almost depleted!")
				end
			end
		end

		local BestRadio
		for _, radio in ipairs(FindEZradios()) do
			if radio:UserIsAuthorized(ply) and (not BestRadio or BestRadio:GetPos():DistToSqr(ply:GetPos()) > radio:GetPos():DistToSqr(ply:GetPos())) then
				local RadioState = BestRadio and BestRadio:GetState() or 4
				if radio.GetState and radio:GetState() <= RadioState then
					BestRadio = radio
				end
			end
		end

		local ExplodedString = string.Explode(" ", lowerTxt)
		if BestRadio and BestRadio:EZreceiveSpeech(ply, txt) then
			return ""
		elseif not BestRadio and ((ExplodedString[1] == "supply") or (ExplodedString[1] == "aid")) and (ExplodedString[2] == "radio:") then
			ply:PrintMessage(HUD_PRINTCENTER, "No good radios in range")
		end
	end
end)

function JMod.EZradioStatus(transceiver, id, ply, bff)
	local Station, Time, Msg = JMod.EZ_RADIO_STATIONS[id], CurTime(), ""
	if not Station then return end
	JMod.NotifyAllRadios(id) -- do a notify to update all radio states
	transceiver.BFFd = bff

	if Station.state == JMod.EZ_STATION_STATE_DELIVERING then
		local DeliveryTime = (Station.nextDeliveryTime - Time) * math.Rand(.9, 1.1)
		Msg = "this outpost is currently delivering a package; ETA " .. GetTimeString(DeliveryTime) .. "."

		if bff then
			Msg = "hey we gettin somethin fo someone else righ now in about " .. GetTimeString(DeliveryTime)
		end
	elseif Station.state == JMod.EZ_STATION_STATE_BUSY then
		local ReadyTime = (Station.nextReadyTime - Time)
		Msg = "this outpost is currently preparing for deliveries, check again in " .. GetTimeString(ReadyTime) .. "."

		if bff then
			Msg = "hey homie we pretty busy out here right now jus hol up for about " .. GetTimeString(ReadyTime) .. "."
		end
	elseif Station.state == JMod.EZ_STATION_STATE_READY then
		Msg = "this outpost is ready to accept delivery missions"

		if bff then
			Msg = "ANYTHING U NEED WE GOTCHU"
		end
	end

	if #Station.restrictedPackageStock > 0 then
		local InventoryList = ""

		for k, v in pairs(Station.restrictedPackageStock) do
			InventoryList = InventoryList .. v .. ", "
		end

		Msg = Msg .. ", and has a special stock of " .. InventoryList
	end

	if Station.restrictedPackageDelivering then
		Msg = Msg .. ", and has a special delivery of " .. Station.restrictedPackageDelivering .. " arriving from regional HQ in " .. GetTimeString(Station.restrictedPackageDeliveryTime - Time)
	end

	return Msg
end
