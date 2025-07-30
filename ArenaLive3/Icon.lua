--[[ ArenaLive Core Functions: Icon Handler
Created by: Vadrak
Creation Date: 05.04.2014
Last Update: 10.09.2014
This file stores the function for ArenaLive's dynamic icons. These are used to show trinket CD, class, race etc.
NOTE: Improve fall back option
]]--

-- ArenaLive addon Name and localisation table:
local addonName, L = ...;

--[[
**************************************************
******* GENERAL HANDLER SET UP STARTS HERE *******
**************************************************
]]--
-- Create new Handler and register for all important events:
local Icon = ArenaLive:ConstructHandler("Icon", true, false);

-- Set an indicator so that unit frames know that they have to nest all frames of this handler type into a superordinated table:
Icon.multiple = true;

Icon:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
Icon:RegisterEvent("UNIT_FACTION");
Icon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
Icon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED_SPELL_DISPEL");
Icon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED_SPELL_INTERRUPT");
Icon:RegisterEvent("PLAYER_ENTERING_WORLD");

-- Table of Texture coordinates for the race/gender icons.
local RACE_GENDER_ICON_TCOORDS =
	{
		["Human"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0, 0.125, 0, 0.25},
				[3] = {0, 0.125, 0.50391, 0.75},
			},
		["Dwarf"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0.125, 0.25, 0, 0.25},
				[3] = {0.125, 0.25, 0.50391, 0.75},
			},
		["NightElf"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0.37695, 0.5, 0, 0.25},
				[3] = {0.37695, 0.5, 0.50391, 0.75},
			},
		["Gnome"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0.25195, 0.375, 0, 0.25},
				[3] = {0.25195, 0.375, 0.50391, 0.75},
			},
		["Draenei"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0.50195, 0.625, 0, 0.25},
				[3] = {0.50195, 0.625, 0.50391, 0.75},
			},
		["Worgen"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0.62891, 0.75391, 0, 0.25},
				[3] = {0.62891, 0.75391, 0.50391, 0.75},
			},
		["Orc"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0.37695, 0.5, 0.2539, 0.50},
				[3] = {0.37695, 0.5, 0.75391, 1},
			},
		["Scourge"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0.126953125, 0.25, 0.2539, 0.50},
				[3] = {0.126953125, 0.25, 0.75391, 1},
			},
		["Tauren"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0, 0.125, 0.2539, 0.50},
				[3] = {0, 0.125, 0.75391, 1},
			},
		["Troll"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0.25195, 0.375, 0.2539, 0.50},
				[3] = {0.25195, 0.375, 0.75391, 1},
			},
		["BloodElf"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0.50195, 0.625, 0.2539, 0.50},
				[3] = {0.50195, 0.625, 0.75391, 1},
			},
		["Goblin"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0.62891, 0.75391, 0.2539, 0.50},
				[3] = {0.62891, 0.75391, 0.75391, 1},
			},
		["Pandaren"] =
			{
				[1] = {0, 0.25, 0.50, 0.75},
				[2] = {0.75586, 0.88086, 0, 0.25},
				[3] = {0.75586, 0.88086, 0.50391, 0.75},
			},
	};

-- Create table for spell cooldown of units:
local cooldownCache = {};



--[[
****************************************
****** HANDLER METHODS START HERE ******
****************************************
]]--
--[[ Method: ConstructObject
	 Creates a new frame of the type icon.
		icon (frame): The frame that is going to be set up as an icon.
		texture (texture): Texture that shows the different images for the icon. (e.g. class icon, spell icon of the pvp-trinket etc.)
		addonName (string): Name of the addon the icon belongs to. This is needed in order to set up the icon's cooldown correctly.
		cooldownFrame (frame [Cooldown]): Cooldown frame that shows the cooldown of spell CDs, if the icon is set to show pvp-trinket cooldown for example.
]]--
function Icon:ConstructObject(icon, texture, cooldownFrame, addonName)

	ArenaLive:CheckArgs(icon, "table", texture, "Texture", addonName, "string", cooldownFrame, "Cooldown");

	-- Set base info:
	icon.id = identifier;

	ArenaLive:ConstructHandlerObject(cooldownFrame, "Cooldown", addonName, icon);
	
	-- Set texture frame reference:
	icon.texture = texture

