ZZDailyWrits = {}
ZZDailyWrits.name            = "ZZDailyWrits"
ZZDailyWrits.version         = "2.7.1"
ZZDailyWrits.savedVarVersion = 1
ZZDailyWrits.default         = {
    position = {350,100}
}


-- Init ----------------------------------------------------------------------

function ZZDailyWrits.OnAddOnLoaded(event, addonName)
    if addonName ~= ZZDailyWrits.name then return end
    if not ZZDailyWrits.version then return end
    if not ZZDailyWrits.default then return end
    ZZDailyWrits:Initialize()
end

function ZZDailyWrits:Initialize()
    --EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)
    self.savedVariables = ZO_SavedVars:NewAccountWide(
                              "ZZDailyWritsVars"
                            , self.savedVarVersion
                            , nil
                            , self.default
                            )
    self:RestorePos()
end

-- Save/Restore UI Position --------------------------------------------------

function ZZDailyWrits:RestorePos()
    pos = self.savedVariables.position
    if not pos then
        pos = self.default.position
        d("pos huh?")
    end

    ZZDailyWritsUI:SetAnchor(
             TOPLEFT
            ,GuiRoot
            ,TOPLEFT
            ,pos[1]
            ,pos[2]
            )
end

function ZZDailyWrits:SavePos()
    d("SavePos")
    self.savedVariables.position = { ZZDailyWritsUI:GetLeft()
                                   , ZZDailyWritsUI:GetTop()
                                   }
end

-- Keybinding ----------------------------------------------------------------

function ZZDailyWrits_DoIt()
    d("_DoIt")
    ui = ZZDailyWritsUI
    if not ui then
        d("No UI")
        return
    end
    h = ZZDailyWritsUI:IsHidden()
    if h then
        ZZDailyWrits:RestorePos()
    end

    ZZDailyWritsUI:SetHidden(not h)
end

-- UI ------------------------------------------------------------------------

--[[
function ZZDailyWrits_Update()

end

function ZZDailyWrits_Initialized()

end
--]]

-- Postamble -----------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent( ZZDailyWrits.name
                              , EVENT_ADD_ON_LOADED
                              , ZZDailyWrits.OnAddOnLoaded
                              )

ZO_CreateStringId("SI_BINDING_NAME_ZZDailyWrits_DoIt", "Show me")
