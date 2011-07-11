local addonName = ...
local uiAddonName = "LFG Call To Arms"

local LDB = LibStub("LibDataBroker-1.1")
local dataobj = LDB:NewDataObject(uiAddonName, {
	type = "data source",
	text = " Loading",
	icon = "Interface\\Icons\\inv_misc_bag_34",
})
local LSM = LibStub("LibSharedMedia-3.0")
local LDBIcon = LibStub("LibDBIcon-1.0")

local GROUP_TYPE_NONE = 1
local GROUP_TYPE_PARTY = 2
local GROUP_TYPE_RAID = 3

dataobj.lfginfo = {}
dataobj.group_type = GROUP_TYPE_NONE

local minimapButton = nil
local function getMinimapButton()
	if not minimapButton then
		-- LibDBIcon-1.0 currently sets the button with the following name
		minimapButton = _G["LibDBIcon10_" .. uiAddonName]
		if not minimapButton then
			-- if that didn't work, try pulling it out of LibDBIcon directly
			minimapButton = LDBIcon.objects[uiAddonName]
			-- and make sure we actualy got a Button back
			if not (minimapButton and minimapButton.GetObjectType and minimapButton:GetObjectType() == "Button") then
				minimapButton = nil
			elseif not (minimapButton.icon and minimapButton.icon.GetObjectType and minimapButton.icon:GetObjectType() == "Texture") then
				-- also make sure it has a .icon property that is a texture
				minimapButton = nil
			end
		end
	end
	return minimapButton
end

local function calculateTexture(role, size, offset, tintRed, tintGreen, tintBlue)
	size = size or 16
	offset = offset or 0
	tintRed = tintRed or 255
	tintGreen = tintGreen or 255
	tintBlue = tintBlue or 255
	local SIZE = 64
	local x1, x2, y1, y2 = GetTexCoordsForRoleSmallCircle(role)
	x1 = x1 * SIZE
	x2 = x2 * SIZE
	y1 = y1 * SIZE
	y2 = y2 * SIZE
	return ("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:%d:%d:0:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d|t"):format(size, size, offset, SIZE, SIZE, x1, x2, y1, y2, tintRed, tintGreen, tintBlue)
end
local TANK_TEXTURE = calculateTexture("TANK", 16, -2)
local HEAL_TEXTURE = calculateTexture("HEALER", 16, -2)
local DPS_TEXTURE = calculateTexture("DAMAGER", 16 , -2)

LibStub("AceEvent-3.0"):Embed(dataobj)
LibStub("AceTimer-3.0"):Embed(dataobj)

local defaults = {
	profile = {
		soundKey = "None",
		playSoundWhenMuted = false,
		minimap = {
			hide = false
		},
	},
	char = {
		roles = {
			tank = true,
			healer = true,
			damager = true
		}
	}
}

dataobj:RegisterEvent("ADDON_LOADED", function (event, name)
	if name == addonName then
		dataobj:OnInitialize()
		dataobj:UnregisterEvent("ADDON_LOADED")
	end
end)

function dataobj:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("LFGCallToArmsBrokerDB", defaults, true)
	LDBIcon:Register(uiAddonName, self, self.db.profile.minimap)

	local AceConfig = LibStub("AceConfig-3.0")
	AceConfig:RegisterOptionsTable(uiAddonName, function () return self:AceConfig3Options() end)
	local interfaceFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(uiAddonName)
	interfaceFrame.default = function() self:SetDefaultOptions() end

	self:RegisterEvent("LFG_LOCK_INFO_RECEIVED", "UpdateText")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "GroupMakeupChanged")
	self:RegisterEvent("RAID_ROSTER_UPDATE", "GroupMakeupChanged")

	self:ScheduleRepeatingTimer(function() RequestLFDPlayerLockInfo() end, 60)
	RequestLFDPlayerLockInfo()
end

function dataobj:OnClick(b)
	if b == "LeftButton" then
		ToggleLFDParentFrame()
	elseif b == "RightButton" then
		InterfaceOptionsFrame_OpenToCategory(uiAddonName)
	end
end

local function isRandomDungeonDisplayable(id)
	local name, typeID, minLevel, maxLevel, _, _, _, expansionLevel = GetLFGDungeonInfo(id);
	local myLevel = UnitLevel("player");
	return myLevel >= minLevel and myLevel <= maxLevel and EXPANSION_LEVEL >= expansionLevel;
end

