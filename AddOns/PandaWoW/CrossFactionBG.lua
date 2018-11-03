StaticPopupDialogs["CONFIRM_JOIN_SOLO_CROSS"] =
{
	text = CONFIRM_JOIN_SOLO,
	button1 = YES,
	button2 = NO,
	OnAccept = function() JoinCrossPressed(soloCrossButton); end,
	OnShow = function(self)	end,
	OnCancel = function (self) end,
	hideOnEscape = 1,
	timeout = 0,
}

function CreateButton()
    if joinCrossFaction ~= nil then
        return;
    end

	if HonorFrame and not WorldStateScoreFrame:IsShown()then
		local joinCrossFaction = CreateFrame("CheckButton", "joinCrossFaction", HonorFrame, "UICheckButtonTemplate");--joinCrossFaction = CreateFrame("Button", "joinCrossFaction_GlobalName", HonorFrame, "MagicButtonTemplate");
		joinCrossFaction:SetPoint("BOTTOMLEFT", 120, -5);
		joinCrossFactionText:SetText("Cross-Faction");
		if IsCrossChecked then joinCrossFaction:SetChecked(1) end
		local function replacebuttons()
			if IsCrossChecked then
				HonorFrameSoloQueueButton:Hide()
				HonorFrameGroupQueueButton:Hide()
				soloCrossButton:Show()
				partyCrossButton:Show()
			else
				HonorFrameSoloQueueButton:Show()
				HonorFrameGroupQueueButton:Show()
				soloCrossButton:Hide()
				partyCrossButton:Hide()
			end
			if HonorFrameGroupQueueButton:IsEnabled()then
				partyCrossButton:Enable()
			else
				partyCrossButton:Disable()
			end
			if HonorFrameSoloQueueButton:IsEnabled()then
				soloCrossButton:Enable()
			else
				soloCrossButton:Disable()
			end
		end
		joinCrossFaction:SetScript("OnClick", function(self)
			IsCrossChecked = self:GetChecked()and 1 or nil
			replacebuttons()
		end);
		joinCrossFaction:SetScript("OnShow",function(self)
			replacebuttons()
		end)
		
		local soloCrossButton = CreateFrame("Button", "soloCrossButton", HonorFrame, "MagicButtonTemplate");
		select(6,soloCrossButton:GetRegions()):Hide()
		soloCrossButton:SetPoint("CENTER",HonorFrameSoloQueueButton)
		soloCrossButton:SetSize(HonorFrameSoloQueueButton:GetSize())
		--soloCrossButton:SetFrameLevel(HonorFrameSoloQueueButton:GetFrameLevel()+1)
		soloCrossButtonText:SetText(BATTLEFIELD_JOIN)
		soloCrossButton:SetScript("OnClick", function(self)
			if (GetNumGroupMembers() > 1) then
				StaticPopup_Show("CONFIRM_JOIN_SOLO_CROSS");
				return;
			end
			JoinCrossPressed(self)
		end)
		local partyCrossButton = CreateFrame("Button", "partyCrossButton", HonorFrame, "MagicButtonTemplate");
		select(7,partyCrossButton:GetRegions()):Hide()
		partyCrossButton:SetPoint("CENTER",HonorFrameGroupQueueButton)
		partyCrossButton:SetSize(HonorFrameGroupQueueButton:GetSize())
		--partyCrossButton:SetFrameLevel(HonorFrameGroupQueueButton:GetFrameLevel()+1)
		partyCrossButtonText:SetText(BATTLEFIELD_GROUP_JOIN)
		partyCrossButton:SetScript("OnClick", function(self)
			JoinCrossPressed(self)
		end)
		HonorFrame.SoloQueueButton:HookScript('OnEnable',function()soloCrossButton:Enable()end)
		HonorFrame.SoloQueueButton:HookScript('OnDisable',function()soloCrossButton:Disable()end)
		HonorFrame.GroupQueueButton:HookScript('OnEnable',function()partyCrossButton:Enable()end)
		HonorFrame.GroupQueueButton:HookScript('OnDisable',function()partyCrossButton:Disable()end)
		if IsAddOnLoaded"Aurora" then 
			Aurora[1].Reskin(soloCrossButton)
			Aurora[1].Reskin(partyCrossButton)
		end
		replacebuttons()
	end
end

function JoinCrossPressed(self)
    PlaySound("igMainMenuOptionCheckBoxOn");

    if ( HonorFrame.type == "specific" and HonorFrame.SpecificFrame.selectionID ) then
        JoinCross(self, HonorFrame.SpecificFrame.selectionID)
    elseif ( HonorFrame.type == "bonus" and HonorFrame.BonusFrame.selectedButton ) then
        if ( HonorFrame.BonusFrame.selectedButton.worldID ) then
            local pvpID = GetWorldPVPAreaInfo(HonorFrame.BonusFrame.selectedButton.worldID);
            --JoinCross(pvpID)
        else
            JoinCross(self, HonorFrame.BonusFrame.selectedButton.bgID);
        end
    end
end

local function Check(flag, value)
    if (flag) then
        return value;
    end
    
    return 0;
end

local function GetRoleNumber()
    local tank, healer, dps = GetPVPRoles();
    local role = Check(tank, 2) + Check(healer, 4) + Check(dps, 8);
    return role;
end

function boolToNumber(value)
    return value and 1 or 0;
end

function roundMap(mapId)
    return mapId >= 0 and mapId or 0;
end

function JoinCross(self, _bgId)
    local role = GetRoleNumber();
    local groupQue = boolToNumber(UnitIsGroupLeader('player')and self:GetName()=='partyCrossButton' and GetNumGroupMembers() > 1);
    
    if (_bgId == 32) then
        local mapID1 = roundMap(GetBlacklistMap(1));
        local mapID2 = roundMap(GetBlacklistMap(2));
        
        local black = mapID1.." "..mapID2;

        SendChatMessage(".join cross_faction ".._bgId.." "..role.." "..black.." "..groupQue, "GUILD");
        return;
    end
    
    SendChatMessage(".join cross_faction ".._bgId.." "..role.." 0 0 "..groupQue, "GUILD");
end
