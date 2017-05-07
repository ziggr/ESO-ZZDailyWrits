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
  { abbr = "bs", order = 1, ct = CRAFTING_TYPE_BLACKSMITHING , quest_name = "Blacksmithing Writ"}
, { abbr = "cl", order = 2, ct = CRAFTING_TYPE_CLOTHIER      , quest_name = "Clothier Writ" }
, { abbr = "ww", order = 3, ct = CRAFTING_TYPE_WOODWORKING   , quest_name = "Woodworking Writ"}
, { abbr = "al", order = 4, ct = CRAFTING_TYPE_ALCHEMY       , quest_name = "Alchemy Writ"}
, { abbr = "en", order = 5, ct = CRAFTING_TYPE_ENCHANTING    , quest_name = "Enchanter Writ"}
, { abbr = "pr", order = 6, ct = CRAFTING_TYPE_PROVISIONING  , quest_name = "Provisioner Writ"}
}

local DWUI = nil


-- Quest states --------------------------------------------------------------

                        -- Not started
                        -- Need to visit a billboard to acquire quest.
                        -- "X" icon.
DW.STATE_0_NEEDS_ACQUIRE    = { id = "acqr", order = 0 }

                        -- Acquired, but at least one item needs to be
                        -- crafted before turnining in.
                        -- Need to visit a crafting station to
                        -- make things.
                        -- "Anvil" icon.
DW.STATE_1_NEEDS_CRAFTING   = { id = "crft", order = 1 }

                        -- Crafting of all items completed.
                        -- Need to visit turn-in station.
                        -- "Bag" icon
DW.STATE_2_NEEDS_TURN_IN    = { id = "turn", order = 2 }

                        -- Quest completed. Done for the day.
                        -- "Checkmark" icon.
DW.STATE_3_TURNED_IN        = { id = "done", order = 3 }

function DW.StateMax(a, b)
    if a.order < b.order then
        return b
    else
        return a
    end
end

