--[[
    ArenaLive [Spectator] is an user interface for spectated arena 
	wargames in World of Warcraft.
    Copyright (C) 2015  Harald Böhm <harald@boehm.agency>
	Further contributors: Jochen Taeschner and Romina Schmidt.
	
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
	
	ADDITIONAL PERMISSION UNDER GNU GPL VERSION 3 SECTION 7:
	As a special exception, the copyright holder of this add-on gives you
	permission to link this add-on with independent proprietary software,
	regardless of the license terms of the independent proprietary software.
]]

-- Addon Name and localisation table:
local FORCED_ALPHA = true
local NAMEPLATE_SIZE = 0.9
local NAMEPLATE_TARGET_SIZE = 1.0

if (FORCED_ALPHA == true) then
    SetCVar("nameplateNotSelectedAlpha", 1)
end

-- Addon Name and localisation table:
local addonName, L = ...;

local ArenaLiveNamePlatesFrame = CreateFrame("Frame", "ArenaLiveNamePlates3", UIParent)
ArenaLiveNamePlatesFrame.defaults = {
	["FirstLogin"] = true,
	["Version"] = "3.2.3b",
	["Cooldown"] =	{
		["ShowText"] = true,
		["StaticSize"] = false,
		["TextSize"] = 8,
	},
	["CCIndicator"] =	{
		["Priorities"] = {
			["defCD"] = 9,
			["offCD"] = 3,
			["stun"] = 8,
			["silence"] = 7,
			["crowdControl"] = 6,
			["root"] = 5,
			["disarm"] = 4,
			["usefulBuffs"] = 0,
			["usefulDebuffs"] = 0,
		},
	},
	["NamePlate"] = {
		["CCIndicator"] = {
			["Enabled"] = true,
		},
		["HealthBar"] = {
			["ColourMode"] = "class",
			["ShowHealPrediction"] = true,
			["ShowAbsorb"] = true,
		},
	},
};

local ArenaLiveNamePlates = ArenaLive:ConstructAddon(ArenaLiveNamePlatesFrame, addonName, false, ArenaLiveNamePlatesFrame.defaults, false, "ALNP_Database")

--[[
**************************************************
******* GENERAL HANDLER SET UP STARTS HERE *******
**************************************************
]]--
local NamePlate = ArenaLive:ConstructHandler("NamePlate", true, true);
local CCIndicator = ArenaLive:GetHandler("CCIndicator");
local HealthBar = ArenaLive:GetHandler("HealthBar");
local NameText = ArenaLive:GetHandler("NameText");
local playerExistState = {};


-- Register for needed events:
NamePlate:RegisterEvent("PLAYER_ENTERING_WORLD");
NamePlate:RegisterEvent("PLAYER_TARGET_CHANGED");
NamePlate:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED");
NamePlate:RegisterEvent("UNIT_AURA");
NamePlate:RegisterEvent("UNIT_NAME_UPDATE");
NamePlate:RegisterEvent("UNIT_PET");
NamePlate:RegisterEvent("UNIT_HEALTH");
NamePlate:RegisterEvent("UNIT_HEAL_PREDICTION");
NamePlate:RegisterEvent("NAME_PLATE_CREATED");
NamePlate:RegisterEvent("NAME_PLATE_UNIT_ADDED");
NamePlate:RegisterEvent("NAME_PLATE_UNIT_REMOVED");

-- Set Attributes:
NamePlate.unitCache = {};
NamePlate.unitNameCache = {};
NamePlate.namePlates = {};

-- Create NamePlate Class:
local NamePlateClass = {};

--[[
*****************************************
*** PRIVATE HOOK FUNCTIONS START HERE ***
*****************************************
]]--
local function NamePlateHealthBar_OnValueChanged(healthBar)
	local blizzPlate = healthBar:GetParent():GetParent();
	local namePlate = NamePlate.namePlates[blizzPlate];
	if ( namePlate.enabled ) then
		namePlate:UpdateHealthBar();
	end
end

