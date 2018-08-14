StaticPopupDialogs["CONFIRM_JOIN_SOLO_CROSS"] =
{
	text = CONFIRM_JOIN_SOLO,
	button1 = YES,
	button2 = NO,
	OnAccept = function(self) JoinCrossPressed(); end,
	OnShow = function(self)	end,
	OnCancel = function (self) end,
	hideOnEscape = 1,
	timeout = 0,
}

function CreateButton()
    if joinCrossFaction ~= nil then
        return;
    end

    joinCrossFaction = CreateFrame("Button", "joinCrossFaction_GlobalName", HonorFrame, "MagicButtonTemplate");
    joinCrossFaction:SetPoint("BOTTOMLEFT", 120, 0);
	joinCrossFaction:SetWidth(101)
	joinCrossFaction:SetHeight(22)
    joinCrossFaction_GlobalNameText:SetText("Cross-Faction");
    --joinCrossFaction.tooltip = "Join Cross-Faction BG queue";
    joinCrossFaction:SetScript("OnClick", function() ShowPopup(); end);
end

function ShowPopup()
    if (GetNumGroupMembers() > 1) then
        StaticPopup_Show("CONFIRM_JOIN_SOLO_CROSS");
        return;
    end
    
    JoinCrossPressed();
end

function JoinCrossPressed()
    PlaySound("igMainMenuOptionCheckBoxOn");

    if ( HonorFrame.type == "specific" and HonorFrame.SpecificFrame.selectionID ) then
        JoinCross(HonorFrame.SpecificFrame.selectionID)
    elseif ( HonorFrame.type == "bonus" and HonorFrame.BonusFrame.selectedButton ) then
        if ( HonorFrame.BonusFrame.selectedButton.worldID ) then
            local pvpID = GetWorldPVPAreaInfo(HonorFrame.BonusFrame.selectedButton.worldID);
            --JoinCross(pvpID)
        else
            JoinCross(HonorFrame.BonusFrame.selectedButton.bgID);
        end
    end
end

function Check(flag, value)
    if (flag) then
        return value;
    end
    
    return 0;
end

function GetRoleNumber()
    local tank, healer, dps = GetPVPRoles();
    local role = Check(tank, 2) + Check(healer, 4) + Check(dps, 8);
    return role;
end

function JoinCross(_bgId)
    local role = GetRoleNumber();
    
    if (_bgId == 32) then
        local black = "";
        
        local mapID1 = GetBlacklistMap(1);
        local mapID2 = GetBlacklistMap(2);
        
        if (mapID1 > 0 and mapID2 > 0) then
            black = mapID1.." "..mapID2;
        elseif (mapID1 > 0) then
            black = mapID1;
        elseif (mapID2 > 0) then
            black = mapID2;
        end
        
        SendChatMessage(".join cross_faction ".._bgId.." "..role.." "..black, "GUILD");
        return;
    end
    
    SendChatMessage(".join cross_faction ".._bgId.." "..role, "GUILD")
    --SendAddonMessage("PandaWoWUI_BG", ".join_cross|i".._bgId.."|r"..role.."|b"..black.."|", "INSTANCE_CHAT");
end