local function currentGroupType()
	if GetNumRaidMembers() >= 1 then
		return GROUP_TYPE_RAID
	elseif GetNumPartyMembers() > 0 then
		return GROUP_TYPE_PARTY
	else
		return GROUP_TYPE_NONE
	end
end

function dataobj:UpdateText()
	-- figure out what roles we were displaying before
	local oldRoles = self.lfginfo.roles or { tank = true, healer = true, damager = true }
	table.wipe(self.lfginfo)
	self.lfginfo.roles = {
		tank = false,
		healer = false,
		damager = false
	}
	self.group_type = currentGroupType()
	local hasValue = false
	if self.group_type == GROUP_TYPE_NONE then
		local hasTank, hasHeal, hasDPS
		for i=1, GetNumRandomDungeons() do
			local id, name = GetLFGRandomDungeonInfo(i)
			if isRandomDungeonDisplayable(id) then
				local dungeonInfo = {}
				for i=1, LFG_ROLE_NUM_SHORTAGE_TYPES do
					local eligible, forTank, forHealer, forDamage, itemCount, money, xp = GetLFGRoleShortageRewards(id, i);
					if eligible and (itemCount ~= 0 or money ~= 0 or xp ~= 0) then
						if forTank then
							hasTank = true
							dungeonInfo.tank = true
						end
						if forHealer then
							hasHeal = true
							dungeonInfo.heal = true
						end
						if forDamage then
							hasDPS = true
							dungeonInfo.dps = true
						end
					end
				end
				if next(dungeonInfo) then
					dungeonInfo.name = name
					table.insert(self.lfginfo, dungeonInfo)
				end
			end
		end
		local textures = {}
		local shouldPlaySound = false
		if hasTank and self.db.char.roles.tank then
			table.insert(textures, TANK_TEXTURE)
			if not oldRoles.tank then shouldPlaySound = true end
		end
		if hasHeal and self.db.char.roles.healer then
			table.insert(textures, HEAL_TEXTURE)
			if not oldRoles.healer then shouldPlaySound = true end
		end
		if hasDPS and self.db.char.roles.damager then
			table.insert(textures, DPS_TEXTURE)
			if not oldRoles.damager then shouldPlaySound = true end
		end
		if #textures > 0 then
			dataobj.text = " "..table.concat(textures, " ")
			hasValue = true
		else
			dataobj.text = " None"
		end
		self.lfginfo.roles.tank = hasTank
		self.lfginfo.roles.healer = hasHeal
		self.lfginfo.roles.damager = hasDPS
		if shouldPlaySound then
			local channel = "SFX"
			if self.db.profile.playSoundWhenMuted then channel = "Master" end
			PlaySoundFile(LSM:Fetch("sound", self.db.profile.soundKey), channel)
		end
	elseif self.group_type == GROUP_TYPE_PARTY then
		dataobj.text = " In Party"
	else
		dataobj.text = " In Raid"
	end
	local button = getMinimapButton()
	if button then SetDesaturation(button.icon, not hasValue) end
end

function dataobj:GroupMakeupChanged()
	local groupType = currentGroupType()
	if (groupType == GROUP_TYPE_NONE) ~= (self.group_type == GROUP_TYPE_NONE) then
		RequestLFDPlayerLockInfo();
	end
end

function dataobj:PARTY_MEMBERS_CHANGED()
	self:UpdateText()
end

