PandaWoWCommandLib = commandLib
assert(PandaWoWCommandLib)

Transmogrication = {};

local customEnabled = nil;

local _G = _G
local GetContainerNumSlots, GetContainerItemID, GetContainerItemLink, GetItemInfo, strsub, gsub, strfind = 
      _G.GetContainerNumSlots, _G.GetContainerItemID, _G.GetContainerItemLink, _G.GetItemInfo, _G.strsub, _G.gsub, _G.strfind
local bor, lshift = _G.bit.bor, _G.bit.lshift;
local NUM_BAG_SLOTS, BACKPACK_CONTAINER, BANK_CONTAINER = _G.NUM_BAG_SLOTS, _G.BACKPACK_CONTAINER, _G.BANK_CONTAINER;

-- empty dummies
local VOID_CONTAINER, PLAYER_CONTAINER = 12, 13
local ITEM_QUALITY_LEGENDARY = _G.ITEM_QUALITY_LEGENDARY;

local alert = GetLocale() == "ruRU" and "Внимание! Ваши файлы интерфейса трансмогрификации устарели!\nОбновите файлы запустив лаунчер" or "Warning! Your transmogrify interface files are outdated!\nUpdate files by running launcher"

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")

local itemTypes, L, typesSize, LtypesSize = {
	CLOTH    = 47,
	LEATHER  = 60,
	MAIL     = 285,
	PLATE    = 7922,
	ONEHAXE  = 7941,
	ONEHMACE = 7945,
	ONEHSWORD= 7943,
	DAGGER   = 7947,
	POLEARM  = 25228,
	BOW      = 25240,
	GUN      = 4379,
	STAFF    = 35,
	CROSSBOW = 25254,
	WAND     = 25282,
	TWOHAXE  = 7958,
	TWOHMACE = 7956,
	TWOHSWORD= 7957,
	SHIELD   = 3160,
	FIST     = 29348,
	COSMETIC = 105741,
	QUEST    = 22549,

	ARMOR    = 1270,
	MISC	 = 105602,
	FISHING  = 6256
}, {}, 24, 0 -- WHEN ADDING VALUES BE SURE TO INCREASE THIS

local fail = true
local function queryItems()
	if not fail then return end
	for i, v in pairs(itemTypes) do
		local info = {GetItemInfo(v)}
		if #info > 0 then
			LtypesSize = LtypesSize + 1
			L[i] = i == "ARMOR" and info[6] or info[7]
		end
	end
	if typesSize == LtypesSize then
		f:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
		fail = nil
	end
end
queryItems()

local PWT_VERSION_INFO = 1.25;
local OLDVERSION = true;
RegisterAddonMessagePrefix"PWTVerInfo"

local function PandaWoW_PostVersionInfo(channel, target)
	SendAddonMessage("PWTVerInfo", PWT_VERSION_INFO, channel, target);
end

local function PandaWoW_HandleVersionInfo(msg, author, channel)
	local recNumber = tonumber(msg);
	if (recNumber > PWT_VERSION_INFO) then
        if OLDVERSION then
            local alertIcon = [[|TInterface\DialogFrame\UI-Dialog-Icon-AlertOther:24:24:0|t]]
            RaidNotice_AddMessage(RaidWarningFrame, alertIcon .. '\r\n' .. YELLOW_FONT_COLOR_CODE .. alert .. '\124r', ChatTypeInfo["RAID_WARNING"])
            DEFAULT_CHAT_FRAME:AddMessage(alertIcon .. YELLOW_FONT_COLOR_CODE .. alert .. '\124r' .. alertIcon)
            OLDVERSION = nil -- we already notified player so we need to stop spamming
        end
	elseif (recNumber < PWT_VERSION_INFO) then
		PandaWoW_PostVersionInfo("WHISPER", author);
	end
end

LoadAddOn("Blizzard_ItemAlterationUI")

TransmogrifyArtFrameTitleText:SetText(TRANSMOGRIFY .. " (v. " .. PWT_VERSION_INFO .. ")")
f:SetScript("OnEvent", function(self, event, ...)
	if event == "CHAT_MSG_ADDON" then
        local arg1, arg2, arg3, arg4 = ...
		if arg1 == "PWTVerInfo" then
			PandaWoW_HandleVersionInfo(arg2, arg4, arg3);
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if (IsInGuild()) then
			PandaWoW_PostVersionInfo"GUILD";
		end
	elseif event == "PLAYER_ENTERING_BATTLEGROUND" then
		PandaWoW_PostVersionInfo"INSTANCE_CHAT";
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		queryItems()
    end
end)

