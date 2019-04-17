PandaWoWCommandLib = commandLib
assert(PandaWoWCommandLib)

Transmogrication = {};

local customEnabled = nil;

local _G = _G
local GetContainerNumSlots, GetContainerItemID, GetContainerItemLink, GetItemInfo, GetSpellInfo = 
      GetContainerNumSlots, GetContainerItemID, GetContainerItemLink, GetItemInfo, GetSpellInfo
local bor, lshift = bit.bor, bit.lshift;
local NUM_BAG_SLOTS, BACKPACK_CONTAINER, BANK_CONTAINER = _G.NUM_BAG_SLOTS, _G.BACKPACK_CONTAINER, _G.BANK_CONTAINER;

local VOID_CONTAINER = -3

-- en locale: "Quests","Quest", ru locale: "Задание","Задания" :\
local QUESTS_LABEL, BATTLE_PET_SOURCE_2 = _G.QUESTS_LABEL, _G.BATTLE_PET_SOURCE_2

local ITEM_QUALITY_LEGENDARY = _G.ITEM_QUALITY_LEGENDARY;

--[[local itemTypes = {
    oneHaxes    = 196,  twoHaxes    = 197,
    oneHmaces   = 198,  twoHmaces   = 199,
    polearms    = 200,  staves      = 227,
    oneHswords  = 201,  twoHswords  = 202,
    daggers     = 1180, fists       = 15590,
    bows        = 264,  crossbows   = 5011, guns = 266,}]]
local cloth, leather, mail, plate
local oneHaxes, twoHaxes, polearms, staves, oneHmaces, twoHmaces, oneHswords, twoHswords, daggers, fists, shields, bows, crossbows, guns =
GetSpellInfo(196), GetSpellInfo(197), GetSpellInfo(200), GetSpellInfo(227), GetSpellInfo(198), GetSpellInfo(199), 
GetSpellInfo(201), GetSpellInfo(202), GetSpellInfo(1180), GetSpellInfo(15590), GetSpellInfo(9116), GetSpellInfo(264), GetSpellInfo(5011), GetSpellInfo(266)
if GetLocale() == "ruRU" then
    polearms = "Древковое"; oneHmaces = "Одноручное дробящее"; twoHmaces = "Двуручное дробящее"
    cloth = "Тканевые"; leather = "Кожаные"; mail = "Кольчужные"; plate = "Латные"; fists = "Кистевое"
    guns = "Огнестрельное"
else -- only enUS/enGB yet...
    cloth = "Cloth"; leather = "Leather"; mail = "Mail"; plate = "Plate"
end

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

    if not customEnabled and inventorySlot == 17 and equipSlot ~= mies then 
        useTable[location] = nil
        return
    end

    if equipLocation[equipSlot] == inventorySlot and useTable[location] == nil then
        useTable[location] = itemID;
	end
end