end

--[[ Method: UseFallBackType
	 Checks if the update function should use the fall back icon type or the regular one.
		frame (frame): The affected unit frame.
		iconID (number): ID of the icon to check for.
]]--
function Icon:UseFallBackType(frame, iconID)

	local database = ArenaLive:GetDBComponent(frame.addon, self.name, frame.group);
	local iconType = database[iconID].Type;
	local fallBack = database[iconID].FallBackType;
	
	if ( frame.test or not fallBack or not frame.unit ) then
		return false;
	end
	
	local _, class = UnitClass(frame.unit);
	local _, race = UnitRace(frame.unit);
	local faction = UnitFactionGroup(frame.unit);
	local isPlayer = UnitIsPlayer(frame.unit);
	local sex = UnitSex(frame.unit);
	local unitType = string.match(frame.unit, "^([a-z]+)[0-9]+$") or frame.unit;
	
	if ( iconType == "reaction" ) then
		return false;
	elseif ( iconType == "race" and race and sex ) then
		return false;
	elseif ( iconType == "class" and class and isPlayer ) then
		return false;
	elseif ( iconType == "specialisation" and isPlayer and ( frame.unit == "player" or unitType == "arena" or UnitIsUnit("player", frame.unit) ) ) then
		return false;
	elseif ( iconType == "trinket" and isPlayer and faction ) then
		return false;
	elseif ( iconType == "racial" and isPlayer and race ) then
		return false;
	elseif ( iconType == "interrupt" and class and ArenaLive.spellDB.Interrupts[class] ) then
		return false;
	elseif ( iconType == "dispel" and class and ArenaLive.spellDB.Dispels[class] ) then
		return false;
	else
		return true;
	end
end

--[[ Method: Update
	 General update function for icons. This one will update all icons for the specified frame.
		frame (frame): The affected unit frame.
		typeFilter (string/nil): When set the update iterate will only update icons with the specified iconType.
]]--
function Icon:Update(frame, typeFilter)

	if ( not frame[self.name] ) then
		return;
	end
	
	local database = ArenaLive:GetDBComponent(frame.addon, self.name, frame.group);
	for id in pairs(frame[self.name]) do
		if ( typeFilter ) then
			if ( typeFilter == database[id].Type or typeFilter == database[id].FallBackType ) then
				Icon:UpdateSingleIcon(frame, id);
			end
		else
			Icon:UpdateSingleIcon(frame, id);
		end
	end
end

function Icon:UpdateSingleIcon(frame, iconID)

	if ( not frame.unit ) then
		return;
	end

	local icon = frame[self.name][iconID];
	local database = ArenaLive:GetDBComponent(frame.addon, self.name, frame.group);
	local useFallback = Icon:UseFallBackType(frame, iconID);
	local iconType;
	
	if ( useFallback ) then
		iconType = database[iconID].FallBackType;
	else
		iconType = database[iconID].Type;
	end
	
	-- Set up spell info according to type:
	icon.spellID, icon.duration = Icon:GetSpellInfo(frame, iconType);
	
	-- Set texture according to iconType:
	Icon:SetTexture(frame, icon, iconType);
	
	-- Get time and Set Cooldown:
	local startTime, duration = Icon:GetCooldown(frame, icon);
	if ( startTime and duration ) then
		icon.cooldown:Set(startTime, duration);
	else
		icon.cooldown:Reset();
	end

end