local equipLocation =
{
    INVTYPE_HEAD 		= 1,
    INVTYPE_SHOULDER	= 3,
    INVTYPE_BODY		= 4,
    INVTYPE_CHEST		= 5,
    INVTYPE_ROBE		= 5,
    INVTYPE_WAIST		= 6,
    INVTYPE_LEGS		= 7,
    INVTYPE_FEET		= 8,
    INVTYPE_WRIST		= 9,
    INVTYPE_HAND		= 10,
    INVTYPE_CLOAK       = 15,

    INVTYPE_WEAPON      = 16,
    INVTYPE_WEAPONMAINHAND = 16,
    INVTYPE_2HWEAPON    = 16,

    INVTYPE_WEAPONOFFHAND = 17,
    INVTYPE_HOLDABLE    = 17,
    INVTYPE_SHIELD      = 17,
    INVTYPE_RANGED		= 18,
    INVTYPE_RANGEDRIGHT = 18,
};

-- location offsets
local ITEM_INVENTORY_BAG_BIT_OFFSET   = ITEM_INVENTORY_BAG_BIT_OFFSET;
local ITEM_INVENTORY_LOCATION_BAGS    = ITEM_INVENTORY_LOCATION_BAGS;
local ITEM_INVENTORY_LOCATION_BANK    = ITEM_INVENTORY_LOCATION_BANK;
local ITEM_INVENTORY_LOCATION_PLAYER  = ITEM_INVENTORY_LOCATION_PLAYER;
local ITEM_INVENTORY_LOCATION_VOIDSTORAGE   = ITEM_INVENTORY_LOCATION_VOIDSTORAGE;

local function PackInventoryLocation(container, slot, equipment, bank, bags, voidStorage)
	local location = 0
	-- basic flags
    location = bor(location, equipment      and ITEM_INVENTORY_LOCATION_PLAYER or 0);
    location = bor(location, bags           and ITEM_INVENTORY_LOCATION_BAGS or 0);
	location = bor(location, bank           and ITEM_INVENTORY_LOCATION_BANK or 0);
	location = bor(location, voidStorage    and ITEM_INVENTORY_LOCATION_VOIDSTORAGE or 0);

	-- container (tab, bag, ...) and slot
	location = location + (slot or 1)

    if bank and bags and container > NUM_BAG_SLOTS then
		-- store bank bags as 1-7 instead of 5-11
		container = container - ITEM_INVENTORY_BANK_BAG_OFFSET;
	end

    if container and container > 0 then
		location = location + lshift(container, ITEM_INVENTORY_BAG_BIT_OFFSET)
	end

    -- TODO: FIX BANK!!
    if bank and not bags and not voidStorage then
        location = location + 39;
    end

	return location;
end

