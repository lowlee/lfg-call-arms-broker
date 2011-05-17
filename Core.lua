local LDB = LibStub("LibDataBroker-1.1")
local dataobj = LDB:NewDataObject("LFG Call To Arms")

local GROUP_TYPE_NONE = 1
local GROUP_TYPE_PARTY = 2
local GROUP_TYPE_RAID = 3

dataobj.type = "data source"
dataobj.icon = "Interface\\LFGFrame\\LFG-Eye"
dataobj.iconCoords = {0.023, 0.102, 0.043, 0.199}
dataobj.lfginfo = {}
dataobj.group_type = GROUP_TYPE_NONE

local function calculateTexture(role, size, offset)
	size = size or 16
	offset = offset or 0
	local SIZE = 64
	local x1, x2, y1, y2 = GetTexCoordsForRoleSmallCircle(role)
	x1 = x1 * SIZE
	x2 = x2 * SIZE
	y1 = y1 * SIZE
	y2 = y2 * SIZE
	return ("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:%d:%d:0:%d:%d:%d:%d:%d:%d:%d|t"):format(size, size, offset, SIZE, SIZE, x1, x2, y1, y2)
end
local TANK_TEXTURE = calculateTexture("TANK", 16, -2)
local HEAL_TEXTURE = calculateTexture("HEALER", 16, -2)
local DPS_TEXTURE = calculateTexture("DAMAGER", 16 , -2)

LibStub("AceEvent-3.0"):Embed(dataobj)
LibStub("AceTimer-3.0"):Embed(dataobj)

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
	table.wipe(self.lfginfo)
	self.group_type = currentGroupType()
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
		if hasTank then
			table.insert(textures, TANK_TEXTURE)
		end
		if hasHeal then
			table.insert(textures, HEAL_TEXTURE)
		end
		if hasDPS then
			table.insert(textures, DPS_TEXTURE)
		end
		if #textures > 0 then
			dataobj.text = " "..table.concat(textures, " ")
		else
			dataobj.text = " None"
		end
	elseif self.group_type == GROUP_TYPE_PARTY then
		dataobj.text = " In Party"
	else
		dataobj.text = " In Raid"
	end
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

function dataobj:OnTooltipShow()
	self:AddLine("LFG Call to Arms")
	local greyColor = { 0.6, 0.6, 0.6 }
	if dataobj.group_type == GROUP_TYPE_NONE then
		local TANK = calculateTexture("TANK", 12)
		local HEAL = calculateTexture("HEALER", 12)
		local DPS = calculateTexture("DAMAGER", 12)
		if #dataobj.lfginfo > 0 then
			for _,dungeonInfo in ipairs(dataobj.lfginfo) do
				self:AddLine(dungeonInfo.name, unpack(greyColor))
				if dungeonInfo.tank then
					self:AddLine("  " .. TANK .. " Tank")
				end
				if dungeonInfo.heal then
					self:AddLine("  " .. HEAL .. " Healer")
				end
				if dungeonInfo.dps then
					self:AddLine("  " .. DPS .. " DPS")
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

dataobj:RegisterEvent("LFG_LOCK_INFO_RECEIVED", "UpdateText")
dataobj:RegisterEvent("PARTY_MEMBERS_CHANGED", "GroupMakeupChanged")
dataobj:RegisterEvent("RAID_ROSTER_UPDATE", "GroupMakeupChanged")

dataobj:UpdateText()
dataobj:ScheduleRepeatingTimer(function() RequestLFDPlayerLockInfo() end, 60)