function Icon:GetSpellInfo(unitFrame, iconType)
	local unit = unitFrame.unit;
	local isPlayer = UnitIsPlayer(unit);
	if ( isPlayer or unitFrame.test ) then
		local _, class, race;
		if ( unitFrame.test ) then
			class = ArenaLive.testModeValues[unitFrame.test]["class"];
			race = ArenaLive.testModeValues[unitFrame.test]["race"];
		else
			_, class = UnitClass(unit);
			_, race = UnitRace(unit)
		end
		
		if ( iconType == "trinket" ) then
			return unpack(ArenaLive.spellDB.Trinket);
		elseif ( iconType == "racial" ) then
			if ( race and class and ArenaLive.spellDB.Racials[race][class] ) then
				return unpack(ArenaLive.spellDB.Racials[race][class]);
			elseif ( race ) then
				return unpack(ArenaLive.spellDB.Racials[race]);
			end
		elseif ( iconType == "interrupt" and ArenaLive.spellDB.Interrupts[class]) then
			if ( type(ArenaLive.spellDB.Interrupts[class][1]) == "table" ) then
				-- Warlocks and their multiple spellID Spellock again. >:| 
				return ArenaLive.spellDB.Interrupts[class], nil;
			else
				return unpack(ArenaLive.spellDB.Interrupts[class]);
			end
		elseif ( iconType == "dispel" and ArenaLive.spellDB.Dispels[class] ) then
			return unpack(ArenaLive.spellDB.Dispels[class]);
		else
			return nil, nil;
		end
	else
		return nil, nil;
	end	

end

--[[ Method: UpdateCooldown
	 Updates the cooldown frame for the specified icon.
		icon (frame): Affected icon.
]]--
function Icon:GetCooldown(frame, icon)
	local unit = frame.unit;
	local guid = frame.guid;
	
	if ( not unit or not guid or frame.test ) then
		return nil, nil;
	end

	local theTime = GetTime();
	
	-- Check if the icon is a type with a cooldown and if there is a cooldown entry in the cache:
	if ( icon.spellID and cooldownCache[guid] ) then
		local endTime;
		
		local spellID, duration, endTime;
		if ( type(icon.spellID) == "table" ) then
			-- Warlocks ... srsly!	
			
			-- Check if one of the spellocks has an entry in the cache:
			for key, interruptTable in pairs(icon.spellID) do
				spellID, duration = unpack(interruptTable);
				
				if ( cooldownCache[guid][spellID] ) then
					endTime = cooldownCache[guid][spellID];
					break;
				end
			end

		elseif ( cooldownCache[guid][icon.spellID] ) then
			duration = icon.duration;
			endTime = cooldownCache[guid][icon.spellID];
		end
		
		-- Return the match, if we have one:
		if ( endTime ) then
			-- Check if the cooldown that was found has run out already:
			if ( endTime > theTime ) then
				local startTime = endTime - duration;
				return startTime, duration;
			else
				-- Reset cache entry as the CD has run out already:
				cooldownCache[guid][icon.spellID] = nil;			
			end
		end
	end
		
	return nil, nil;
end