local function NamePlateCastBar_OnValueChanged(castBar)
	local blizzPlate = castBar:GetParent():GetParent();
	local namePlate = NamePlate.namePlates[blizzPlate];
	if ( namePlate.enabled ) then
		namePlate:UpdateCastBar();
	end
end



--[[
****************************************
****** HANDLER METHODS START HERE ******
****************************************
]]--
function NamePlate:ConstructObject(namePlate, addonName, frameGroup)
	local prefix = namePlate:GetName();
	namePlate.addon = addonName;
	namePlate.group = frameGroup;
	
	-- Copy Class Methods:
	ArenaLive:CopyClassMethods(NamePlateClass, namePlate);	
	
	-- Construct CC Indicator:
	namePlate.CCIndicator = _G[prefix.."CCIndicator"];
	CCIndicator:ConstructObject(_G[prefix.."CCIndicator"], _G[prefix.."CCIndicatorTexture"], _G[prefix.."CCIndicatorCooldown"], addonName);
	
	-- Construct HealthBar:
	HealthBar:ConstructObject(_G[prefix.."HealthBar"], _G[prefix.."HealthBarHealPredictionBar"], _G[prefix.."HealthBarAbsorbBar"], _G[prefix.."HealthBarAbsorbBarOverlay"], 32, _G[prefix.."HealthBarAbsorbBarFullHPIndicator"], nil, addonName, frameGroup);
	
	-- Set reference where needed:
	namePlate.nameText = _G[prefix.."NameText"];
	namePlate.healerIcon = _G[prefix.."HealerIcon"];
	namePlate.border = _G[prefix.."Border"];
	
	
	namePlate:SetScript("OnShow", namePlate.OnShow);
	
	-- Enable or disable name plate according to spectator state:
    namePlate:Enable();

end

function NamePlate:Enable()
	self:Show();
	for blizzPlate, namePlate in pairs(self.namePlates) do
		namePlate:Enable();
	end
	self.enabled = true;
end

function NamePlate:Disable()
	self:Hide();
	for blizzPlate, namePlate in pairs(self.namePlates) do
		namePlate:Disable();
	end
	
	self.enabled = false;
end

function NamePlate:GetReactionType(r, g, b)
	-- I use 0.9 instead of 1, because getter functions
	-- most of the time return not 1, but 0,998 etc.
	if ( r > 0.9 and g > 0.9 and b == 0 ) then
		return "Neutral";
	elseif ( r > 0.9 and g == 0 and b == 0 ) then
		return "Hostile";
	elseif ( g > 0.9 and r == 0 and b == 0 ) then
		return "PvP-Friendly";
	elseif ( b > 0.9 and r == 0 and g == 0 ) then
		return "Friendly";
	else
		return "Hostile-Player" -- Only hostile/neutral players can have class colours.
	end
end

function NamePlate:SetBlizzPlateStructure(blizzPlate)

    if not blizzPlate.UnitFrame or blizzPlate.hooked then return end

    blizzPlate.hooked = true

	-- Get castbar and healthbar of a nameplate:
	local healthBar = blizzPlate.UnitFrame.healthBar;
	local castBar = blizzPlate.UnitFrame.CastBar

	-- Secure hook scripts:
	healthBar:HookScript("OnValueChanged", NamePlateHealthBar_OnValueChanged);
	healthBar:HookScript("OnMinMaxChanged", NamePlateHealthBar_OnValueChanged);
	castBar:HookScript("OnValueChanged", NamePlateCastBar_OnValueChanged);
	castBar:HookScript("OnMinMaxChanged", NamePlateCastBar_OnValueChanged);
	castBar:HookScript("OnShow", NamePlateCastBar_OnValueChanged);
	castBar:HookScript("OnHide", NamePlateCastBar_OnValueChanged);

end

