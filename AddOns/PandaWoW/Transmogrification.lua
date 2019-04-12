PandaWoWCommandLib = commandLib
assert(PandaWoWCommandLib)

Transmogrication = {};

local customEnabled = nil;

local _G = _G
local GetContainerNumSlots, GetContainerItemID, GetContainerItemLink, GetItemInfo = 
      GetContainerNumSlots, GetContainerItemID, GetContainerItemLink, GetItemInfo
local bor, lshift = bit.bor, bit.lshift;
local NUM_BAG_SLOTS, BACKPACK_CONTAINER, BANK_CONTAINER = _G.NUM_BAG_SLOTS, _G.BACKPACK_CONTAINER, _G.BANK_CONTAINER;

local VOID_CONTAINER = -3

-- en locale: "Quests","Quest", ru locale: "Задание","Задания" :\
local QUESTS_LABEL, BATTLE_PET_SOURCE_2 = _G.QUESTS_LABEL, _G.BATTLE_PET_SOURCE_2

local ITEM_QUALITY_LEGENDARY = _G.ITEM_QUALITY_LEGENDARY;

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
    INVTYPE_CLOAK       = 15, -- INVTYPE_BACK
    
    INVTYPE_WEAPON      = 16,
    INVTYPE_WEAPONMAINHAND = 16,
    INVTYPE_MAINHAND	= 16,
    INVTYPE_2HWEAPON    = 16,
    
    INVTYPE_WEAPONOFFHAND = 17,
    INVTYPE_OFFHAND		= 17,
    INVTYPE_HOLDABLE    = 17,
    INVTYPE_SHIELD      = 17,
    INVTYPE_RANGED		= 18,
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

local function AddEquippableItem(useTable, inventorySlot, container, slot)
    local itemID, link, _
    if container == VOID_CONTAINER then
        _, link = GetItemInfo(GetVoidItemInfo(slot))
        itemID = tostring(string.match(link,"item:([%-?%d]+)")) -- extract ID from link
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

	local _, _, _, _, _, itemClass, _, _, equipSlot = GetItemInfo(link)
    if itemClass == BATTLE_PET_SOURCE_2 or itemClass == QUESTS_LABEL then return end -- en/ru

	local location = PackInventoryLocation(container, slot, isPlayer, isBank, isBags, isVoid);
    
    if equipLocation[equipSlot] == inventorySlot and useTable[location] == nil then
        useTable[location] = itemID;
	end
end

hooksecurefunc('GetInventoryItemsForSlot', function(inventorySlot, useTable, transmog)
    if transmog == nil then return end
    local invItemId = GetInventoryItemID("player", inventorySlot)
    if not invItemId then return end

    local _, _, _, _, _, mainItemClass, _, _, mies = GetItemInfo(invItemId);
    
    if mainItemClass == nil then return end
    
    if customEnabled == true then
        for container = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
            for slot = 1, GetContainerNumSlots(container) do
                AddEquippableItem(useTable, inventorySlot, container, slot)
            end
        end
        
        --print(PackInventoryLocation(BANK_CONTAINER, 2, nil, true, nil));
        
        -- scan bank main frame (data is only available when bank is opened)
        for slot = 1, _G.NUM_BANKGENERIC_SLOTS do
            AddEquippableItem(useTable, inventorySlot, BANK_CONTAINER, slot)
        end
        
        -- scan bank containers
        for bankContainer = 1, _G.NUM_BANKBAGSLOTS do
            local container = _G.ITEM_INVENTORY_BANK_BAG_OFFSET + bankContainer
            for slot = 1, GetContainerNumSlots(container) or 0 do
                AddEquippableItem(useTable, inventorySlot, container, slot)
            end
        end
        
        -- scan void
        for voidSlot = 1, 80 do -- VOID_STORAGE_MAX
            if GetVoidItemInfo(voidSlot) then
                AddEquippableItem(useTable, inventorySlot, VOID_CONTAINER, voidSlot)
            end
        end
    else
        for location, itemId in pairs(useTable) do
            local _, _, itemRarity = GetItemInfo(itemId);
            
            if itemRarity == ITEM_QUALITY_LEGENDARY then
                useTable[location] = nil;
            end
        end
    end
    
    for location, itemId in pairs(useTable) do
        local _, _, _, _, _, itemClass, _, _, equipSlot  = GetItemInfo(itemId);
        
        -- Allow robes trans into chests and vice versa
        if mies == "INVTYPE_ROBE" and equipSlot == "INVTYPE_CHEST" then
            equipSlot = "INVTYPE_ROBE"
        elseif mies == "INVTYPE_CHEST" and equipSlot == "INVTYPE_ROBE" then
            equipSlot = "INVTYPE_CHEST"
        end

        if itemClass == BATTLE_PET_SOURCE_2 or itemClass == QUESTS_LABEL or -- en/ru
           (mies ~= equipSlot) then
            useTable[location] = nil;
        end
    end
end)

function Transmogrication.LoadInfo()
    PandaWoWCommandLib:DoCommand("checktransmog", function(s, o)if o[1] == "enabled" then customEnabled = true; end end);
end