--[[ Method: UpdateTexture
	 Updates the texture for the specified icon.
		frame (frame): Unit frame the icon belongs to.
		icon (frame): Affected icon.
		iconType (string): type the icon will be updated to.
]]--
function Icon:SetTexture(frame, icon, iconType)
	local unit = frame.unit;
	if ( not unit ) then
		return;
	end

	-- Gather data to get the correct texture:
	local _, class, race, faction, sex, classID, specID, reaction, isPlayer;
	
	if ( frame.test ) then
		race, sex = ArenaLive.testModeValues[frame.test]["race"], ArenaLive.testModeValues[frame.test]["sex"];
		class, classID, specID = ArenaLive.testModeValues[frame.test]["class"], ArenaLive.testModeValues[frame.test]["classID"], ArenaLive.testModeValues[frame.test]["specID"];
		reaction, faction = ArenaLive.testModeValues[frame.test]["reaction"], ArenaLive.testModeValues[frame.test]["faction"];
		isPlayer = true;
	else
		_, class = UnitClass(unit);
		_, race = UnitRace(unit);
		faction = UnitFactionGroup(unit);
		sex = UnitSex(unit);
		isPlayer = UnitIsPlayer(unit);
	end

	local texture = "Interface\\Icons\\INV_Misc_QuestionMark"; -- This is the basic texture, if no other texture is found, this question mark will be shown instead.
	icon.texture:SetTexCoord(0, 1, 0, 1);
	
	if ( race and sex and iconType == "race" ) then
		if ( sex > 1 ) then
			texture = "Interface\\Glues\\CharacterCreate\\UI-CHARACTERCREATE-RACES";
			icon.texture:SetTexCoord(unpack(RACE_GENDER_ICON_TCOORDS[race][sex]));
		end
	elseif ( isPlayer and class and iconType == "class" ) then
			texture = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes";
			icon.texture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]));
	elseif ( iconType == "reaction" ) then
		local red, green, blue;
		
		if ( frame.test ) then
			red, green, blue = unpack(reaction);
		else
			red, green, blue = UnitSelectionColor(unit);
		end

		if ( not UnitPlayerControlled(unit) and UnitIsTapDenied(unit) and not UnitIsTappedByPlayer(unit) and not UnitIsTappedByAllThreatList(unit) ) then
			icon.texture:SetTexture(0.5, 0.5, 0.5, 1);
		else
			icon.texture:SetTexture(red, green, blue, 1);
		end
		
		return;
	elseif ( iconType == "specialisation" ) then
		--[[ Currently it is only possible to retrieve talent spec for "arena" and "player" unitIDs.
			 For other unitIDs we would need to query the server via an inspect, which isn't very efficient. ]]
		local spellIcon;
		local unitType = string.match(unit, "^([a-z]+)[0-9]+$") or unit;
		local unitNumber = tonumber(string.match(unit, "^[a-z]+([0-9]+)$"));
		
		-- Testmode must be treated differently:
		if ( frame.test ) then
			texture = select(4, GetSpecializationInfoForClassID(classID, specID));
		elseif ( unitType == "player" or UnitIsUnit("player", unit) ) then
			-- Spec icon for player:
			specID = C_SpecializationInfo.GetSpecialization();
			
			if ( specID ) then
				spellIcon = select(4, C_SpecializationInfo.GetSpecializationInfo(specID));
			end
			
		elseif ( unitType == "arena" ) then
			-- Retrieve arena opponent data:
			local numOpps = GetNumArenaOpponentSpecs();
			local _, instanceType = IsInInstance();
			
			if ( numOpps and unitNumber and unitNumber <= numOpps ) then
				-- We're inside the arena and can track spec info:
				specID = GetArenaOpponentSpec(unitNumber);
				spellIcon = select(4, C_SpecializationInfo.GetSpecializationInfo(specID));
			elseif ( faction and instanceType ~= "arena" ) then
				-- This is the case if we're in a Flag BG. "arena" unitIDs show the flag carrier in these BGs since MoP:
				spellIcon = "Interface\\TargetingFrame\\UI-PVP-"..faction;
			end
			
		end
		-- TODO: Once WoD's spectator mode is released, add function to show spec icon for new spectator unitIDs too. =)
		if ( spellIcon ) then
			texture = spellIcon;
		end
		
	elseif ( faction and iconType == "trinket" ) then
	
		if ( faction == "Alliance" ) then
			texture = "Interface\\ICONS\\INV_Jewelry_TrinketPVP_01";
		else
			texture = "Interface\\ICONS\\INV_Jewelry_TrinketPVP_02";
		end	
	
	elseif ( icon.spellID and ( iconType == "racial" or iconType == "interrupt" or iconType == "dispel" ) ) then
		local spellIcon;
		if ( type(icon.spellID) == "table" ) then
			-- Simply use the first spellID in the table, as they all have the same icon:
			spellIcon = select(3, GetSpellInfo(icon.spellID[1][1]));
		else
			spellIcon = select(3, GetSpellInfo(icon.spellID));
		end

		if ( icon ) then
			texture = spellIcon;
		end	
	end
	
	icon.texture:SetTexture(texture);

end

function Icon:Reset(frame)
	if ( not frame[self.name] ) then
		return;
	end
	
	for id in pairs(frame[self.name]) do
		local icon = frame[self.name][id];
		Icon:ResetSingleIcon(icon);
	end
end

function Icon:ResetSingleIcon(icon)
	icon.cooldown:Reset();
	icon.texture:SetTexCoord(0, 1, 0, 1);
	icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
end

--[[ Method: UpdateCooldownCache
	 Checks if a spell is a cooldown that needs to be added to the cooldown cache and adds it correctly.
		event (string): event that fired.
		spellID: spellID of the spell that needs to be checked.
		unit (string): unitID that casted the spell.
		guid (string): unitGUID that casted the spell.
	 Returns:
		True if there was a spell added to the cooldown cache. If necessary it also returns the spellID of a spell that has a shared CD with the specified spellID.
]]--
function Icon:UpdateCooldownCache (event, spellID, unit, guid)
	local spellCD, sharedID, sharedCD;
	if ( event == "UNIT_SPELLCAST_SUCCEEDED" and unit ) then
		local isPlayer = UnitIsPlayer(unit);
		
		
		if ( not isPlayer ) then
			return;
		end
		
		guid = guid or UnitGUID(unit);
		local _, class = UnitClass(unit);
		local _, race = UnitRace(unit);
		
		
		-- Get Trinket spellID and CD:
		local trinketID, trinketCD = unpack(ArenaLive.spellDB.Trinket);
		
		-- Get racial's spellID, spellCD and sharedCD:
		local racialID, racialCD, racialSharedCD;
		if ( ArenaLive.spellDB.Racials[race][class] ) then
			racialID, racialCD, racialSharedCD = unpack(ArenaLive.spellDB.Racials[race][class]);
		else
			racialID, racialCD, racialSharedCD = unpack(ArenaLive.spellDB.Racials[race]);
		end
		
		-- Check if Trinket:
		if ( spellID == trinketID ) then
			spellCD = trinketCD; 
			
			-- Check if the unit's racial shares CD with pvp-trinket:
			if ( racialSharedCD > 0 ) then
				sharedID = racialID;
				sharedCD = racialSharedCD;
			end
		
		-- Check if racial ability:
		elseif ( spellID == racialID ) then
			spellCD = racialCD;
			
			-- Check if the unit's racial shares CD with pvp-trinket:
			if ( racialSharedCD > 0 ) then
				sharedID = trinketID;
				sharedCD = racialSharedCD;
			end		
		elseif ( ArenaLive.spellDB.Interrupts[class] ) then
			-- Check if interrupt This is going to be a bit messy, due to warlocks having more than one spellID for their interrupt:
			local interruptID, interruptCD;
			if ( type(ArenaLive.spellDB.Interrupts[class][1]) == "table" ) then
				for key, interruptsTable in pairs(ArenaLive.spellDB.Interrupts[class]) do
					interruptID, interruptCD = interruptsTable[1], interruptsTable[2];
					if ( spellID == interruptID ) then
						spellCD = interruptCD;
						break;
					end
				end
			else
				interruptID, interruptCD = unpack(ArenaLive.spellDB.Interrupts[class]);
				
				if ( spellID == interruptID ) then
					spellCD = interruptCD;
				end
			end
		end
		
		
	elseif ( event == "COMBAT_LOG_EVENT_UNFILTERED_SPELL_DISPEL" and guid ) then
	
		local _, class = GetPlayerInfoByGUID(guid);
		
		-- GetPlayerInfoByGUID only returns data for players. This means that if class is nil we can assume that the guid is not a player
		if ( not class or not ArenaLive.spellDB.Dispels[class] ) then
			return;
		end

		local dispelID, dispelCD = unpack(ArenaLive.spellDB.Dispels[class]);
		if ( spellID ==  dispelID ) then
			spellCD = dispelCD;
		end
	
	end
	
	-- If a match was found then update the cooldown cache:
	if ( spellCD ) then		
		-- Create an entry for this guid, if there is none.
		if ( not cooldownCache[guid] ) then
			cooldownCache[guid] = {};
		end
		
		-- Calculate end of the CD by adding the current time to the duration. This is way more efficient than tracking cooldown in real time via OnUpdate scripts.
		spellCD = spellCD + GetTime();		
		
		-- Add SpellCD to the cache:
		cooldownCache[guid][spellID] = spellCD;
		
		-- Add shared ability CD if necessary:
		if ( sharedID and sharedCD ) then
			-- Add the current time to the shared CD. Same as for the spellCD:
			sharedCD = sharedCD + GetTime();
			
			-- Check if there already is an entry for the shared CD and if cooldown is higher than the new one:
			if ( not cooldownCache[guid][sharedID] or cooldownCache[guid][sharedID] < sharedCD ) then
				cooldownCache[guid][sharedID] = sharedCD;
			end
		end
		
		return true, sharedID;

	end
	
	return;
end

--[[ Method: OnEvent
	 OnEvent script handler for Icon handler.
		event (string): Event that fired.
		... (mixed): A list of further args that accompany the event.
]]--
function Icon:OnEvent(event, ...)
	
	if ( event == "PLAYER_SPECIALIZATION_CHANGED" ) then
		-- Update all frames that show the player:
		local playerGUID = UnitGUID("player");
		if ( ArenaLive:IsGUIDInUnitFrameCache(playerGUID) ) then
			for id, isRegistered in ArenaLive:GetAffectedUnitFramesByGUID(playerGUID) do
				local frame = ArenaLive:GetUnitFrameByID(id);
				Icon:Update(frame, "specialisation");
			end
		end
	elseif ( event == "UNIT_FACTION" ) then
		local unit = ...;
		if ( ArenaLive:IsUnitInUnitFrameCache(unit) ) then
			for id, isRegistered in ArenaLive:GetAffectedUnitFramesByUnit(unit) do
				local frame = ArenaLive:GetUnitFrameByID(id);
				Icon:Update(frame, "reaction");
			end
		end
	elseif ( event == "UNIT_SPELLCAST_SUCCEEDED" ) then
		local unit = select(1, ...);
		local spellID = select(3, ...);
		local guid = UnitGUID(unit);

		-- Update cooldown cache:
		local wasCacheUpdated, sharedID = Icon:UpdateCooldownCache(event, spellID, unit, guid);
		
		if ( wasCacheUpdated ) then
			if ( ArenaLive:IsGUIDInUnitFrameCache(guid) ) then
				for id, isRegistered in ArenaLive:GetAffectedUnitFramesByGUID(guid) do
					local frame = ArenaLive:GetUnitFrameByID(id);
					Icon:Update(frame);
				end
			end
		end
	elseif ( event == "COMBAT_LOG_EVENT_UNFILTERED_SPELL_DISPEL" ) then
		local guid = select(4, ...);
		local spellID = select(15, ...);
		
		-- Update cooldown cache:
		local wasCacheUpdated, sharedID = Icon:UpdateCooldownCache(event, spellID, unit, guid);
		
		if ( wasCacheUpdated ) then
			if ( ArenaLive:IsGUIDInUnitFrameCache(guid) ) then
				for id, isRegistered in ArenaLive:GetAffectedUnitFramesByGUID(guid) do
					local frame = ArenaLive:GetUnitFrameByID(id);
					Icon:Update(frame);
				end
			end
		end
	elseif ( event == "COMBAT_LOG_EVENT_UNFILTERED_SPELL_INTERRUPT" ) then
		--[[ Bugfix for Ticket 41: Mages get their Counter Spell cooldown reduced by 4 sec. whenever they successfully interrupt someone,
			 if they have the 2 piece set bonus of the PvP-Set. So always reduce the cooldown on a successful counter spell by 4 sec to make
			 sure that always the lowest possible cooldown is shown. ]]
			local guid = select(4, ...);
			local spellID = select(12, ...);
			if ( guid and spellID and spellID == ArenaLive.spellDB.Interrupts.MAGE[1] and cooldownCache[guid][spellID] ) then
				cooldownCache[guid][spellID] = cooldownCache[guid][spellID] - 4;
				if ( ArenaLive:IsGUIDInUnitFrameCache(guid) ) then
					for id, isRegistered in ArenaLive:GetAffectedUnitFramesByGUID(guid) do
						local frame = ArenaLive:GetUnitFrameByID(id);
						Icon:Update(frame);
					end
				end
			end
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
		-- Wipe the cooldown cache when entering the arena, because all cooldowns will be resetted.
		local _, instanceType = IsInInstance();
		
		if ( instanceType == "arena" ) then
			ArenaLive:Message(L["Entering arena, wiping Icon cooldown cache table..."], "debug");
			table.wipe(cooldownCache);
			
			for id, frame in ArenaLive:GetAllUnitFrames() do
				Icon:Update(frame);
			end
		end
	end
end
   
-- Option frame set ups:
-- Note that you need to set frame.id as the icon identifier of the affected frame.
local iconTypes = {
	[1] = {
		["value"] = "class",
		["text"] = L["Class Icon"],
	},
	[2] = {
		["value"] = "dispel",
		["text"] = L["Dispel Cooldown"],
	},
	[3] = {
		["value"] = "interrupt",
		["text"] = L["Interrupt Cooldown"],
	},
	[4] = {
		["value"] = "race",
		["text"] = L["Race Icon"],
	},
	[5] = {
		["value"] = "racial",
		["text"] = L["Racial Ability Cooldown"],
	},
	[6] = {
		["value"] = "reaction",
		["text"] = L["Reaction Colour"],
	},
	[7] = {
		["value"] = "specialisation",
		["text"] = L["Talent Specialisation Icon"],
	},
	[8] = {
		["value"] = "trinket",
		["text"] = L["PvP Insignia"],
	},
};
Icon.optionSets = {
	["IconType"] = {
		["type"] = "DropDown",
		["width"] = 150,
		["title"] = L["Icon Type"],
		["emptyText"] = L["Choose Icon Type"],
		["infoTable"] = iconTypes,
		["GetDBValue"] = function (frame) 
			if ( not frame.id ) then
				ArenaLive:Message(L["Cannot interact with database, because frame %s has no value set for key \"id\"!"], "error", frame:GetName() or frame);
			end
			
			local database = ArenaLive:GetDBComponent(frame.addon, frame.handler, frame.group);
			return database[frame.id]["Type"]; 
		end,
		["SetDBValue"] = function (frame, newValue)
			if ( not frame.id ) then
				ArenaLive:Message(L["Cannot interact with database, because frame %s has no value set for key \"id\"!"], "error", frame:GetName() or frame);
			end
			local database = ArenaLive:GetDBComponent(frame.addon, frame.handler, frame.group);
			database[frame.id]["Type"] = newValue;
		end,
		["postUpdate"] = function (frame, newValue, oldValue)
			for id, unitFrame in ArenaLive:GetAllUnitFrames() do 
				if ( unitFrame.addon == frame.addon and unitFrame.group == frame.group and unitFrame[frame.handler] ) then 
					Icon:UpdateSingleIcon(unitFrame, frame.id);
				end
			end 
		end,
	},
	["FallBackType"] = {
		["type"] = "DropDown",
		["width"] = 150,
		["title"] = L["Fallback Type"],
		["emptyText"] = L["Choose Fallback Type"],
		["infoTable"] = iconTypes,
		["tooltip"] = L["Sets a fallback option that will be used whenever the normal icon type is note available for the unit frame."],
		["GetDBValue"] = function (frame) 
			if ( not frame.id ) then
				ArenaLive:Message(L["Cannot interact with database, because frame %s has no value set for key \"id\"!"], "error", frame:GetName() or frame);
			end
			
			local database = ArenaLive:GetDBComponent(frame.addon, frame.handler, frame.group);
			return database[frame.id]["FallBackType"]; 
		end,
		["SetDBValue"] = function (frame, newValue)
			if ( not frame.id ) then
				ArenaLive:Message(L["Cannot interact with database, because frame %s has no value set for key \"id\"!"], "error", frame:GetName() or frame);
			end
			local database = ArenaLive:GetDBComponent(frame.addon, frame.handler, frame.group);
			database[frame.id]["FallBackType"] = newValue;
		end,
		["postUpdate"] = function (frame, newValue, oldValue)
			for id, unitFrame in ArenaLive:GetAllUnitFrames() do 
				if ( unitFrame.addon == frame.addon and unitFrame.group == frame.group and unitFrame[frame.handler] ) then 
					Icon:UpdateSingleIcon(unitFrame, frame.id);
				end
			end 
		end,
	},
};