local function noTransmog(mic, misc, ic, isc, mies, ies, id)
	if id == 3934 and not Is64BitClient() then return true end
	if customEnabled then
		-- Hide weapons that not allowed to tmog
		if Is64BitClient() and id == 3934 then
			if misc == L.ONEHSWORD or misc == L.ONEHAXE or misc == L.ONEHMACE or misc == L.TWOHSWORD or misc == L.TWOHAXE or misc == L.TWOHMACE or misc == L.POLEARM or misc == L.STAFF then-- working only on x64 client :(
				return false
			else
				return true
			end
		-- polearms/staves -> staves/polearms/2h
		elseif (misc == L.POLEARM or misc == L.STAFF) and isc ~= L.STAFF and isc ~= L.POLEARM and isc ~= L.TWOHSWORD and isc ~= L.TWOHAXE and isc ~= L.TWOHMACE then
			return true
		-- daggers/fists -> 1h
		elseif (misc == L.DAGGER or misc == L.FIST) and isc ~= L.ONEHSWORD and isc ~= L.ONEHAXE and isc ~= L.ONEHMACE and isc ~= L.DAGGER and isc ~= L.FIST then
			return true
		-- 2h NOT ALLOWED TO daggers/fists
		elseif (misc == L.TWOHSWORD or misc == L.TWOHAXE or misc == L.TWOHMACE) and (isc == L.DAGGER or isc == L.FIST) then
			return true
		-- 1h/2h > 1h/2h
		elseif ((isc == L.STAFF or isc == L.POLEARM) and (misc == L.ONEHSWORD or misc == L.ONEHAXE or misc == L.ONEHMACE)) or (misc == L.ONEHSWORD or misc == L.ONEHAXE or misc == L.ONEHMACE or misc == L.TWOHSWORD or misc == L.TWOHAXE or misc == L.TWOHMACE)
		  and (isc ~= L.TWOHSWORD and isc ~= L.TWOHAXE and isc ~= L.TWOHMACE
		  and isc ~= L.ONEHSWORD and isc ~= L.ONEHAXE and isc ~= L.ONEHMACE
		  and isc ~= L.DAGGER and isc ~= L.FIST and isc ~= L.STAFF and isc ~= L.POLEARM) then
			return true
		-- Hide wands from bows/crossbows/guns slot and vice versa
		elseif (misc == L.GUN or misc == L.BOW or misc == L.CROSSBOW) and isc ~= L.GUN and isc ~= L.BOW and isc ~= L.CROSSBOW then
			return true
		else
			return false
		end
	else -- not premium
		if isc == L.FISHING then
			return true
		elseif (misc == L.PLATE or misc == L.MAIL or misc == L.LEATHER or misc == L.CLOTH) and isc ~= misc and isc ~= L.COSMETIC then
			return true
		elseif (misc == L.DAGGER or misc == L.SHIELD) and isc ~= misc then
			return true
		elseif (isc == L.POLEARM or isc == L.STAFF) and isc ~= misc and misc ~= L.STAFF and misc ~= L.POLEARM then
			return true
		elseif (misc == L.POLEARM or misc == L.STAFF) and misc ~= isc and isc ~= l.STAFF and isc ~= L.POLEARM then
		    return true
		elseif misc == L.FIST and isc ~= misc then
			return true
		elseif (misc == L.ONEHSWORD or misc == L.ONEHAXE or misc == L.ONEHMACE) and (isc == L.TWOHMACE or isc == L.TWOHAXE or isc == L.TWOHSWORD or isc == L.DAGGER or isc == L.FIST or isc == L.WAND) then
			return true
		elseif (misc == L.GUN or misc == L.BOW or misc == L.CROSSBOW) and isc ~= L.GUN and isc ~= L.BOW and isc ~= L.CROSSBOW then
			return true
		elseif (misc ~= L.GUN and misc ~= L.BOW and misc ~= L.CROSSBOW) and (isc == L.GUN or isc == L.BOW or isc == L.CROSSBOW) then
			return true
		elseif misc ~= L.WAND and isc == WAND then
			return true
		else
			return false
		end
	end
end

local function AddEquippableItem(useTable, mies, inventorySlot, container, slot)
    local itemID, link, _
    if container == VOID_CONTAINER then
        _, link = GetItemInfo(GetVoidItemInfo(slot))
        itemID = tonumber(string.match(link,"item:([%-?%d]+)")) -- extract ID from link
    elseif container == PLAYER_CONTAINER then
        itemID = GetInventoryItemID("player", slot)
        link   = GetInventoryItemLink("player", slot)
    else
        itemID = GetContainerItemID(container, slot)
        link   = GetContainerItemLink(container, slot)
    end

    if not link then return end

	local isBags   = container >= BACKPACK_CONTAINER and container <= NUM_BAG_SLOTS + _G.NUM_BANKBAGSLOTS
	local isBank   = container == BANK_CONTAINER or (isBags and container > NUM_BAG_SLOTS)
    local isVoid   = container == VOID_CONTAINER
	local isPlayer = not isBank and not isVoid
	if not isBags then container = nil end

	local _, _, _, _, _, _, itemSubClass, _, equipSlot = GetItemInfo(link)
    if itemSubClass == L.QUEST then return end

	local location = PackInventoryLocation(container, slot, isPlayer, isBank, isBags, isVoid);

    if not customEnabled and equipSlot ~= mies then
        if itemSubClass == L.GUN or itemSubClass == L.BOW or itemSubClass == L.CROSSBOW or itemSubClass == L.WAND then -- ranged fix
            if equipLocation[mies] == 17 then useTable[location] = nil return end
        elseif (inventorySlot == 17 or inventorySlot == 16) and itemID ~= 3934 then -- offhand fix
            useTable[location] = nil
            return
        end
    end

    if ((equipLocation[equipSlot] == inventorySlot or equipLocation[equipSlot] == 16 or equipLocation[equipSlot] == 18) or 
	(equipLocation[equipSlot] == 17 and inventorySlot == 16)) and useTable[location] == nil then
        useTable[location] = itemID;
	end
end

local EquipmentFlyout_UpdateFlyout_orig = EquipmentFlyout_UpdateFlyout
hooksecurefunc('GetInventoryItemsForSlot', function(inventorySlot, useTable, transmog)
    if transmog == nil then return end
    EquipmentFlyout_UpdateFlyout = function()end
    local invItemId = GetInventoryItemID("player", inventorySlot)
    if not invItemId then return end

    local _, _, _, _, _, mainItemClass, mainItemSubClass, _, mies = GetItemInfo(invItemId);

    if mainItemSubClass == nil then return end

    for container = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(container) do
            AddEquippableItem(useTable, mies, inventorySlot, container, slot)
        end
    end

    --print(PackInventoryLocation(BANK_CONTAINER, 2, nil, true, nil));

    -- scan bank main frame (data is only available when bank is opened)
    for slot = 1, _G.NUM_BANKGENERIC_SLOTS do
        AddEquippableItem(useTable, mies, inventorySlot, BANK_CONTAINER, slot)
    end

    -- scan bank containers
    for bankContainer = 1, _G.NUM_BANKBAGSLOTS do
        local container = _G.ITEM_INVENTORY_BANK_BAG_OFFSET + bankContainer
        for slot = 1, GetContainerNumSlots(container) or 0 do
            AddEquippableItem(useTable, mies, inventorySlot, container, slot)
        end
    end

    -- scan void
    for voidSlot = 1, 80 do -- VOID_STORAGE_MAX
        if GetVoidItemInfo(voidSlot) then
            AddEquippableItem(useTable, mies, inventorySlot, VOID_CONTAINER, voidSlot)
        end
    end
    
    -- scan equipped (for both weapon hands)
    AddEquippableItem(useTable, mies, inventorySlot, PLAYER_CONTAINER, 16)
    AddEquippableItem(useTable, mies, inventorySlot, PLAYER_CONTAINER, 17)

    if not customEnabled then
        local localizedClass, class = UnitClass"player"
        localizedClass = LOCALIZED_CLASS_NAMES_MALE[class]
        for location, itemId in pairs(useTable) do
            if itemId == invItemId then useTable[location] = nil; end
            local _, link, itemRarity, _, _, itemClass, itemSubClass, _, equipSlot = GetItemInfo(itemId);

            -- We need to check tooltip of items to tmog if we are able to wear
            --i.e it will hide armor from another classes but will show weapons that are unable to wear
            GameTooltip:SetOwner(UIParent,'ANCHOR_NONE')
            GameTooltip:SetHyperlink(link)
            local pattern = gsub(ITEM_CLASSES_ALLOWED, "%%s", "(.+)")
            for i = GameTooltip:NumLines(), 1, -1 do
                local tooltipText = _G['GameTooltipTextLeft' .. i]:GetText()
                local _, _, classes = strfind(tooltipText, pattern)
                if classes then
                    local c, c1, c2, c3, c4, c5, c6, c7 = 0, "", "", "", "", "", "", ""
                    for j = 1, #classes do
                        local chr = strsub(classes, j, j+1)
                        if chr~=", " then
                            chr = strsub(classes, j, j)
                            if c==0 then c1=c1 .. chr
                            elseif c==1 then c2=c2 .. chr
                            elseif c==2 then c3=c3 .. chr
                            elseif c==3 then c4=c4 .. chr
                            elseif c==4 then c5=c5 .. chr
                            elseif c==5 then c6=c6 .. chr
                            elseif c==6 then c7=c7 .. chr
                            end
                        else c=c+1 end
                    end
                    classes = {c1, c2, c3, c4, c5, c6, c7}
                    for j, k in pairs(classes) do
                        k = gsub(k,'^ ?(.*)','%1')
                        if k == localizedClass then break end
                        if j == #classes then useTable[location] = nil; end
                    end
                end
            end
            GameTooltip:Hide()

            -- Hide lower armor type items and legendary items
			if itemRarity == ITEM_QUALITY_LEGENDARY or noTransmog(mainItemClass, mainItemSubClass, itemClass, itemSubClass, mies, equipSlot, itemId) then
				useTable[location] = nil
			end
        end
    else
        for location, itemId in pairs(useTable) do
            if itemId == invItemId then useTable[location] = nil; end
            local _, _, _, _, _, itemClass, itemSubClass, _, equipSlot = GetItemInfo(itemId);

            -- Allow robes trans into chests and vice versa
            if mies == "INVTYPE_ROBE" and equipSlot == "INVTYPE_CHEST" then
                equipSlot = "INVTYPE_ROBE"
            elseif mies == "INVTYPE_CHEST" and equipSlot == "INVTYPE_ROBE" then
                equipSlot = "INVTYPE_CHEST"
            -- Allow bows trans into crossbows/guns and vice versa
            elseif mies == "INVTYPE_RANGED" and equipSlot == "INVTYPE_RANGEDRIGHT" then
                equipSlot = "INVTYPE_RANGED"
            elseif mies == "INVTYPE_RANGEDRIGHT" and equipSlot == "INVTYPE_RANGED" then
                equipSlot = "INVTYPE_RANGEDRIGHT"
            -- Allow 1H -> 2H
            elseif mies == "INVTYPE_WEAPON" and equipSlot == "INVTYPE_2HWEAPON" then
                equipSlot = "INVTYPE_WEAPON"
            elseif mies == "INVTYPE_2HWEAPON" and equipSlot == "INVTYPE_WEAPON" then
                equipSlot = "INVTYPE_2HWEAPON"
            -- Allow offhands trans into shields and vice versa
            elseif mies == "INVTYPE_HOLDABLE" and equipSlot == "INVTYPE_SHIELD" then
                equipSlot = "INVTYPE_HOLDABLE"
            elseif mies == "INVTYPE_SHIELD" and equipSlot == "INVTYPE_HOLDABLE" then
                equipSlot = "INVTYPE_SHIELD"
            end
            -- Allow main hands trans into one hands and vice versa
            if Is64BitClient() then -- working only on x64 client :(
                if mies == "INVTYPE_2HWEAPON" and itemId == 3934 then
                    equipSlot = "INVTYPE_2HWEAPON"
                elseif mies == "INVTYPE_WEAPON" and equipSlot == "INVTYPE_WEAPONMAINHAND" then
                    equipSlot = "INVTYPE_WEAPON"
                elseif mies == "INVTYPE_WEAPONMAINHAND" and equipSlot == "INVTYPE_WEAPON" then
                    equipSlot = "INVTYPE_WEAPONMAINHAND"
                elseif mies == "INVTYPE_WEAPON" and equipSlot == "INVTYPE_WEAPONOFFHAND" then
                    equipSlot = "INVTYPE_WEAPON"
                elseif mies == "INVTYPE_WEAPONOFFHAND" and equipSlot == "INVTYPE_WEAPON" then
                    equipSlot = "INVTYPE_WEAPONOFFHAND"
                end
            end

			if noTransmog(mainItemClass, mainItemSubClass, itemClass, itemSubClass, mies, equipSlot, itemId) then
				useTable[location] = nil
			end

            if (itemSubClass == L.QUEST) or mies ~= equipSlot and itemId ~= 3934 then
                useTable[location] = nil;
            end
        end
    end

    -- clean from incorrect slots (x64 client)
    if Is64BitClient() then
        for location, itemId in pairs(useTable) do
            local _, _, _, _, _, _, itemSubClass, _, itemSlot = GetItemInfo(itemId);
            if equipLocation[itemSlot] ~= inventorySlot and inventorySlot == 17 then
                if itemSubClass == L.GUN or itemSubClass == L.BOW or itemSubClass == L.CROSSBOW or itemSubClass == L.WAND then
                    useTable[location] = nil
                end
            elseif equipLocation[mies] == 16 and (itemSubClass == L.GUN or itemSubClass == L.BOW or itemSubClass == L.CROSSBOW) then useTable[location] = nil
            elseif equipLocation[itemSlot] == 17 and inventorySlot == 16 then
            elseif equipLocation[itemSlot] ~= inventorySlot and (itemSubClass ~= L.GUN and itemSubClass ~= L.BOW and itemSubClass ~= L.CROSSBOW and itemSubClass ~= L.WAND and itemId ~= 3934) then useTable[location] = nil
            end
        end
    end

    -- clean from duplicates
    local hash = {}
    for location, itemId in pairs(useTable) do
        if not hash[itemId] then
            hash[itemId] = true
        else useTable[location] = nil
        end
    end
end)

hooksecurefunc(EquipmentFlyoutFrame,'Show', function(self)
    if self.button and self.button:GetParent().flyoutSettings.parent == TransmogrifyFrame then return end
    EquipmentFlyout_UpdateFlyout = EquipmentFlyout_UpdateFlyout_orig
end)

hooksecurefunc(EquipmentFlyoutFrame,'Hide', function(self)
    EquipmentFlyout_UpdateFlyout = EquipmentFlyout_UpdateFlyout_orig
end)

function Transmogrication.LoadInfo()
    PandaWoWCommandLib:DoCommand("checktransmog", function(s, o)if o[1] == "enabled" then customEnabled = true; end end);
end