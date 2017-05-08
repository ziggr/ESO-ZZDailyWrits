ZZDailyWrits = {}
local DW = ZZDailyWrits

DW.name            = "ZZDailyWrits"
DW.version         = "2.7.1"
DW.savedVarVersion = 2
DW.default         = { position  = {350,100}
                     , char_data = {}
                     }

-- Sequence the writs in an order I prefer.
--
-- Use these values for craft_type
--
DW.CRAFTING_TYPE = {
  { abbr = "bs", order = 1, ct = CRAFTING_TYPE_BLACKSMITHING , quest_name = "Blacksmith Writ"}
, { abbr = "cl", order = 2, ct = CRAFTING_TYPE_CLOTHIER      , quest_name = "Clothier Writ" }
, { abbr = "ww", order = 3, ct = CRAFTING_TYPE_WOODWORKING   , quest_name = "Woodworker Writ"}
, { abbr = "al", order = 4, ct = CRAFTING_TYPE_ALCHEMY       , quest_name = "Alchemist Writ"}
, { abbr = "en", order = 5, ct = CRAFTING_TYPE_ENCHANTING    , quest_name = "Enchanter Writ"}
, { abbr = "pr", order = 6, ct = CRAFTING_TYPE_PROVISIONING  , quest_name = "Provisioner Writ"}
}

local DWUI = nil



-- Quest states --------------------------------------------------------------

                        -- Not started
                        -- Need to visit a billboard to acquire quest.
                        -- "X" icon.
DW.STATE_0_NEEDS_ACQUIRE    = { id = "acquire", order = 0, color = "CCCCCC" }

                        -- Acquired, but at least one item needs to be
                        -- crafted before turnining in.
                        -- Need to visit a crafting station to
                        -- make things.
                        -- "Anvil" icon.
DW.STATE_1_NEEDS_CRAFTING   = { id = "craft",   order = 1, color = "FF3333" }

                        -- Crafting of all items completed.
                        -- Need to visit turn-in station.
                        -- "Bag" icon
DW.STATE_2_NEEDS_TURN_IN    = { id = "turn in", order = 2, color = "33FF33" }

                        -- Quest completed. Done for the day.
                        -- "Checkmark" icon.
DW.STATE_3_TURNED_IN        = { id = "done",    order = 3, color = "AAAAAA" }
DW.STATE_ORDERED = {
  [DW.STATE_0_NEEDS_ACQUIRE .order] = DW.STATE_0_NEEDS_ACQUIRE
, [DW.STATE_1_NEEDS_CRAFTING.order] = DW.STATE_1_NEEDS_CRAFTING
, [DW.STATE_2_NEEDS_TURN_IN .order] = DW.STATE_2_NEEDS_TURN_IN
, [DW.STATE_3_TURNED_IN     .order] = DW.STATE_3_TURNED_IN
}

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
--d("Set qs["..tostring(x.crafting_type.order).."]")
--d(x)
        end
    end
                        -- Merge with previous quest_status list here
                        -- to detect "needs turn-in" -> "turned in" edge.
    for i, ct in ipairs(DW.CRAFTING_TYPE) do
        self.quest_status[i] = self:MergeQuestStatus( self.quest_status[i]
                                                    , quest_status[i] )
    end