function NamePlate:CreateNamePlate(blizzPlate)
	local id = string.match(blizzPlate:GetName(), "^NamePlate(%d+)$");
	local namePlate = CreateFrame("Frame", "ArenaLiveNamePlate"..id, blizzPlate, "ArenaLiveSpectatorNamePlateTemplate");
	self.namePlates[blizzPlate] = namePlate;
	ArenaLive:ConstructHandlerObject(namePlate, "NamePlate", addonName, "NamePlate");

	blizzPlate:HookScript("OnUpdate", function()
        if blizzPlate.UnitFrame then
            if namePlate.enabled then
                blizzPlate.UnitFrame:SetAlpha(0)
                blizzPlate.UnitFrame.healthBar.border:SetAlpha(0)
                for i=1, select("#", blizzPlate.UnitFrame.healthBar:GetRegions()) do
                    select(i, blizzPlate.UnitFrame.healthBar:GetRegions()):SetAlpha(0)
                end
                blizzPlate.UnitFrame.CastBar:SetAlpha(0)
            else
                blizzPlate.UnitFrame:SetAlpha(1)
                blizzPlate.UnitFrame.healthBar:SetAlpha(1)
                for i=1, select("#", blizzPlate.UnitFrame.healthBar:GetRegions()) do
                    select(i, blizzPlate.UnitFrame.healthBar:GetRegions()):SetAlpha(1)
                end
                blizzPlate.UnitFrame.CastBar:SetAlpha(1)
            end
        end
    end)
end

function NamePlate:UpdateAll()
	if ( self.enabled ) then
		for _, namePlate in pairs(NamePlate.namePlates) do
			NamePlate:UpdateNamePlate(namePlate);
		end
	end
end

function NamePlate:UpdateNamePlate(namePlate)
	local blizzPlate = namePlate:GetParent();
	if not blizzPlate.UnitFrame then return end

	namePlate:UpdateUnit(namePlate.unit);
	namePlate:Update();
end

function NamePlate:PlateReactionIsUnitReaction(blizzPlate, unit)
	local plateReaction = NamePlate:GetReactionType(blizzPlate.UnitFrame.healthBar:GetStatusBarColor());
	local unitReaction = NamePlate:GetReactionType(UnitSelectionColor(unit));
	local isPlayer = UnitIsPlayer(unit);
	local _, _, _, _, teamID = ArenaLiveSpectator.UnitCache:GetUnitInfo(unit);
	local _, gameType = IsSpectator();

	if ( isPlayer and gameType == "battleground" and ( ( teamID == 1 and ( plateReaction == "Hostile-Player" or plateReaction == "Friendly" ) and unitReaction == "PvP-Friendly" ) or ( teamID == 0 and unitReaction == "Hostile" and plateReaction == "Hostile-Player" ) ) ) then
		return true;
	elseif ( isPlayer and gameType == "arena" and unitReaction == "Hostile" and plateReaction == "Hostile-Player" ) then
		return true;
	elseif ( not isPlayer and ( unitReaction == "Friendly" and plateReaction == "Hostile" ) ) then
		return true;
	elseif ( unitReaction == plateReaction ) then
		return true;
	else
		return false;
	end
end

function NamePlate:UpdateUnitCacheEntry(unit)
	local oldName = self.unitCache[unit];
	
	-- Reset old name cache entry if necessary:
	if ( oldName ) then
		self.unitNameCache[oldName] = nil;
	end
	
	-- Apply new name data to cache:
	local name = GetUnitName(unit);
	if ( name ) then
		--ArenaLive:Message("NamePlate:UpdateUnitCacheEntry(): Called for unit %s, name = %s", "debug", "NamePlate:UpdateUnitCacheEntry()", unit, tostring(name));
		self.unitCache[unit] = name;
		self.unitNameCache[name] = unit;
	end
end


