ZZDailyWrits = {}
local DW = ZZDailyWrits

DW.name            = "ZZDailyWrits"
DW.version         = "2.7.1"
DW.savedVarVersion = 1
DW.default         = {
    position = {350,100}
}

-- Sequence the writs in an order I prefer.
--
-- Use these values for craft_type
--
DW.CRAFTING_TYPE = {
  { abbr = "bs", ct = CRAFTING_TYPE_BLACKSMITHING }
, { abbr = "cl", ct = CRAFTING_TYPE_CLOTHIER      }
, { abbr = "ww", ct = CRAFTING_TYPE_WOODWORKING   }
, { abbr = "al", ct = CRAFTING_TYPE_ALCHEMY       }
, { abbr = "en", ct = CRAFTING_TYPE_ENCHANTING    }
, { abbr = "pr", ct = CRAFTING_TYPE_PROVISIONING  }
}

local DWUI = nil


-- Quest states --------------------------------------------------------------

                        -- Not started
                        -- Need to visit a billboard to acquire quest.
                        -- "X" icon.
DW.STATE_0_NEEDS_ACQUIRE    = "X"

                        -- Acquired, but at least one item needs to be
                        -- crafted before turnining in.
                        -- Need to visit a crafting station to
                        -- make things.
                        -- "Anvil" icon.
DW.STATE_1_NEEDS_CRAFTING   = "A"

                        -- Crafting of all items completed.
                        -- Need to visit turn-in station.
                        -- "Bag" icon
DW.STATE_2_NEEDS_TURN_IN    = "B"

                        -- Quest completed. Done for the day.
                        -- "Checkmark" icon.
DW.STATE_3_TURNED_IN        = "V"

-- QuestStatus --------------------------------------------------------------
--
-- What remains to be done for this quest?
--
DW.QuestStatus = {
}
function DW.QuestStatus:New()
    local o = { status      = DW.STATE_0_NEEDS_ACQUIRE
              , acquired_ts = 0  -- When we received the event for "acquired
                                 -- this quest," or 11pm yesterday if we
                                 -- missed that event and we're learning of
                                 -- the quest via a journal scan.
              }
    setmetatable(o, self)
    self.__index = self
    return o
end

-- CharData ==================================================================
--
-- Current character's crafting quests data.
--
-- Knows how to query current (aka "journal") quests to find any current quest status.
-- Knows to remember up to two quests' states, resets

local CharData = {
}
function CharData:New()
    local o = {
        char_name   = nil   -- "Zhaksyr the Mighty"

    ,   quest_status = {}   -- index = craft_type
                            -- value = QuestStatus
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

-- Init ----------------------------------------------------------------------

function DW.OnAddOnLoaded(event, addonName)
    if addonName ~= DW.name then return end
    if not DW.version then return end
    if not DW.default then return end
    DW:Initialize()
end

function DW:Initialize()
    if not DWUI then
        DWUI = ZZDailyWritsUI
    end

    ZO_CreateStringId("SI_BINDING_NAME_ZZDW_TOGGLE_VISIBILITY", "Show/Hide")

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

function DW:RestorePos()
    pos = self.savedVariables.position
    if not pos then
        pos = self.default.position
        d("pos huh?")
    end

    DWUI:SetAnchor(
             TOPLEFT
            ,GuiRoot
            ,TOPLEFT
            ,pos[1]
            ,pos[2]
            )
end

function DW:SavePos()
    d("SavePos")
    self.savedVariables.position = { DWUI:GetLeft()
                                   , DWUI:GetTop()
                                   }
end

-- Keybinding ----------------------------------------------------------------

function ZZDailyWrits.ToggleVisibility()
    d("ZZDW.ToggleVisibility")
    ui = DWUI
    if not ui then
        d("No UI")
        return
    end
    local h = DWUI:IsHidden()
    if h then
        DW:RestorePos()
    end
    DWUI:SetHidden(not h)
end

-- UI ------------------------------------------------------------------------

--[[
function DW_Update()

end

function DW_Initialized()

end
--]]

-- Postamble -----------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent( DW.name
                              , EVENT_ADD_ON_LOADED
                              , DW.OnAddOnLoaded
                              )

ZO_CreateStringId("SI_BINDING_NAME_DW_DoIt", "Show me")