--d("char_data.quest_status:  ct="..#self.quest_status)
--d(self.quest_status[2])
end

-- When did the daily crafting writs reset? 10pm US Pacific Standard Time
function CharData:ResetTS()
                        -- 10pm US Pacific Standard Time
                        -- January 1, 2017.
                        -- 2017-01-01T22:00:00 -0800
    local start_ts    = 1483336800
    local now_ts      = GetTimeStamp()
    local sec_since   = now_ts - start_ts
    local sec_per_day = 24*60*60
    local days_since  = math.floor(sec_since / sec_per_day)
    local prev_reset_ts = (days_since * sec_per_day) + start_ts
    return prev_reset_ts
end


-- Once a quest vanishes from our list, assume it was turned in.
function CharData:MergeQuestStatus(prev, curr)
    if not prev then return curr end

                        -- Do not trust undated history.
    if not prev.acquired_ts then return curr end

                        -- Is the previous status from a quest
                        -- before the most recent daily reset?
                        -- If so, then ignore it in favor of
                        -- whatever we have now (even if curr == nil).
    if prev.acquired_ts < self:ResetTS() then return curr end

                        -- If no change in state, prefer previous
                        -- because its timestamp is closer to when
                        -- the state change actually occurred.
    if curr and (prev.state == curr.state) then return prev end

                        -- We needed to turn it in, and now it's gone.
                        -- Assume it was indeed turned in.
    if prev.state == DW.STATE_2_NEEDS_TURN_IN then
        local quest_status_turned_in = DW.QuestStatus:New()
        quest_status_turned_in.state = DW.STATE_3_TURNED_IN
        quest_status_turned_in.text  = ""
        quest_status_turned_in.ts    = GetTimeStamp()
        return quest_status_turned_in
    elseif prev.state == DW.STATE_3_TURNED_IN then
                        -- Latch "turned in"
        return prev
    end

                        -- It's gone, and last time we saw it the quest
                        -- needed more than just turning in. Not sure
                        -- what happened, assume we need to acquire it again.
    return nil
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
                        -- SURPRISE there is something broken in
                        -- alchemy writs right now, GetJournalQuestRepeatType()
                        -- and GetJournalQuestInfo() can return nothing but
                        -- 0/nil/"" for alchemy writs. Because ZOS hates me.

                        -- Only daily quests matter.
    local rt = GetJournalQuestRepeatType(quest_index)
    if rt ~= QUEST_REPEAT_DAILY then
        -- d(tostring(quest_index).." not daily "..tostring(rt))
        return
    end
                        -- Only daily CRAFTING quests matter.
    local qinfo = { GetJournalQuestInfo(quest_index) }
    if qinfo[DW.JQI.quest_type] ~= QUEST_TYPE_CRAFTING then
        -- d(  tostring(quest_index).." not crafting "
        --   ..tostring(qinfo[DW.JQI.quest_type])
        --   .." "..tostring(qinfo[DW.JQI.quest_name]) )
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
local DEBUG = function() end
--if (quest_index == 9) then DEBUG = function(x) d(x) end end

    local text_list = {}
    local state     = DW.STATE_1_NEEDS_CRAFTING

                        -- Accumulate quest's current status, which always seems to
                        -- be the status of the last/highest-indexed step.
    local step_ct = GetJournalQuestNumSteps(quest_index)
DEBUG("step_ct:"..tostring(step_ct))
    local step_index = step_ct
    local sinfo = { GetJournalQuestStepInfo(quest_index, step_index) }
DEBUG("GetJournalQuestStepInfo()")
DEBUG(sinfo)
-- d(sinfo)
    local condition_ct = sinfo[DW.JQSI.num_conditions]
    if condition_ct == 0 then -- It's already partially turned in, "Sign Delivery Manifest" time.
        state = DW.STATE_2_NEEDS_TURN_IN
    else
        for ci = 1, condition_ct do
            local cinfo = { GetJournalQuestConditionInfo(quest_index, step_index, ci) }
    DEBUG("Condition " .. tostring(ci))
    DEBUG(cinfo)
                            -- If we have not completed all the required counts
                            -- for this condition, then its text matters.
            if cinfo[DW.JQCI.is_visible]
                    and ( cinfo[DW.JQCI.current] < cinfo[DW.JQCI.max] ) then
                    local c_text = cinfo[DW.JQCI.condition_text]
                table.insert(text_list, c_text)
                state = DW.StateMax(state, self:ConditionTextToState(c_text))
            end
        end
    end

    local quest_status       = DW.QuestStatus:New()
    quest_status.state       = state
    quest_status.text        = table.concat(text_list, "\n")
    quest_status.acquired_ts = GetTimeStamp()
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

-- File I/O ------------------------------------------------------------------


function CharData:ReadSavedVariables()
    local saved = DW.savedVariables
    if not saved.char_data then return end
    local quest_status_list = {}
    for i, ct in ipairs(DW.CRAFTING_TYPE) do
        quest_status_list[i] = DW.QuestStatus:FromSaved(saved.char_data[i])
    end
    self.quest_status = quest_status_list
end

function CharData:WriteSavedVariables()
    local quest_status_list = {}
    for i, ct in ipairs(DW.CRAFTING_TYPE) do
        quest_status_list[i] = DW.QuestStatus:ToSaved(self.quest_status[i])
    end
    DW.savedVariables.char_data = quest_status_list
end

function DW.QuestStatus:FromSaved(saved)
    if not saved then return nil end
    local qs       = DW.QuestStatus:New()
    qs.state       = DW.STATE_ORDERED[saved.state]
    qs.text        = saved.text
    qs.acquired_ts = saved.acquired_ts
    return qs
end

function DW.QuestStatus:ToSaved(quest_status)
    if not quest_status then return nil end
    local saved = {   state       = quest_status.state.order
                  , text        = quest_status.text
                  , acquired_ts = quest_status.acquired_ts
                  }
    return saved
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
    self.savedVariables = ZO_SavedVars:New(
                              "ZZDailyWritsVars"
                            , self.savedVarVersion
                            , nil
                            , self.default
                            )

    DW.char_data:ReadSavedVariables()

    local event_id_list = { EVENT_QUEST_ADDED       -- 0 needs acquire -> 1 or 2
                          , EVENT_CRAFT_COMPLETED   -- 1 needs craft   -> 2
                          , EVENT_QUEST_COMPLETE    -- 2 needs turn in -> 3
                          }
    for _, event_id in ipairs(event_id_list) do
        EVENT_MANAGER:RegisterForEvent( DW.name
                                      , event_id
                                      , function()
                                            ZZDailyWrits.RefreshDataAndUI()
                                        end
                                      )
    end

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
        DW.RefreshDataAndUI()
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

-- Fetch current data. Display it.
function ZZDailyWrits.RefreshDataAndUI()
    DW.char_data:ScanJournal()
    DW.char_data:WriteSavedVariables()
    DW:DisplayCharData()
end

function DW:DisplayCharData()
    for _,ct in ipairs(DW.CRAFTING_TYPE) do
                        -- What state to display? Default to "acquire" if we
                        -- haven't recorded anything for this crafting type.
        local quest_status = self.char_data.quest_status[ct.order]
        local state        = DW.STATE_0_NEEDS_ACQUIRE
        if quest_status then
            state = quest_status.state
        end

        local ui_status = ZZDailyWritsUI:GetNamedChild("_status_"..ct.abbr)
        local ui_label  = ZZDailyWritsUI:GetNamedChild("_label_" ..ct.abbr)

        ui_status:SetText("|c"..state.color..state.id.."|r")
        ui_label:SetText( "|c"..state.color..ct.abbr .."|r")
    end
end

-- Postamble -----------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent( DW.name
                              , EVENT_ADD_ON_LOADED
                              , DW.OnAddOnLoaded
                              )

ZO_CreateStringId("SI_BINDING_NAME_DW_DoIt", "Show me")
