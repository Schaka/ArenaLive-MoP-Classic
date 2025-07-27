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

local addonName, L = ...;

local playerNameCache = {}
local reactionCache = {}

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

local relevantUnits = {
	"target",
    "targettarget",
	"focus",
	"focustarget",
	"arena1",
	"arena2",
	"arena3",
    "arena4",
	"arena5",
}

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
NamePlate:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
NamePlate:RegisterEvent("PLAYER_TARGET_CHANGED");
NamePlate:RegisterEvent("UNIT_AURA");
NamePlate:RegisterEvent("UNIT_NAME_UPDATE");
NamePlate:RegisterEvent("UNIT_PET");
NamePlate:RegisterEvent("UNIT_HEAL_PREDICTION");

-- Set Attributes:
NamePlate.numWorldFrameChildren = 0;
NamePlate.unitNameCache = {};
NamePlate.namePlates = {};

-- Create NamePlate Class:
local NamePlateClass = {};

--[[
****************************************
*** SCRIPT HOOK FUNCTIONS START HERE ***
****************************************
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

	-- we have to hackfix the cooldown frame, as the cooldown icon on nameplates constantly resets itself and is broken, so we simualte the frame
	local cooldown = CreateFrame("Cooldown", nil, indicator)
	cooldown.SetHideCountdownNumbers = function() end
	cooldown.SetSwipeColor = function() end
	cooldown.SetCooldown = function(self, startTime, duration)
		local remaining = duration - (GetTime() - startTime);
		self.remaining = remaining;
		self.elapsed = 0;
		if not self:IsShown() then
			self:Show()
		end
	end
	cooldown.Set = function(self, startTime, duration)
		local remaining = duration - (GetTime() - startTime)
		self.remaining = remaining;
		self.elapsed = 0;
		if not self:IsShown() then
			self:Show()
		end
	end

	local text = namePlate.CCIndicator:CreateFontString(nil, "OVERLAY", "ArenaLiveFont_CooldownText")
	text:SetAllPoints(namePlate.CCIndicator)
	cooldown.text = text

	--CCIndicator:ConstructObject(_G[prefix.."CCIndicator"], _G[prefix.."CCIndicatorTexture"], _G[prefix.."CCIndicatorCooldown"], addonName);
	CCIndicator:ConstructObject(_G[prefix.."CCIndicator"], _G[prefix.."CCIndicatorTexture"], cooldown, addonName);
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
	local mainFrame, nameFrame = blizzPlate:GetChildren();
	blizzPlate.mainFrame = mainFrame;
	blizzPlate.nameFrame = nameFrame;
	
	local mainFrameChildren = { mainFrame:GetChildren() };
	
	-- Get castbar and healthbar of a nameplate:
	local healthBar = mainFrameChildren[1];
	blizzPlate.healthBar = healthBar;
	
	local castBar = mainFrameChildren[2];
	local castBarRegions = { castBar:GetRegions() };
	blizzPlate.castBar = castBar;
	blizzPlate.castBar.shield = castBarRegions[3];
	blizzPlate.castBar.icon = castBarRegions[4];
	blizzPlate.castBar.text = castBarRegions[5];

	-- Get Name FontString:
	nameFontString = select(1, nameFrame:GetRegions());
	blizzPlate.nameText = nameFontString;
	
	-- Secure hook scripts:
	blizzPlate.healthBar:HookScript("OnValueChanged", NamePlateHealthBar_OnValueChanged);
	blizzPlate.healthBar:HookScript("OnMinMaxChanged", NamePlateHealthBar_OnValueChanged);
	blizzPlate.castBar:HookScript("OnValueChanged", NamePlateCastBar_OnValueChanged);
	blizzPlate.castBar:HookScript("OnMinMaxChanged", NamePlateCastBar_OnValueChanged);
	blizzPlate.castBar:HookScript("OnShow", NamePlateCastBar_OnValueChanged);
	blizzPlate.castBar:HookScript("OnHide", NamePlateCastBar_OnValueChanged);

	if (FORCED_ALPHA == true) then
		blizzPlate:HookScript("OnUpdate", function(frame)
			frame:SetAlpha(1.0)
		end)
	end	
end

function NamePlate:HideBlizzardNamePlate(blizzPlate)
	-- Set Alpha to zero instead of actually hiding them:
	blizzPlate.mainFrame:SetAlpha(0);
	blizzPlate.nameFrame:SetAlpha(0);
end

function NamePlate:ShowBlizzardNamePlate(blizzPlate)
	blizzPlate.mainFrame:SetAlpha(1);
	blizzPlate.nameFrame:SetAlpha(1);
end

function NamePlate:CreateNamePlate(blizzPlate)
	local id = string.match(blizzPlate:GetName(), "^NamePlate(%d+)$");
	local namePlate = CreateFrame("Frame", "ArenaLiveNamePlate"..id, blizzPlate, "ArenaLiveSpectatorNamePlateTemplate");
	self.namePlates[blizzPlate] = namePlate;
	ArenaLive:ConstructHandlerObject(namePlate, "NamePlate", addonName, "NamePlate");
end

function NamePlate:UpdateNamePlate(namePlate)
	local blizzPlate = namePlate:GetParent();
	local blizzPlateName = blizzPlate.nameText:GetText();
	
	local unit;
		
	for _, checkUnit in pairs(relevantUnits) do
		if UnitName(checkUnit) == blizzPlateName then
			unit = checkUnit
			break
		end
	end

	if not unit then
		namePlate.unit = nil
		namePlate:UpdateAppearance()
		namePlate:Update()
		return 
	end
	
	namePlate:UpdateUnit(unit);
	namePlate:Update();
end

function NamePlate:OnEvent(event, ...)
	local unit = ...;

	if event == "PLAYER_TARGET_CHANGED" then
		event = "UNIT_AURA"
		unit = "target"
	end

	if ( ( event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_PREDICTION" ) ) then
		for blizzPlate, namePlate in pairs(self.namePlates) do
			if ( unit == namePlate.unit ) then
				HealthBar:Update(namePlate);
			end
		end
	elseif ( event == "UNIT_AURA" ) then
		for blizzPlate, namePlate in pairs(self.namePlates) do
			if ( namePlate.unit and unit == namePlate.unit and namePlate.CCIndicator.enabled ) then
				CCIndicator:UpdateCache("UNIT_AURA", unit)
				CCIndicator:Update(namePlate);
			end
		end
	elseif ( event == "UNIT_NAME_UPDATE" ) then
		--NamePlate:UpdateAll();
	elseif ( event == "UNIT_PET" ) then
		local unitType = string.match(unit, "^([a-z]+)[0-9]+$") or unit;
		local unitNumber = string.match(unit, "^[a-z]+([0-9]+)$");
		if ( not unitNumber ) then
			return;
		end
		
		if ( unitType == "spectateda" or unitType == "spectatedb" ) then
			if ( unitType == "spectateda" ) then
				unit = "spectatedpeta"..unitNumber;
			else
				unit = "spectatedpetb"..unitNumber;
			end

			NamePlate:UpdateAll();
		end
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
		NamePlate:Enable();
		wipe(reactionCache)
	end
end

local lastupdate = 0
function NamePlate:OnUpdate(elapsed)

	lastupdate = lastupdate + elapsed

	-- Check if there were new frames created:
	if ( self.numWorldFrameChildren < WorldFrame:GetNumChildren() ) then
		for _, frame in pairs({WorldFrame:GetChildren()}) do
			local frameName = frame:GetName();
			
			-- Check if frame is a nameplate:
			if ( frameName and string.find(frameName, "^NamePlate(%d+)$" ) ) then
				if ( not self.namePlates[frame] ) then
					self:SetBlizzPlateStructure(frame);
					self:CreateNamePlate(frame);
				end
			end
		end
		self.numWorldFrameChildren = WorldFrame:GetNumChildren();
	end

	if lastupdate > 0.1 then
		for _, frame in pairs({WorldFrame:GetChildren()}) do
			local frameName = frame:GetName();
			
			-- Check if frame is a nameplate:
			if ( frameName and string.find(frameName, "^NamePlate(%d+)$" ) ) then
				
				if ( self.namePlates[frame] ) then
					local namePlate = self.namePlates[frame]
					self:UpdateNamePlate(namePlate)
				end
			end
		end
		lastupdate = 0
	end

end
NamePlate:SetScript("OnUpdate", NamePlate.OnUpdate);

--[[
****************************************
******* CLASS METHODS START HERE *******
****************************************
]]--
function NamePlateClass:Enable()
	local blizzPlate = self:GetParent();
	NamePlate:HideBlizzardNamePlate(blizzPlate);
	
	self:Show();
	self.enabled = true;
	
	NamePlate:UpdateNamePlate(self);
end

function NamePlateClass:Disable()
	local blizzPlate = self:GetParent();
	NamePlate:ShowBlizzardNamePlate(blizzPlate);
	
	self:Hide();
	self.enabled = false;
	
	self:Reset();
end

function NamePlateClass:Update()
	if ( self.enabled ) then
		self:UpdateCastBar();
		-- hackfix, but what can you do?
		if (self.unit and self.CCIndicator.enabled) then
			CCIndicator:UpdateCache("UNIT_AURA", self.unit, true)
			CCIndicator:Update(self); -- manual update, so we don't spam update all other CCIndicators for this unit, like target etc
		else
			CCIndicator:Reset(self);
		end
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
	local isPlayer = false

	if (self.unit) then
		isPlayer = UnitIsPlayer(self.unit)
		if isPlayer then
			local _, class = UnitClass(self.unit)
			playerNameCache[UnitName(self.unit)] = {}
			playerNameCache[UnitName(self.unit)].class = class

			reactionCache[UnitName(self.unit)] = {}
			reactionCache[UnitName(self.unit)].reaction = UnitReaction(self.unit, "player")
			reactionCache[UnitName(self.unit)].color = UnitSelectionColor(self.unit)
		end	
	else
		isPlayer = playerNameCache[blizzPlate.nameText:GetText()] ~= nil
	end
	
	if ( isInPvP and isPlayer ) then

		self:SetSize(188, 52);
		if (self.unit and self.unit == "target") then
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
		self.HealthBar:SetPoint("TOPLEFT", self.classIcon, "TOPRIGHT", 0, 4);
		
		self.castBar:ClearAllPoints();
		self.castBar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 58, 16);
		local role = "FIXME" -- FIXME
		if ( role == "HEALER" ) then
			self.healerIcon:Show();
		else
			self.healerIcon:Hide();
		end
	else
		self:SetSize(137, 22);
		self.classIcon:Hide();
		
		self.border:SetTexture("Interface\\AddOns\\ArenaLiveNamePlates3\\Textures\\NamePlateBorder");
		self.border:SetTexCoord(0.28125, 0.81640625, 0.2421875, 0.5859375);

		self.HealthBar:ClearAllPoints();
		self.HealthBar:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -5);
		
		self.castBar:ClearAllPoints();
		self.castBar:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 5, 0);
		
		self.healerIcon:Hide();
	end
	
	-- Set border colour:
	local red, green, blue;

	if ( isInPvP ) then
		-- border red/green for teams
		if ( self.unit ) then
			red, green, blue = UnitSelectionColor(self.unit);
		elseif ( reactionCache[blizzPlate.nameText:GetText()] ~= nil ) then
			red, green, blue = reactionCache[blizzPlate.nameText:GetText()].color
		end
	elseif (not isInPvP and isPlayer) then
		if ( self.unit) then
			local _, class = UnitClass(self.unit)
			if ( RAID_CLASS_COLORS[class] ) then
				red, green, blue = RAID_CLASS_COLORS[class].r, RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b
			else
				red, green, blue = blizzPlate.healthBar:GetStatusBarColor();	
			end
			red, green, blue = RAID_CLASS_COLORS[class].r, RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b
		elseif ( playerNameCache[blizzPlate.nameText:GetText()] ~= nil ) then
			local class = playerNameCache[blizzPlate.nameText:GetText()].class
			if ( RAID_CLASS_COLORS[class] ) then
				red, green, blue = RAID_CLASS_COLORS[class].r, RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b
			else
				red, green, blue = blizzPlate.healthBar:GetStatusBarColor();	
			end
		end
	else
		red, green, blue = blizzPlate.healthBar:GetStatusBarColor();	
	end	


	self.border:SetVertexColor(red, green, blue);
end

function NamePlateClass:UpdateCastBar()
	local blizzPlate = self:GetParent();
	if ( blizzPlate.castBar:IsShown() ) then
		if ( not self.castBar:IsShown() ) then
			self.castBar:Show();
		end
		
		local minValue, maxValue = blizzPlate.castBar:GetMinMaxValues();
		local value = blizzPlate.castBar:GetValue();
		local texture = blizzPlate.castBar.icon:GetTexture();
		local spellName = blizzPlate.castBar.text:GetText();
		
		-- Prevent Division by zero:
		if ( maxValue == 0 ) then
			maxValue = 1;
		end		
		
		local red, green, blue = 1, 0.7, 0;
		if ( blizzPlate.castBar.shield:IsShown() ) then
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
	local blizzPlate = self:GetParent();
	local inInstance, gameType = IsInInstance()
	local isInPvP = gameType == "pvp" or gameType == "arena"
	local isPlayer = UnitIsPlayer(self.unit) or playerNameCache[blizzPlate.nameText:GetText()]

	if ( self.unit and isInPvP and isPlayer ) then
		local _, class = UnitClass(self.unit);
		self.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]));
		self.classIcon:Show();
	elseif (not self.unit and isInPvP and isPlayer) then
		self.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[playerNameCache[blizzPlate.nameText:GetText()].class]));
		self.classIcon:Show();
	else
		self.classIcon:Hide();
	end