local TANK_ICON = calculateTexture("TANK", 12)
local TANK_ICON_DISABLED = calculateTexture("TANK", 12, nil, 155, 155, 155)
local HEAL_ICON = calculateTexture("HEALER", 12)
local HEAL_ICON_DISABLED = calculateTexture("HEALER", 12, nil, 155, 155, 155)
local DPS_ICON = calculateTexture("DAMAGER", 12)
local DPS_ICON_DISABLED = calculateTexture("DAMAGER", 12, nil, 155, 155, 155)
function dataobj:OnTooltipShow()
	-- reminder: self is the tooltip
	self:AddLine("LFG Call to Arms")
	local greyColor = { 0.6, 0.6, 0.6 }
	if dataobj.group_type == GROUP_TYPE_NONE then
		if #dataobj.lfginfo > 0 then
			for _,dungeonInfo in ipairs(dataobj.lfginfo) do
				self:AddLine(dungeonInfo.name, unpack(greyColor))
				if dungeonInfo.tank then
					local icon = dataobj.db.char.roles.tank and TANK_ICON or TANK_ICON_DISABLED
					local tint = dataobj.db.char.roles.tank and {} or greyColor
					self:AddLine("  " .. icon .. " Tank", unpack(tint))
				end
				if dungeonInfo.heal then
					local icon = dataobj.db.char.roles.healer and HEAL_ICON or HEAL_ICON_DISABLED
					local tint = dataobj.db.char.roles.healer and {} or greyColor
					self:AddLine("  " .. icon .. " Healer", unpack(tint))
				end
				if dungeonInfo.dps then
					local icon = dataobj.db.char.roles.damager and DPS_ICON or DPS_ICON_DISABLED
					local tint = dataobj.db.char.roles.damager and {} or greyColor
					self:AddLine("  " .. icon .. " DPS", unpack(tint))
				end
			end
		else
			self:AddLine("No Call to Arms is available.", unpack(greyColor))
		end
	elseif dataobj.group_type == GROUP_TYPE_PARTY then
		self:AddLine("You are in a party.", unpack(greyColor))
	else
		self:AddLine("You are in a raid.", unpack(greyColor))
	end
end

function dataobj:SetShowsMinimap(bool)
	self.db.profile.minimap.hide = bool
	if bool then
		LDBIcon:Hide(uiAddonName)
	else
		LDBIcon:Show(uiAddonName)
		self:UpdateText() -- in case the minimap button needs desaturating
	end
end

local function copyDefaults(dest, source)
	for k,v in pairs(dest) do
		if type(v) == "table" then
			copyDefaults(v, source[k])
		else
			dest[k] = source[k]
		end
	end
end

function dataobj:SetDefaultOptions()
	self.db:ResetProfile()
	copyDefaults(self.db.char, defaults.char)
	LibStub("AceConfigRegistry-3.0"):NotifyChange(uiAddonName)
	LDBIcon:Refresh(uiAddonName, self.db.profile.minimap)
	self:UpdateText()
end

function dataobj:AceConfig3Options()
	--local rolesIcon = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
	local texSize = 20
	local canBeTank, canBeHealer, canBeDamager = UnitGetAvailableRoles("player")
	local greyTint = {155, 155, 155}
	return {
		name = uiAddonName,
		type = "group",
		get = function(info) return self.db.profile[info[#info]] end,
		set = function(info, val) self.db.profile[info[#info]] = val end,
		args = {
			roles = {
				name = "Roles",
				type = "group",
				inline = true,
				order = 1,
				get = function(info) return info.arg and self.db.char.roles[info[#info]] end,
				set = function(info, val)
					self.db.char.roles[info[#info]] = val
					self:UpdateText()
				end,
				args = {
					description = {
						name = "What roles are you interested in seeing?\n", -- newline for spacing reasons
						type = "description",
						order = 0
					},
					tank = {
						name = calculateTexture("TANK", texSize, nil, unpack(canBeTank and {} or greyTint)),
						type = "toggle",
						width = "half",
						order = 1,
						disabled = not canBeTank,
						arg = canBeTank
					},
					healer = {
						name = calculateTexture("HEALER", texSize, nil, unpack(canBeHealer and {} or greyTint)),
						type = "toggle",
						width = "half",
						order = 2,
						disabled = not canBeHealer,
						arg = canBeHealer
					},
					damager = {
						name = calculateTexture("DAMAGER", texSize, nil, unpack(canBeDamager and {} or greyTint)),
						type = "toggle",
						width = "half",
						order = 3,
						disabled = not canBeDamager,
						arg = canBeDamager
					}
				}
			},
			sound = {
				name = "Sound",
				type = "group",
				inline = true,
				order = 2,
				args = {
					soundDesc = {
						name = "Play a sound when the available roles change:",
						type = "description",
						order = 1,
					},
					soundKey = {
						name = "Sound",
						desc = "Sound to play when the available roles change",
						type = "select",
						order = 2,
						dialogControl = "LSM30_Sound",
						values = LSM:HashTable("sound"),
					},
					playSoundWhenMuted = {
						name = "Play sound when muted",
						desc = "Play sound even when sound effects are turned off",
						type = "toggle",
						order = 3,
					},
				},
			},
			showMinimap = {
				name = "Show Minimap Icon",
				type = "toggle",
				order = 5,
				get = function(info) return not self.db.profile.minimap.hide end,
				set = function(info, val) self:SetShowsMinimap(not val) end
			},
		}
	}
end
