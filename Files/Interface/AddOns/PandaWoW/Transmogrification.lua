local addonName, addonDB = ...

PandaWoWCommandLib = commandLib
assert(PandaWoWCommandLib)

Transmogrication = {};

local customEnabled = nil;

local _G = _G
local GetContainerNumSlots, GetContainerItemID, GetContainerItemLink, GetItemInfo, GetSpellInfo, strsub, gsub, strfind = 
      GetContainerNumSlots, GetContainerItemID, GetContainerItemLink, GetItemInfo, GetSpellInfo, string.sub, string.gsub, string.find
local bor, lshift = bit.bor, bit.lshift;
local NUM_BAG_SLOTS, BACKPACK_CONTAINER, BANK_CONTAINER = _G.NUM_BAG_SLOTS, _G.BACKPACK_CONTAINER, _G.BANK_CONTAINER;

-- empty dummies
local VOID_CONTAINER, PLAYER_CONTAINER = 12, 13

-- en locale: "Quests","Quest", ru locale: "Задание","Задания" :\
local QUESTS_LABEL, BATTLE_PET_SOURCE_2 = _G.QUESTS_LABEL, _G.BATTLE_PET_SOURCE_2

local ITEM_QUALITY_LEGENDARY = _G.ITEM_QUALITY_LEGENDARY;

--[[local itemTypes = {
    oneHaxes    = 196,  twoHaxes    = 197,
    oneHmaces   = 198,  twoHmaces   = 199,
    polearms    = 200,  staves      = 227,
    oneHswords  = 201,  twoHswords  = 202,
    daggers     = 1180, fists       = 15590,
    bows        = 264,  crossbows   = 5011,
    guns        = 266,  wands       = 5009}]]
local cloth, leather, mail, plate
local oneHaxes, twoHaxes, polearms, staves, oneHmaces, twoHmaces, oneHswords, twoHswords, daggers, fists, shields, bows, crossbows, guns =
GetSpellInfo(196), GetSpellInfo(197), GetSpellInfo(200), GetSpellInfo(227), GetSpellInfo(198), GetSpellInfo(199), 
GetSpellInfo(201), GetSpellInfo(202), GetSpellInfo(1180), GetSpellInfo(15590), GetSpellInfo(9116), GetSpellInfo(264), GetSpellInfo(5011), GetSpellInfo(266)
local alert
if GetLocale() == "ruRU" then
    polearms = "Древковое"; oneHmaces = "Одноручное дробящее"; twoHmaces = "Двуручное дробящее"
    cloth = "Тканевые"; leather = "Кожаные"; mail = "Кольчужные"; plate = "Латные"; fists = "Кистевое"
    guns = "Огнестрельное"

    alert = "Внимание! Ваши файлы интерфейса трансмогрификации устарели!\nОбновите файлы запустив лаунчер"
else -- only enUS/enGB yet...
    cloth = "Cloth"; leather = "Leather"; mail = "Mail"; plate = "Plate"

    alert = "Warning! Your transmogrify interface files are outdated!\nUpdate files by running launcher"
end
local cosmeticIds, cosmetic = {105741, 105742, 105743, 105744, 105745, 105746, 105747, 105748, 95474, 95475, 97213, 97901}

-- alert users to update addon
local notifyUser = CreateFrame"Frame"
notifyUser:RegisterEvent"CHAT_MSG_ADDON"
notifyUser:RegisterEvent"PLAYER_ENTERING_WORLD"
notifyUser:RegisterEvent"PLAYER_ENTERING_BATTLEGROUND"

local PWT_VERSION_INFO = 1.22;
local NEWVERSION = false;
RegisterAddonMessagePrefix"PWTVerInfo"

local function PandaWoW_PostVersionInfo(channel, target)
	SendAddonMessage("PWTVerInfo", PWT_VERSION_INFO, channel, target);
end