function NamePlate:OnEvent(event, ...)
	local unit = ...;
	if ( ( event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_PREDICTION" ) ) then
		for blizzPlate, namePlate in pairs(self.namePlates) do
			if ( unit == namePlate.unit ) then
				HealthBar:Update(namePlate);
			end
		end
    elseif ( event == "PLAYER_TARGET_CHANGED" ) then
        for blizzPlate, namePlate in pairs(self.namePlates) do
            namePlate:UpdateAppearance();
        end
	elseif ( event == "UNIT_AURA" ) then
		for blizzPlate, namePlate in pairs(self.namePlates) do
			if ( unit == namePlate.unit ) then
				CCIndicator:Update(namePlate);
			end
		end
	elseif ( event == "UNIT_NAME_UPDATE" ) then
		NamePlate:UpdateUnitCacheEntry(unit);
		NamePlate:UpdateAll();
	elseif ( event == "UNIT_PET" ) then
		local unitType = string.match(unit, "^([a-z]+)[0-9]+$") or unit;
		local unitNumber = string.match(unit, "^[a-z]+([0-9]+)$");
		if ( not unitNumber ) then
			return;
		end
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
        NamePlate:Enable();
    elseif ( event == "NAME_PLATE_CREATED" ) then
        local unitFrame = ...
        self:CreateNamePlate(unitFrame);
        --ArenaLiveNamePlatesFrame:CrawlNamePlateData(unitFrame)
    elseif ( event == "NAME_PLATE_UNIT_ADDED" ) then
        local unit = ... -- nameplate1
        local unitFrame = C_NamePlate.GetNamePlateForUnit(unit, issecure())
        self:SetBlizzPlateStructure(unitFrame);

        unitFrame.unit = unit
        local namePlate = self.namePlates[unitFrame];
        namePlate.unit = unit
        namePlate:Update()
        NamePlate:UpdateNamePlate(namePlate);
    elseif ( event == "NAME_PLATE_UNIT_REMOVED" ) then
        local unit = ... -- nameplate1
        local unitFrame = C_NamePlate.GetNamePlateForUnit(unit, issecure())
        unitFrame.unit = unit
        local namePlate = self.namePlates[unitFrame];
        namePlate.unit = unit
        namePlate:Update()
        NamePlate:UpdateNamePlate(namePlate);
	end
end

local children;
function ArenaLiveNamePlatesFrame:CrawlNamePlateData(nameplate)

	local children = {nameplate:GetChildren()};
	local regions = {nameplate:GetRegions()};
	local i = 1;
	
	print(nameplate:GetParent():GetName());
	for key, value in pairs(nameplate) do
		print(tostring(key).." = "..tostring(value));
	end
	
	for _, child in ipairs(children) do
		local frameType = child:GetObjectType();
		local subChildren = {child:GetChildren()}
		local subRegions = {child:GetRegions()};
		
		print(tostring("Child"..tostring(i))..": FrameType = "..tostring(frameType));
		
		local subID = 1;
		for _, subChild in ipairs(subChildren) do
			local minvalue, maxvalue, value;
			local objectType = subChild:GetObjectType();
			if ( objectType == "StatusBar" ) then
				minvalue, maxvalue = subChild:GetMinMaxValues();
				value = subChild:GetValue();
				local name = subChild:GetName();
				local subsubchildren = subChild:GetNumChildren();
				local subsubRegions = {subChild:GetRegions()};
				print("     "..tostring("SubChild"..tostring(subID))..": FrameType = "..tostring(objectType).."; MinValue = "..tostring(minvalue).."; MaxValue = "..tostring(maxvalue).."; Value = "..tostring(value)..";");
				subID = subID + 1; 
				for key, subsubRegion in pairs(subsubRegions) do
					local subsubRegionType = subsubRegion:GetObjectType();
					if ( subsubRegionType == "FontString" ) then
						local subsubText = subsubRegion:GetText();
						print("          5:"..tostring(subsubText));
					elseif ( subsubRegionType == "Texture" ) then
						local subsubTexture = subsubRegion:GetTexture();
						print("         ", key, ": "..tostring(subsubTexture));
					end
				end
			end
		end
		
		local subRegionID = 1;
		for _, region in ipairs(subRegions) do
			local regionType = region:GetObjectType();
			local content;
			
			if ( regionType == "Texture" ) then
				content = region:GetTexture();
			elseif ( regionType == "FontString" ) then
				content = region:GetText();
			end
			
			print("     "..tostring("SubRegion")..tostring(subRegionID)..": RegionType = "..tostring(regionType).."; Content = "..tostring(content));
			subRegionID = subRegionID + 1;
		end
		
		i = i + 1;
	end
	
	local regionID = 1;
	for _, region in ipairs(regions) do
		local regionName = region:GetName();
		local regionType = region:GetObjectType();
		print (tostring(regionName).."(Region"..tostring(subRegionID).."): RegionType = "..tostring(regionType));
		regionID = regionID + 1;
	end
end

--[[
****************************************
******* CLASS METHODS START HERE *******
****************************************
]]--
function NamePlateClass:Enable()
	local blizzPlate = self:GetParent();
	
	self:Show();
	self.enabled = true;
	
	NamePlate:UpdateNamePlate(self);
end

function NamePlateClass:Disable()
	local blizzPlate = self:GetParent();

	self:Hide();
	self.enabled = false;
	
	self:Reset();
end

function NamePlateClass:Update()
	if ( self.enabled ) then
		self:UpdateCastBar();
		CCIndicator:Update(self);
		self:UpdateClassIcon();
		self:UpdateHealthBar();
		self:UpdateNameText()
	end
end

function NamePlateClass:UpdateAppearance()
	local blizzPlate = self:GetParent();
	local database = ArenaLive:GetDBComponent(addonName);
	local inInstance, gameType = IsInInstance()
    local isInPvP = gameType == "pvp" or gameType == "arena"
    local isPlayer = self.unit and UnitIsPlayer(self.unit)

	if ( isInPvP and self.unit and isPlayer ) then
		self:SetSize(188, 52);
        if ( self.unit and UnitGUID(self.unit) == UnitGUID("target") ) then
            self:SetScale(NAMEPLATE_TARGET_SIZE);
        else
            self:SetScale(NAMEPLATE_SIZE);
        end
		
		self.classIcon:Show();
		
		-- we need minimum 81.25% of the original height of the texture to display it, as in 104 of 128 pixels
        -- because textures get stretched, that means we need to display 416 (81.25%) pixel in width
        self.border:SetTexture("Interface\\AddOns\\ArenaLiveNamePlates3\\Textures\\PlayerNamePlateBig");
        self.border:SetTexCoord(0.09875, 0.90125, 0.125, 0.9375);
		
		self.HealthBar:ClearAllPoints();
        self.HealthBar:SetWidth(120)
        self.HealthBar:SetPoint("TOPLEFT", self.classIcon, "TOPRIGHT", 0, 4);

        self.castBar:ClearAllPoints();
        self.castBar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 58, 16);
	    --[[
		local role = ArenaLiveSpectator.UnitCache:GetUnitRole(self.unit);
		if ( role == "HEALER" ) then
			self.healerIcon:Show();
		else
			self.healerIcon:Hide();
		end
        ]]
	else
		self:SetSize(137, 22);
		if ( self.unit and UnitGUID(self.unit) == UnitGUID("target") ) then
            self:SetScale(NAMEPLATE_TARGET_SIZE);
        else
            self:SetScale(NAMEPLATE_SIZE);
        end

		self.classIcon:Hide();
		
		self.border:SetTexture("Interface\\AddOns\\ArenaLiveNamePlates3\\Textures\\NamePlateBorder");
		self.border:SetTexCoord(0.28125, 0.81640625, 0.2421875, 0.5859375);

		self.HealthBar:ClearAllPoints();
		self.HealthBar:SetWidth(125)
		self.HealthBar:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -2);

		self.castBar:ClearAllPoints();
		self.castBar:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 5, 0);
		
		self.healerIcon:Hide();
	end
	
	-- Set border colour:
	local red, green, blue;
	if ( self.unit ) then
		local unitType = string.match(self.unit, "^([a-z]+)[0-9]+$") or self.unit;
        red, green, blue = UnitSelectionColor(self.unit);
	elseif blizzPlate.UnitFrame then
		red, green, blue = blizzPlate.UnitFrame.healthBar:GetStatusBarColor();
	end

	self.border:SetVertexColor(red, green, blue);