end

function NamePlateClass:UpdateHealthBar()
	local blizzPlate = self:GetParent();
	local isInPvP = gameType == "pvp" or gameType == "arena"
	local isPlayer = not self.unit and playerNameCache[blizzPlate.nameText:GetText()] ~= nil
	
	-- Set class color if possible:
	local red, green, blue = blizzPlate.healthBar:GetStatusBarColor();
	if ( self.unit ) then
		HealthBar:Update(self);
		return
	
	-- overwrite statusbar functionality (which automatically sets class color) with our own, if no unit is available outside PvP
	elseif (isPlayer) then
		local class = playerNameCache[blizzPlate.nameText:GetText()].class
		if (RAID_CLASS_COLORS[class]) then
			self.HealthBar:SetStatusBarColor(RAID_CLASS_COLORS[class].r, RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b);
		else
			self.HealthBar:SetStatusBarColor(red, green, blue);	
		end

		local minValue, maxValue = blizzPlate.healthBar:GetMinMaxValues();
		local value = blizzPlate.healthBar:GetValue();
		
		-- Prevent Division by zero:
		if ( maxValue == 0 ) then
			maxValue = 1;
		end

		-- no reset of statusbar color
		self.HealthBar:SetMinMaxValues(minValue, maxValue);
		self.HealthBar:SetValue(value);
	else
		local minValue, maxValue = blizzPlate.healthBar:GetMinMaxValues();
		local value = blizzPlate.healthBar:GetValue();
		
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
	local name;
	if ( self.unit ) then
		name = NameText:GetNickname(self.unit) or UnitName(self.unit) or blizzPlate.nameText:GetText();
	else
		name = blizzPlate.nameText:GetText();
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
end

function NamePlateClass:OnShow()
	if ( self.enabled ) then
		NamePlate:UpdateNamePlate(self);
	end
end