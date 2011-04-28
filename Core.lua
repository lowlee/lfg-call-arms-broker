local LDB = LibStub("LibDataBroker-1.1")
local dataobj = LDB:NewDataObject("LFG Call To Arms")

dataobj.type = "data source"
dataobj.icon = "Interface\\AddOns\\LFGCallToArmsBroker\\Eye"
dataobj.lfginfo = {}

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

function dataobj:LFG_LOCK_INFO_RECEIVED()
	self:UpdateText()
end

dataobj:RegisterEvent("LFG_LOCK_INFO_RECEIVED")

local function isRandomDungeonDisplayable(id)
	local name, typeID, minLevel, maxLevel, _, _, _, expansionLevel = GetLFGDungeonInfo(id);
	local myLevel = UnitLevel("player");
	return myLevel >= minLevel and myLevel <= maxLevel and EXPANSION_LEVEL >= expansionLevel;
end

function dataobj:UpdateText()
	table.wipe(self.lfginfo)
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
end

function dataobj:OnTooltipShow()
	local TANK = calculateTexture("TANK", 12)
	local HEAL = calculateTexture("HEALER", 12)
	local DPS = calculateTexture("DAMAGER", 12)
	if #dataobj.lfginfo > 0 then
		for _,dungeonInfo in ipairs(dataobj.lfginfo) do
			self:AddLine(dungeonInfo.name, 0.6, 0.6, 0.6)
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
		self:AddLine("No Call to Arms is available.")
	end
end

dataobj:UpdateText()
dataobj:ScheduleRepeatingTimer(function() RequestLFDPlayerLockInfo() end, 60)