-- QuestStatus --------------------------------------------------------------
--
-- What remains to be done for this quest?
--
DW.QuestStatus = {
}
function DW.QuestStatus:New()
    local o = { state       = DW.STATE_0_NEEDS_ACQUIRE
              , text        = ""
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
-- Knows how to query current (aka "journal") quests to find any
-- current quest status.

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

-- Scan the "Quest Journal" for active crafting quests.
function CharData:ScanJournal()
    local quest_ct = GetNumJournalQuests()
    local quest_status = {}
    for qi = 1, quest_ct do
        local x = self:AbsorbQuest(qi)
        if x then
            quest_status[x.crafting_type.order] = x.quest_status
d("Set qs["..tostring(x.crafting_type.order).."]")
d(x)
        end
    end

                        -- XXX Merge with previous quest_status list here
                        -- XXX to retain previously turned-in
                        -- XXX quests.

    self.quest_status = quest_status
d("char_data.quest_status:  ct="..#self.quest_status)
d(self.quest_status[2])
end

-- GetJournalQuestInfo() returns:
DW.JQI = {
  quest_name            =  1 -- string
, background_text       =  2 -- string
, active_step_text      =  3 -- string
, active_step_type      =  4 -- number
, active_step_tracker_override_text =  5 -- string
, completed             =  6 -- boolean
, tracked               =  7 -- boolean
, quest_level           =  8 -- number
, pushed                =  9 -- boolean
, quest_type            = 10 -- number
, instance_display_type = 11 -- number InstanceDisplayType
}

-- GetJournalQuestStepInfo() returns
DW.JQSI = {
  step_text             = 1 -- string
, visibility            = 2 -- number:nilable
, step_type             = 3 -- number
, tracker_override_text = 4 -- string
, num_conditions        = 5 -- number
}

-- GetJournalQuestConditionInfo() returns
DW.JQCI = {
  condition_text        = 1 -- string
, current               = 2 -- number
, max                   = 3 -- number
, is_fail_condition     = 4 -- boolean
, is_complete           = 5 -- boolean
, is_credit_shared      = 6 -- boolean
, is_visible            = 7 -- boolean
}

-- Fetch a quest's data from server. If it's a crafting quest,
-- store its quest_status in the appropriate self.quest_status[] slot.
function CharData:AbsorbQuest(quest_index)
                        -- Only daily quests matter.
    local rt = GetJournalQuestRepeatType(quest_index)
    if rt ~= QUEST_REPEAT_DAILY then
        -- d(tostring(quest_index).." not daily "..tostring(rt))
        return
    end
                        -- Only daily CRAFTING quests matter.
    local qinfo = { GetJournalQuestInfo(quest_index) }
    if qinfo[DW.JQI.quest_type] ~= QUEST_TYPE_CRAFTING then
        -- d(tostring(quest_index).." not crafting "..tostring(qinfo[DW.JQI.quest_type]))
        return
    end
                        -- Find correct index into CharData.quest_status[]
    local crafting_type = self:QuestNameToCraftingType(qinfo[DW.JQI.quest_name])
    if not crafting_type then
        d("quest_name matches no index: "..tostring(qinfo[DW.JQI.quest_name]))
        return
    end

                        -- Accumulate conditions into a quest_status.
    local quest_status = self:AccumulateCondition(quest_index)

    return { crafting_type = crafting_type
           , quest_status  = quest_status
           }
end

function CharData:QuestNameToCraftingType(quest_name)
    for i, ct in ipairs(DW.CRAFTING_TYPE) do
        if quest_name:find(ct.quest_name) then
            return ct
        end
    end
    return nil
end

-- Return a quest's conditions as a single QuestStatus instance.
function CharData:AccumulateCondition(quest_index)
    local text_list = {}
    local status    = DW.STATE_1_NEEDS_CRAFTING

                        -- Accumulate quest's current status, which always seems to
                        -- be the status of the last/highest-indexed step.
    local step_ct = GetJournalQuestNumSteps(quest_index)
    local step_index = step_ct
    local sinfo = { GetJournalQuestStepInfo(quest_index, step_index) }
-- d(sinfo)
    local condition_ct = sinfo[DW.JQSI.num_conditions]
    for ci = 1, condition_ct do
        local cinfo = { GetJournalQuestConditionInfo(quest_index, step_index, ci) }
-- d("Condition " .. tostring(ci))
-- d(cinfo)
                        -- If we have not completed all the required counts
                        -- for this condition, then its text matters.
        if cinfo[DW.JQCI.is_visible]
                and ( cinfo[DW.JQCI.current] < cinfo[DW.JQCI.max] ) then
                local c_text = cinfo[DW.JQCI.condition_text]
            table.insert(text_list, c_text)
            status = DW.StateMax(status, self:ConditionTextToState(c_text))
        end
    end

    local quest_status = DW.QuestStatus:New()
    quest_status.status = status
    quest_status.text   = table.concat(text_list, "\n")
    return quest_status
end

-- If a crafting quest exists in the journal, it either needs to be
-- crafted, or needs to be turned in.
function CharData:ConditionTextToState(condition_text)
    local says_deliver = string.find(condition_text, "Deliver ")
    if says_deliver then
        return DW.STATE_2_NEEDS_TURN_IN
    else
        return DW.STATE_1_NEEDS_CRAFTING
    end
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

    DW.char_data = CharData:New()

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
        -- d("pos huh?")
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
    --d("SavePos")
    self.savedVariables.position = { DWUI:GetLeft()
                                   , DWUI:GetTop()
                                   }
end

-- Keybinding ----------------------------------------------------------------

function ZZDailyWrits.ToggleVisibility()
    -- d("ZZDW.ToggleVisibility")
    ui = DWUI
    if not ui then
        d("No UI")
        return
    end
    local h = DWUI:IsHidden()
    if h then
        DW:RestorePos()
        DW.char_data:ScanJournal()
        DW:DisplayCharData()
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

function DW:DisplayCharData()
    for _,ct in ipairs(DW.CRAFTING_TYPE) do
        local quest_status = self.char_data.quest_status[ct.order]
        if quest_status then
            local ui = ZZDailyWritsUI:GetNamedChild("_status_"..ct.abbr)
            ui:SetText(quest_status.status.id)
d("UI set "..ct.abbr)
        end

    end
end

-- Postamble -----------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent( DW.name
                              , EVENT_ADD_ON_LOADED
                              , DW.OnAddOnLoaded
                              )

ZO_CreateStringId("SI_BINDING_NAME_DW_DoIt", "Show me")