end

function NamePlateClass:UpdateCastBar()
	local blizzPlate = self:GetParent();
	if not blizzPlate.UnitFrame then return end

	if ( blizzPlate.UnitFrame.CastBar:IsShown() ) then
		if ( not self.castBar:IsShown() ) then
			self.castBar:Show();
		end
		
		local minValue, maxValue = blizzPlate.UnitFrame.CastBar:GetMinMaxValues();
		local value = blizzPlate.UnitFrame.CastBar:GetValue();
		local texture = blizzPlate.UnitFrame.CastBar.Icon:GetTexture();
		local spellName = blizzPlate.UnitFrame.CastBar.Text:GetText();
		
		-- Prevent Division by zero:
		if ( maxValue == 0 ) then
			maxValue = 1;
		end		
		
		local red, green, blue = 1, 0.7, 0;
		if ( blizzPlate.UnitFrame.CastBar.BorderShield:IsShown() ) then
			red, green, blue = 0, 0.49, 1;
		end
		
		self.castBar:SetStatusBarColor(red, green, blue);
		self.castBar:SetMinMaxValues(minValue, maxValue);
		self.castBar:SetValue(value);
		self.castBar.icon:SetTexture(texture);
		self.castBar.text:SetText(spellName);
	elseif ( self.castBar:IsShown() ) then
		self.castBar:Hide();
	end