hooksecurefunc('GetInventoryItemsForSlot', function(inventorySlot, useTable, transmog)
    if transmog == nil then return end
    local invItemId = GetInventoryItemID("player", inventorySlot)
    if not invItemId then return end

    local _, _, _, _, _, _, mainItemSubClass, _, mies = GetItemInfo(invItemId);

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

    if not customEnabled then
        local playerClass = UnitClass"player"
        if GetLocale() == "ruRU" then
            if playerClass == "Шаманка" then playerClass = "Шаман"
            elseif playerClass == "Жрица" then playerClass = "Жрец"
            elseif playerClass == "Охотница" then playerClass = "Охотник"
            elseif playerClass == "Разбойница" then playerClass = "Разбойник"
            elseif playerClass == "Чернокнижница" then playerClass = "Чернокнижник"
            elseif playerClass == "Монахиня" then playerClass = "Монах"
            end
        end
        playerClass = playerClass:lower()
        for location, itemId in pairs(useTable) do
            if itemId == invItemId then useTable[location] = nil; end
            local _, link, itemRarity, _, _, _, itemSubClass, _, equipSlot = GetItemInfo(itemId);

            -- We need to check tooltip of items to tmog if we are able to wear
            --i.e it will hide armor from another classes but will show weapons that are unable to wear
            GameTooltip:SetOwner(UIParent,'ANCHOR_NONE')
            GameTooltip:SetHyperlink(link)
            for i=1, GameTooltip:NumLines()do
                local tooltipText = _G['GameTooltipTextLeft' .. i]:GetText():lower()
                -- crappy and limited regex but it works
                local _, _, class1, class2, class3, class4 = string.find(tooltipText,string.gsub(ITEM_CLASSES_ALLOWED:lower(), "%%s", "([^,+]+),? ?([^,+]+),? ?([^,+]+),? ?([^,+]+)"))

                if (class1 and class1 ~= playerClass)
                or (class2 and class2 ~= playerClass)
                or (class3 and class3 ~= playerClass)
                or (class4 and class4 ~= playerClass) then
                    useTable[location] = nil;
                end
            end
            GameTooltip:Hide()

            -- Hide lower armor type items and legendary items
            if (mainItemSubClass == plate and (itemSubClass ~= mainItemSubClass)
              or mainItemSubClass == mail and (itemSubClass ~= mainItemSubClass)
              or mainItemSubClass == leather and (itemSubClass ~= mainItemSubClass)
              or mainItemSubClass == daggers and (itemSubClass ~= mainItemSubClass)
              or mainItemSubClass == shields and (itemSubClass ~= shields)
              or mainItemSubClass == fists and (itemSubClass ~= mainItemSubClass)
              or (mainItemSubClass == oneHswords or mainItemSubClass == oneHaxes or mainItemSubClass == oneHmaces) and (itemSubClass == twoHmaces or itemSubClass == twoHaxes or itemSubClass == twoHswords or itemSubClass == daggers or itemSubClass == fists)
              or (mainItemSubClass == guns or mainItemSubClass == bows or mainItemSubClass == crossbows) and (itemSubClass ~= guns and itemSubClass ~= bows and itemSubClass ~= crossbows))
              or itemRarity == ITEM_QUALITY_LEGENDARY then
                useTable[location] = nil;
            end
        end
    else
        for location, itemId in pairs(useTable) do
            if itemId == invItemId then useTable[location] = nil; end
            local _, _, _, _, _, _, itemSubClass, _, equipSlot = GetItemInfo(itemId);

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
            -- Allow main hands trans into one hands and vice versa
            elseif mies == "INVTYPE_WEAPON" and equipSlot == "INVTYPE_WEAPONMAINHAND" then
                equipSlot = "INVTYPE_WEAPON"
            elseif mies == "INVTYPE_WEAPONMAINHAND" and equipSlot == "INVTYPE_WEAPON" then
                equipSlot = "INVTYPE_WEAPONMAINHAND"
            -- Allow offhands trans into shields and vice versa
            elseif mies == "INVTYPE_HOLDABLE" and equipSlot == "INVTYPE_SHIELD" then
                equipSlot = "INVTYPE_HOLDABLE"
            elseif mies == "INVTYPE_SHIELD" and equipSlot == "INVTYPE_HOLDABLE" then
                equipSlot = "INVTYPE_SHIELD"
            end

            -- Hide weapons that not allowed to tmog
            -- polearms/staves -> staves/polearms
            if (mainItemSubClass == polearms or mainItemSubClass == staves)
              and itemSubClass ~= staves and itemSubClass ~= polearms then
                useTable[location] = nil;
            -- daggers/fists -> 1h
            elseif (mainItemSubClass == daggers or mainItemSubClass == fists)
              and itemSubClass ~= oneHswords and itemSubClass ~= oneHaxes and itemSubClass ~= oneHmaces
              and itemSubClass ~= daggers and itemSubClass ~= fists then
                useTable[location] = nil;
            -- 2h NOT ALLOWED TO daggers/fists
            elseif (mainItemSubClass == twoHswords or mainItemSubClass == twoHaxes or mainItemSubClass == twoHmaces)
              and itemSubClass == daggers or itemSubClass == fists then
                useTable[location] = nil;
            -- 1h/2h > 1h/2h
            elseif (mainItemSubClass == oneHswords or mainItemSubClass == oneHaxes or mainItemSubClass == oneHmaces 
             or mainItemSubClass == twoHswords or mainItemSubClass == twoHaxes or mainItemSubClass == twoHmaces)
              and itemSubClass ~= twoHswords and itemSubClass ~= twoHaxes and itemSubClass ~= twoHmaces
              and itemSubClass ~= oneHswords and itemSubClass ~= oneHaxes and itemSubClass ~= oneHmaces
              and itemSubClass ~= daggers and itemSubClass ~= fists then
                useTable[location] = nil;
            end

            if (itemSubClass == BATTLE_PET_SOURCE_2 or itemSubClass == QUESTS_LABEL) or -- en/ru
            mies ~= equipSlot then
                useTable[location] = nil;
            end
        end
    end
end)

function Transmogrication.LoadInfo()
    PandaWoWCommandLib:DoCommand("checktransmog", function(s, o)if o[1] == "enabled" then customEnabled = true; end end);
end