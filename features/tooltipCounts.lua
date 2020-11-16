--[[
	tooltipCounts.lua
		Adds item counts to tooltips
]]--

local ADDON, Addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(ADDON)
local TooltipCounts = Addon:NewModule('TooltipCounts')

local SILVER = '|cffc7c7cf%s|r'
local TOTAL = SILVER:format(L.Total)

local initialized = false

--[[ Adding Text ]]--

local function FormatCounts(color, ...)
	local total, places = 0, 0
	local text = ''

	for i = 1, select('#', ...), 2 do
		local title, count = select(i, ...)
		if count > 0 then
			text = text .. L.TipDelimiter .. title:format(count)
			total = total + count
			places = places + 1
		end
	end

	text = text:sub(#L.TipDelimiter + 1)
	if places > 1 then
		text = color:format(total) .. ' ' .. SILVER:format('('.. text .. ')')
	else
		text = color:format(text)
	end

	return total, total > 0 and text
end

local function getPlayerCounts (ownerInfo, itemID)
	local realm = ownerInfo.realm
	local name = ownerInfo.name
	local equip = Addon:GetPlayerItemCount(realm, name, 'equip', itemID)
	local vault = Addon:GetPlayerItemCount(realm, name, 'vault', itemID)
	local reagents = Addon:GetPlayerItemCount(realm, name, 'reagents', itemID)
	local bagSlots = Addon:GetPlayerItemCount(realm, name, 'bagslots', itemID)
	local bankBagSlots = Addon:GetPlayerItemCount(realm, name, 'bankbagslots', itemID)
	local bags, bank

	if ownerInfo.cached then
		bags = Addon:GetPlayerItemCount(realm, name, 'bags', itemID)
		bank = Addon:GetPlayerItemCount(realm, name, 'bank', itemID)
	else
		local total = GetItemCount(itemID, true, false)

		bags = GetItemCount(itemID, false, false)

		bank = total - bags - reagents - bankBagSlots
		bags = bags - equip - bagSlots
	end

	return {
		bags = bags,
		bank = bank,
		reagents = reagents,
		equip = equip,
		vault = vault,
		bagSlots = bagSlots,
		bankBagSlots = bankBagSlots,
	}
end

local function createPlayerText (ownerInfo, itemID)
	local color = Addon.Owners:GetColorString(ownerInfo)
	local counts = getPlayerCounts(ownerInfo, itemID)
	local count, text

	if rawget(L, 'TipCountReagents') then
		count, text = FormatCounts(color,
				L.TipCountEquip, counts.equip,
				L.TipCountBags, counts.bags + counts.bagSlots,
				L.TipCountBank, counts.bank + counts.bankBagSlots,
				L.TipCountVault, counts.vault,
				L.TipCountReagents, counts.reagents)
	else
		count, text = FormatCounts(color,
				L.TipCountEquip, counts.equip,
				L.TipCountBags, counts.bags + counts.bagSlots,
				L.TipCountBank, counts.bank + counts.bankBagSlots + counts.reagents,
				L.TipCountVault, counts.vault)
	end

	return count, text, color
end

local function createGuildText (ownerInfo, itemID)
	local color = Addon.Owners:GetColorString(ownerInfo)
	local count = Addon:GetGuildItemCount(ownerInfo.realm, ownerInfo.name, itemID)
	local text

	count, text = FormatCounts(color, L.TipCountGuild, count)

	return count, text, color
end

local function addOwnerText (tooltip, owner, itemID)
	local ownerInfo = Addon:GetOwnerInfo(owner)
	local count, text, color

	if ownerInfo.isguild then
		if Addon.sets.countGuild then
			count, text, color = createGuildText(ownerInfo, itemID)
		else
			count = 0
		end
	else
		count, text, color = createPlayerText(ownerInfo, itemID)
	end

	if count > 0 then
		tooltip:AddDoubleLine(Addon.Owners:GetIconString(ownerInfo, 12, 0, 0) .. ' ' .. color:format(ownerInfo.name), text)
	end

	return count
end

local function AddOwners(tooltip, link)
	if not Addon.sets.tipCount or tooltip.__tamedCounts then
		return
	end

	local itemID = tonumber(link and GetItemInfo(link) and link:match('item:(%d+)')) -- Blizzard doing craziness when doing GetItemInfo

	if not itemID or itemID == HEARTHSTONE_ITEM_ID then
		return
	end

	local players = 0
	local total = 0

	for owner in Addon:IterateOwners() do
		local count = addOwnerText(tooltip, owner, itemID)

		if (count > 0) then
			players = players + 1
			total = total + count
		end
	end

	if players > 1 then
		tooltip:AddDoubleLine(TOTAL, SILVER:format(total))
	end

	tooltip.__tamedCounts = true
	tooltip:Show()
end


--[[ Hooking ]]--

local function OnItem(tooltip)
	local name, link = tooltip:GetItem()
	if name ~= '' then
		AddOwners(tooltip, link)
	end
end

local function OnTradeSkill(tooltip, recipe, reagent)
	AddOwners(tooltip, tonumber(reagent) and C_TradeSkillUI.GetRecipeReagentItemLink(recipe, reagent) or C_TradeSkillUI.GetRecipeItemLink(recipe))
end

local function OnQuest(tooltip, type, quest)
	AddOwners(tooltip, GetQuestItemLink(type, quest))
end

local function OnClear(tooltip)
	tooltip.__tamedCounts = false
end

local function HookTip(tooltip)
	tooltip:HookScript('OnTooltipCleared', OnClear)
	tooltip:HookScript('OnTooltipSetItem', OnItem)

	hooksecurefunc(tooltip, 'SetQuestItem', OnQuest)
	hooksecurefunc(tooltip, 'SetQuestLogItem', OnQuest)

	if C_TradeSkillUI then
		hooksecurefunc(tooltip, 'SetRecipeReagentItem', OnTradeSkill)
		hooksecurefunc(tooltip, 'SetRecipeResultItem', OnTradeSkill)
	end
end


--[[ Startup ]]--

function TooltipCounts:OnEnable()
	if Addon.sets.tipCount and not initialized then
		initialized = true
		HookTip(GameTooltip)
		HookTip(ItemRefTooltip)
	end
end