end

function NamePlateClass:UpdateClassIcon()
    local isInPvP = gameType == "pvp" or gameType == "arena"

	if ( isInPvP and self.unit and UnitIsPlayer(self.unit) ) then
		local _, class = UnitClass(self.unit);
		self.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]));
		self.classIcon:Show();
	else
		self.classIcon:Hide();
	end
end

function NamePlateClass:UpdateHealthBar()
	local blizzPlate = self:GetParent();
	if not blizzPlate.UnitFrame then return end
	
	-- Set class color if possible:
	local red, green, blue = blizzPlate.UnitFrame.healthBar:GetStatusBarColor();
	if ( self.unit ) then
		HealthBar:Update(self);
		if ( not UnitIsPlayer(self.unit) ) then
			-- A player's pet, use team colour instead:
			local database = ArenaLive:GetDBComponent(addonName);
			local unitType = string.match(self.unit, "^([a-z]+)[0-9]+$") or self.unit;
			self.HealthBar:SetStatusBarColor(red, green, blue);
		end
	else
		local minValue, maxValue = blizzPlate.UnitFrame.healthBar:GetMinMaxValues();
		local value = blizzPlate.UnitFrame.healthBar:GetValue();
		
		-- Prevent Division by zero:
		if ( maxValue == 0 ) then
			maxValue = 1;
		end
		
		HealthBar:Reset(self);
		self.HealthBar:SetStatusBarColor(red, green, blue);
		self.HealthBar:SetMinMaxValues(minValue, maxValue);
		self.HealthBar:SetValue(value);
	end
	
end

function NamePlateClass:UpdateNameText()
	local blizzPlate = self:GetParent();
	if not blizzPlate.UnitFrame then return end

	local name;
	if ( self.unit ) then
		name = NameText:GetNickname(self.unit) or UnitName(self.unit) or blizzPlate.UnitFrame.name:GetText();
	else
		name = blizzPlate.UnitFrame.name:GetText();
	end
	
	self.nameText:SetText(name);
end

function NamePlateClass:Reset()
	if ( self.enabled ) then
		self.castBar:Hide();
		CCIndicator:Reset(self);
		self.classIcon:SetTexCoord(0, 1, 0, 1);
		HealthBar:Reset(self);
		self.nameText:SetText("");
	end
end

function NamePlateClass:UpdateUnit(unit)
    local inInstance, gameType = IsInInstance()
    local isInPvP = gameType == "pvp" or gameType == "arena"

    self.unit = unit;
    if ( unit and isInPvP ) then
        self.CCIndicator.enabled = true;
    else
        self.CCIndicator.enabled = nil;
    end
	self:UpdateAppearance();
	self:UpdateGUID();
end

function NamePlateClass:UpdateGUID()
	if ( self.unit ) then
		local guid = UnitGUID(self.unit);
		if ( not self.guid or guid ~= self.guid ) then
			self.guid = guid;
			if ( guid ) then
				self:Update();
			else
				self:Reset();
			end
			
		end
	else
		self.guid = nil;
		self:Reset();
	end
end

function NamePlateClass:OnShow()
	if ( self.enabled ) then
		NamePlate:UpdateNamePlate(self);
	end
end