local function PandaWoW_HandleVersionInfo(msg, author, channel)
	local recNumber = tonumber(msg);
	if (recNumber > PWT_VERSION_INFO) then
        if not NEWVERSION then
            local alertIcon = [[|TInterface\DialogFrame\UI-Dialog-Icon-AlertOther:24:24:0|t]]
            RaidNotice_AddMessage(RaidWarningFrame, alertIcon .. '\r\n' .. YELLOW_FONT_COLOR_CODE .. alert .. '\124r', ChatTypeInfo["RAID_WARNING"])
            DEFAULT_CHAT_FRAME:AddMessage(alertIcon .. YELLOW_FONT_COLOR_CODE .. alert .. '\124r' .. alertIcon)
            NEWVERSION = true -- we already notified player so we need to stop spamming
        end
	elseif (recNumber < PWT_VERSION_INFO) then
		PandaWoW_PostVersionInfo("WHISPER", author);
	end
end

LoadAddOn"Blizzard_ItemAlterationUI"
TransmogrifyArtFrameTitleText:SetText(TRANSMOGRIFY .. " (v. " .. PWT_VERSION_INFO .. ")")
notifyUser:SetScript("OnEvent", function(self, event, ...)
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

function PackInventoryLocation(container, slot, equipment, bank, bags, voidStorage)
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
    if itemSubClass == BATTLE_PET_SOURCE_2 or itemSubClass == QUESTS_LABEL then return end -- en/ru

	local location = PackInventoryLocation(container, slot, isPlayer, isBank, isBags, isVoid);

    if not customEnabled and equipSlot ~= mies then
        if itemSubClass == guns or itemSubClass == bows or itemSubClass == crossbows then -- ranged fix
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
            local _, link, itemRarity, _, _, _, itemSubClass, _, equipSlot, texture = GetItemInfo(itemId);
            for _, id in pairs(cosmeticIds) do if itemId == id then cosmetic = true break else cosmetic = nil end end

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
            if ((mainItemSubClass == plate or mainItemSubClass == mail or mainItemSubClass == leather or mainItemSubClass == cloth) and itemSubClass ~= mainItemSubClass and not cosmetic)
              or (mainItemSubClass == daggers and (itemSubClass ~= mainItemSubClass))
              or (mainItemSubClass == shields and (itemSubClass ~= mainItemSubClass))
              or ((itemSubClass == polearms or itemSubClass == staves) and (itemSubClass ~= mainItemSubClass and mainItemSubClass ~= staves and mainItemSubClass ~= polearms))
              or ((mainItemSubClass == polearms or mainItemSubClass == staves) and (mainItemSubClass ~= itemSubClass and itemSubClass ~= staves and itemSubClass ~= polearms))
              or strfind(texture:lower(), 'fishing')
              or mainItemSubClass == fists and (itemSubClass ~= mainItemSubClass)
              or ((mainItemSubClass == oneHswords or mainItemSubClass == oneHaxes or mainItemSubClass == oneHmaces) and (itemSubClass == twoHmaces or itemSubClass == twoHaxes or itemSubClass == twoHswords or itemSubClass == daggers or itemSubClass == fists))
              or ((mainItemSubClass == guns or mainItemSubClass == bows or mainItemSubClass == crossbows) and (itemSubClass ~= guns and itemSubClass ~= bows and itemSubClass ~= crossbows))
              or itemRarity == ITEM_QUALITY_LEGENDARY then
                useTable[location] = nil;
            end
        end
    else
        for location, itemId in pairs(useTable) do
            if itemId == invItemId then useTable[location] = nil; end
            local _, _, _, _, _, itemClass, itemSubClass, _, equipSlot = GetItemInfo(itemId);
            -- for _, id in pairs(cosmeticIds) do if itemId == id then cosmetic = true break else cosmetic = nil end end

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

            -- Hide weapons that not allowed to tmog
            if Is64BitClient() and itemId == 3934 then if (mainItemSubClass == oneHswords or mainItemSubClass == oneHaxes or mainItemSubClass == oneHmaces or mainItemSubClass == twoHswords or mainItemSubClass == twoHaxes or mainItemSubClass == twoHmaces or mainItemSubClass == polearms or mainItemSubClass == staves) then-- working only on x64 client :(
			else useTable[location] = nil; end
            -- polearms/staves -> staves/polearms/2h
            elseif (mainItemSubClass == polearms or mainItemSubClass == staves)
              and (itemSubClass ~= staves and itemSubClass ~= polearms and itemSubClass ~= twoHswords and itemSubClass ~= twoHaxes and itemSubClass ~= twoHmaces) then
                useTable[location] = nil;
            -- daggers/fists -> 1h
            elseif (mainItemSubClass == daggers or mainItemSubClass == fists)
              and (itemSubClass ~= oneHswords and itemSubClass ~= oneHaxes and itemSubClass ~= oneHmaces
              and itemSubClass ~= daggers and itemSubClass ~= fists) then
                useTable[location] = nil;
            -- 2h NOT ALLOWED TO daggers/fists
            elseif (mainItemSubClass == twoHswords or mainItemSubClass == twoHaxes or mainItemSubClass == twoHmaces)
              and (itemSubClass == daggers or itemSubClass == fists) then
                useTable[location] = nil;
            -- 1h/2h > 1h/2h
            elseif (mainItemSubClass == oneHswords or mainItemSubClass == oneHaxes or mainItemSubClass == oneHmaces or mainItemSubClass == twoHswords or mainItemSubClass == twoHaxes or mainItemSubClass == twoHmaces)
              and (itemSubClass ~= twoHswords and itemSubClass ~= twoHaxes and itemSubClass ~= twoHmaces
              and itemSubClass ~= oneHswords and itemSubClass ~= oneHaxes and itemSubClass ~= oneHmaces
              and itemSubClass ~= daggers and itemSubClass ~= fists and itemSubClass ~= staves and itemSubClass ~= polearms) then
                useTable[location] = nil;
            -- Hide wands from bows/crossbows/guns slot and vice versa
            elseif (mainItemSubClass == guns or mainItemSubClass == bows or mainItemSubClass == crossbows)
             and (itemSubClass ~= guns and itemSubClass ~= bows and itemSubClass ~= crossbows) then
                useTable[location] = nil;
            elseif mies ~= equipSlot and (itemSubClass == guns or itemSubClass == bows or itemSubClass == crossbows) then
                useTable[location] = nil;
            elseif itemSubClass ~= mainItemSubClass and mies == equipSlot and (mainItemSubClass ~= guns and mainItemSubClass ~= bows and mainItemSubClass ~= crossbows) and (itemSubClass == guns or itemSubClass == bows or itemSubClass == crossbows) then
                useTable[location] = nil;
            end

            if (itemSubClass == BATTLE_PET_SOURCE_2 or itemSubClass == QUESTS_LABEL) or -- en/ru
            mies ~= equipSlot and itemId ~= 3934 then
                useTable[location] = nil;
            end
        end
    end

    -- clean from incorrect slots (x64 client)
    if Is64BitClient() then
        for location, itemId in pairs(useTable) do
            local _, _, _, _, _, _, itemSubClass, _, itemSlot = GetItemInfo(itemId);
            if equipLocation[itemSlot] ~= inventorySlot and inventorySlot == 17 then
                if itemSubClass == guns or itemSubClass == bows or itemSubClass == crossbows then
                    useTable[location] = nil
                end
            elseif equipLocation[mies] == 16 and (itemSubClass == guns or itemSubClass == bows or itemSubClass == crossbows) then useTable[location] = nil
            elseif equipLocation[itemSlot] == 17 and inventorySlot == 16 then
            elseif equipLocation[itemSlot] ~= inventorySlot and (itemSubClass ~= guns and itemSubClass ~= bows and itemSubClass ~= crossbows and itemId ~= 3934) then useTable[location] = nil
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