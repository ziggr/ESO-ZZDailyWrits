ZZDailyWrits = {}
local DW = ZZDailyWrits

DW.name            = "ZZDailyWrits"
DW.version         = "5.0.2"
DW.savedVarVersion = 2
DW.default         = { position  = {350,100}
                     , char_data = {}
                     }

local CAN_JEWELRY                   = ITEM_TRAIT_TYPE_JEWELRY_SWIFT or false
local CRAFTING_TYPE_JEWELRYCRAFTING = CRAFTING_TYPE_JEWELRYCRAFTING or 7

-- Sequence the writs in an order I prefer.
--
-- Use these values for craft_type
--
DW.CRAFTING_TYPE = {
  { abbr = "bs", order = 1, ct = CRAFTING_TYPE_BLACKSMITHING    }
, { abbr = "cl", order = 2, ct = CRAFTING_TYPE_CLOTHIER         }
, { abbr = "ww", order = 3, ct = CRAFTING_TYPE_WOODWORKING      }
, { abbr = "jw", order = 4, ct = CRAFTING_TYPE_JEWELRYCRAFTING  }
, { abbr = "al", order = 5, ct = CRAFTING_TYPE_ALCHEMY          }
, { abbr = "en", order = 6, ct = CRAFTING_TYPE_ENCHANTING       }
, { abbr = "pr", order = 7, ct = CRAFTING_TYPE_PROVISIONING     }
}

local DWUI = nil

local COLOR = {
    ["TEAL"     ] = "66AABB"
,   ["RED"      ] = "FF3333"
,   ["GREEN"    ] = "33FF33"
,   ["GREY"     ] = "AAAAAA"
,   ["DARK_GREY"] = "333333"
,   ["ORANGE"   ] = "FF8800"
}

-- Quest states --------------------------------------------------------------

                        -- Not started
                        -- Need to visit a billboard to acquire quest.
DW.STATE_0_NEEDS_ACQUIRE    = { id = "acquire", order = 0, color = COLOR.TEAL }

                        -- Acquired, but at least one item needs to be
                        -- crafted before turnining in.
                        -- Need to visit a crafting station to
                        -- make things.
DW.STATE_1_NEEDS_CRAFTING   = { id = "craft",   order = 1, color = COLOR.RED      }

                        -- Crafting of all items completed.
                        -- Need to visit turn-in station.
DW.STATE_2_NEEDS_TURN_IN    = { id = "turn in", order = 2, color = COLOR.GREEN }

                        -- Quest completed. Done for the day.
DW.STATE_3_TURNED_IN        = { id = "done",    order = 3, color = COLOR.GREY }

                        -- Quest does not exist on this server or character.
DW.STATE_X_IMPOSSIBLE       = { id = "n/a",     order = 9, color = COLOR.DARK_GREY }
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
    local quest_ct      = GetNumJournalQuests()
    local seen_quest_ct = 0
    local quest_status  = {}
    local ct_to_qi      = {}
    for qi = 1, MAX_JOURNAL_QUESTS do
        local x = self:AbsorbQuest(qi)
        if x then
            quest_status[x.crafting_type.order] = x.quest_status
            ct_to_qi[x.crafting_type.ct] = qi
                        -- +++ Early-exit loop once we've seen
                        -- +++ all the quests in the journal.
            seen_quest_ct = seen_quest_ct + 1
            if quest_ct <= seen_quest_ct then break end
        end
    end
                        -- Merge with previous quest_status list here
                        -- to detect "needs turn-in" -> "turned in" edge.
    for i, ct in ipairs(DW.CRAFTING_TYPE) do
        local prev_state = self.quest_status[i].state
        self.quest_status[i] = self:StateTransition( self.quest_status[i]
                                                    , quest_status[i]
                                                    , ct )
                        -- If we just transitioned into "Needs crafting"
                        -- then now would be a great time to automatically
                        -- queue up that crafting.
        local new_state = self.quest_status[i].state
        if (new_state == DW.STATE_1_NEEDS_CRAFTING)
                and (prev_state ~= new_state) then
            self:EnqueueCrafting(ct.ct, ct_to_qi[ct.ct])
        end

                        -- If we just transitioned into "Needs crafting"
                        -- or "Turn In", now would be a good time to show
                        -- our window so that we can see that without
                        -- forcing Zig to tap F9/Toggle Window.
        if     new_state == DW.STATE_1_NEEDS_CRAFTING
            or new_state == DW.STATE_2_NEEDS_TURN_IN then
            zo_callLater(function() DW.ShowWindow() end, 250)
        end
    end
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

-- State transition table
-- Inputs: previous state        ACQR CRFT TURN DONE
--         current state         ACQR CRFT TURN     (curr=DONE is impossible)
--
-- Outputs: next state           PREV CURR DONE
--          use which timestamp  PREV CURR
--
-- Special case:prev=DONE curr=ACQR must check prev.ts against reset time.

-- For less typing
local ACQR = tostring(DW.STATE_0_NEEDS_ACQUIRE.order)
local CRFT = tostring(DW.STATE_1_NEEDS_CRAFTING.order)
local TURN = tostring(DW.STATE_2_NEEDS_TURN_IN.order)
local DONE = tostring(DW.STATE_3_TURNED_IN.order)

local PREV = "p"
local CURR = "c"
local CKTS = "t"                    -- Special case "check prev.ts"

DW.STATE_TRANSITION = {
                                    -- Note that curr=DONE is impossible.
                                    -- Only this transition table can create "DONE".
  [ ACQR .. DONE ] = PREV .. PREV
, [ CRFT .. DONE ] = PREV .. PREV
, [ TURN .. DONE ] = PREV .. PREV
, [ DONE .. DONE ] = PREV .. PREV

                                    -- No state change, still have not started.
                                    -- Might as well retain prev ts, too.
, [ ACQR .. ACQR ] = PREV .. PREV
, [ CRFT .. CRFT ] = PREV .. PREV
, [ TURN .. TURN ] = PREV .. PREV

                                    -- Main intended state sequence, we just acquired
                                    -- the quest. Use time stamp from this edge.
, [ ACQR .. CRFT ] = CURR .. CURR
, [ ACQR .. TURN ] = CURR .. CURR


                                    -- Main intended state sequence.
                                    -- Retain original acquisition ts as
                                    -- we roll through ACQR->CRFT->TURN->DONE.
, [ CRFT .. TURN ] = CURR .. PREV
, [ CRFT .. ACQR ] = CURR .. PREV


                                    -- Main intended state sequence.
                                    -- Retain original acquisition ts as
                                    -- we roll through ACQR->CRFT->TURN->DONE.
, [ TURN .. ACQR ] = DONE .. PREV

                                    -- Missed a state change when turned in
                                    -- (or abandoned!) the quest.
                                    -- curr ts is close enough. Might be wrong sometimes
                                    -- but hey that's what happens when you transition
                                    -- states without this add-on watching.
, [ TURN .. CRFT ] = CURR .. CURR

                                    -- Missed the DONE->ACQR state change which
                                    -- seems quite likely if we haven't updated
                                    -- since the reset time. Jump to the newly
                                    -- acquired quest's time.
, [ DONE .. CRFT ] = CURR .. CURR
, [ DONE .. TURN ] = CURR .. CURR

                                    -- prev=DONE is the only time where prev.ts
                                    -- matters. ts_old is how we know to change from
                                    -- DONE to ACQR, or latch DONE while ts_new.
, [ DONE .. ACQR ] = CKTS .. CKTS
}

-- Once a quest vanishes from our list, assume it was turned in.
-- crafting_type is here solely for debugging.
function CharData:StateTransition(prev, curr, crafting_type)
    local sprev    = CharData:SafeStatus(prev)
    local scurr    = CharData:SafeStatus(curr)
    local prev_c   = tostring(sprev.state.order)
    local curr_c   = tostring(scurr.state.order)
    local input_cc = prev_c .. curr_c

    local next_state_cc = DW.STATE_TRANSITION[input_cc]
    local next_state_c  = next_state_cc:sub(1,1)
    local next_acq_ts_c = next_state_cc:sub(2,2)

                        -- Nur zum Debuggen.
    -- if next_state_c == CKTS then
    --     if sprev.acquired_ts == 0 then
    --         tt_disp = " prev.ts = 0"
    --     elseif sprev.acquired_ts < self:ResetTS() then
    --         tt_disp = " prev.ts = old"
    --     else
    --         tt_disp = " prev.ts = new"
    --     end
    -- else
    --     tt_disp = " "
    -- end
    -- d(crafting_type.abbr.." "..input_cc.." ==> "..tostring(next_state_cc)..tt_disp)

                        -- Get special case out of the way so that the rest
                        -- of this function can be simpler.
    if next_state_c == CKTS then
        if prev.acquired_ts < self:ResetTS() then
            return scurr
        else
            return sprev
        end
    end

    local next_status   = nil
    if next_state_c == PREV then
        next_status = sprev
    elseif next_state_c == CURR then
        next_status = scurr
    elseif next_state_c == DONE then
        next_status = sprev
        next_status.state = DW.STATE_3_TURNED_IN
    end

    if next_acq_ts_c == PREV then
        next_status.acquired_ts = sprev.acquired_ts
    elseif next_acq_ts_c == CURR then
        next_status.acquired_ts = scurr.acquired_ts
    end

    return next_status
end

-- nil quest statuses are common, but make the above StateTransition code cry.
-- Replace nil with acquire.
function CharData:SafeStatus(quest_status)
    if quest_status then return quest_status end
    return DW.QuestStatus:New()
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
    local qinfo         = { GetJournalQuestInfo(quest_index) }
    local quest_name    = qinfo[DW.JQI.quest_name]
    local crafting_type = LibCraftText.DailyQuestNameToCraftingType(quest_name)
    if not crafting_type then return end

                        -- Find correct index into CharData.quest_status[]
    local crafting_type_row = nil
    for _,c in pairs(DW.CRAFTING_TYPE) do
        if c.ct == crafting_type then
            crafting_type_row = c
            break
        end
    end
                        -- Accumulate conditions into a quest_status.
    local quest_status = self:AccumulateCondition(quest_index)
    return { crafting_type = crafting_type_row
           , quest_status  = quest_status
           }
end

-- Return a quest's conditions as a single QuestStatus instance.
function CharData:AccumulateCondition(quest_index)
    local DEBUG = function() end
    local text_list = {}
    local state     = DW.STATE_1_NEEDS_CRAFTING

                        -- Accumulate quest's current status, which always seems to
                        -- be the status of the last/highest-indexed step.
    local step_ct = GetJournalQuestNumSteps(quest_index)

                        -- Ignore final step if it is one of Update 17/Dragon Bones
                        -- "Brewers and Cooks Can Provide Recipes" hints as a step.
    if self:IsUpdate17RecipeStep(quest_index, step_ct) then
        DEBUG("skipping 'Brewers have recipes' step_index:"..tostring(step_ct))
        step_ct = step_ct - 1
    end

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

-- Update 17 introduced "Brewers and Cooks Can Provide Recipes" hints
-- as pseudo-conditions. This hint appears even if the quest is completed.
-- Sometimes. And really screws up our "do we need to craft this or not?" logic.
function CharData:IsUpdate17RecipeStep(quest_index, step_index)
    local sinfo = { GetJournalQuestStepInfo(quest_index, step_index) }
    local condition_ct = sinfo[DW.JQSI.num_conditions]
    for ci = 1, condition_ct do
        local cinfo = { GetJournalQuestConditionInfo(quest_index, step_index, ci) }
        local c_text = cinfo[DW.JQCI.condition_text]
        -- local says_recipes = string.find(c_text:lower(), "recipes")
        local says_recipes = c_text == LibCraftText.DAILY.COND.HINT_PR_BREWERS_COOKS_RECIPES
        if says_recipes then return true end
    end
    return false
end

-- If a crafting quest exists in the journal, it either needs to be
-- crafted, or needs to be turned in.
function CharData:ConditionTextToState(condition_text)
    local says_deliver = string.find(condition_text
                            , LibCraftText.DAILY.COND.DELIVER_GOODS_SUBSTRING)
    if says_deliver then
        return DW.STATE_2_NEEDS_TURN_IN
    end

    DW.log.Debug(condition_text)
    return DW.STATE_1_NEEDS_CRAFTING
end

function CharData.ToDolCell(info, display_string)
    local is_known = true
    return { info
           , display_string
           , is_known
           }
end

local REJERA = 64509
local OKO    = 45831
local DENI   = 45833
local MAKKO  = 45832
local TA     = 45850

local NAME = { [REJERA] = "Rejera"
             , [OKO   ] = "Oko"
             , [DENI  ] = "Deni"
             , [MAKKO ] = "Makko"
             , [TA    ] = "Ta"
             }


function ZZDailyWrits.GetLLC()
    local self = ZZDailyWrits
    if self.LibLazyCrafting then return self.LibLazyCrafting end

    local lib = LibStub:GetLibrary("LibLazyCrafting")
    self.LibLazyCrafting_lib = lib
    self.LibLazyCrafting = lib:AddRequestingAddon(
         self.name                    -- name
       , true                         -- autocraft
       , ZZDailyWrits.LLCCompleted    -- functionCallback
       )
    return self.LibLazyCrafting
end

function DW.CycleCt()
    if not DW.savedVariables.enable then
        return 0
    end
    return math.floor( (self.savedVariables.days_to_craft or 0) / 3 )
end

-- We've just switched from "acquire" to "needs crafting".
-- Now would be an excellent time to enqueue items for crafting.
--
-- crafting_type is CRAFTING_TYPE_XXX
function CharData:EnqueueCrafting(crafting_type, quest_index)
    local cycle_ct = DW.CycleCt()
    if not cycle_ct or cycle_ct <= 0 then
        return
    end

    if crafting_type == CRAFTING_TYPE_BLACKSMITHING then
        local q = {
          { count = cycle_ct, pattern_index =  3, name = "1h sword"      , weight_name = "heavy", link="|H1:item:43531:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:0:0|h|h" }
        , { count = cycle_ct, pattern_index =  6, name = "2h g.sword"    , weight_name = "heavy", link="|H1:item:43534:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:0:0|h|h" }
        , { count = cycle_ct, pattern_index =  7, name = "dagger"        , weight_name = "heavy", link="|H1:item:43535:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:0:0|h|h" }
        , { count = cycle_ct, pattern_index =  8, name = "chest"         , weight_name = "heavy", link="|H1:item:43537:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index =  9, name = "feet"          , weight_name = "heavy", link="|H1:item:43538:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index = 10, name = "hands"         , weight_name = "heavy", link="|H1:item:43539:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index = 11, name = "head"          , weight_name = "heavy", link="|H1:item:43562:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index = 12, name = "legs"          , weight_name = "heavy", link="|H1:item:43540:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index = 13, name = "shoulders"     , weight_name = "heavy", link="|H1:item:43541:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        }
        local constants = {
          station     = CRAFTING_TYPE_BLACKSMITHING
        }
        self:RemoveIfAlreadyInBag(q, constants)
        self:LLC_Enqueue(q, constants)
    elseif crafting_type == CRAFTING_TYPE_CLOTHIER then
        local q = {
          { count = cycle_ct, pattern_index =  1, name = "chest"         , weight_name = "light"  , link="|H1:item:43543:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index =  3, name = "feet"          , weight_name = "light"  , link="|H1:item:43544:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index =  5, name = "head"          , weight_name = "light"  , link="|H1:item:43564:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index =  6, name = "legs"          , weight_name = "light"  , link="|H1:item:43546:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index =  7, name = "shoulders"     , weight_name = "light"  , link="|H1:item:43547:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index =  8, name = "waist"         , weight_name = "light"  , link="|H1:item:43548:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index = 11, name = "hands"         , weight_name = "medium" , link="|H1:item:43552:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index = 12, name = "head"          , weight_name = "medium" , link="|H1:item:43563:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        , { count = cycle_ct, pattern_index = 14, name = "shoulders"     , weight_name = "medium" , link="|H1:item:43554:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h" }
        }
        local constants = {
          station     = CRAFTING_TYPE_CLOTHIER
        }
        self:RemoveIfAlreadyInBag(q, constants)
        self:LLC_Enqueue(q, constants)
    elseif crafting_type == CRAFTING_TYPE_WOODWORKING then
        local q = {
          { count = cycle_ct * 2, pattern_index =  1, name = "bow"           , weight_name = "wood" , link="|H1:item:43549:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:0:0|h|h"  }
        , { count = cycle_ct    , pattern_index =  3, name = "flame"         , weight_name = "wood" , link="|H1:item:43557:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:0:0|h|h"  }
        , { count = cycle_ct    , pattern_index =  4, name = "ice"           , weight_name = "wood" , link="|H1:item:43558:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:0:0|h|h"  }
        , { count = cycle_ct    , pattern_index =  5, name = "shock"         , weight_name = "wood" , link="|H1:item:43559:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:0:0|h|h"  }
        , { count = cycle_ct * 2, pattern_index =  6, name = "resto"         , weight_name = "wood" , link="|H1:item:43560:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:0:0|h|h"  }
        , { count = cycle_ct * 2, pattern_index =  2, name = "shield"        , weight_name = "wood" , link="|H1:item:43556:308:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h"  }
        }
        local constants = {
          station     = CRAFTING_TYPE_WOODWORKING
        }
        self:RemoveIfAlreadyInBag(q, constants)
        self:LLC_Enqueue(q, constants)
    elseif crafting_type == CRAFTING_TYPE_JEWELRYCRAFTING then
        local jw_mult = math.max(3,cycle_ct)
        local q = {
          { count = jw_mult * 3, pattern_index =  2, name = "necklace"      , weight_name = "jewelry" , link="|H1:item:43561:308:50:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:0|h|h"  }
        , { count = jw_mult * 4, pattern_index =  1, name = "ring"          , weight_name = "jewelry" , link="|H1:item:43536:308:50:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:0|h|h"  }
        }
        local constants = {
          station     = CRAFTING_TYPE_JEWELRYCRAFTING
        }

        self:RemoveIfAlreadyInBag(q, constants)
        self:LLC_Enqueue(q, constants)

    elseif crafting_type == CRAFTING_TYPE_ENCHANTING then
        local en_mult = math.max(3,cycle_ct)
        local q = {
          { count = en_mult, potency = REJERA, essence = DENI  , aspect = TA , link="|H1:item:26588:308:50:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:0|h|h" }
        , { count = en_mult, potency = REJERA, essence = MAKKO , aspect = TA , link="|H1:item:26582:308:50:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:0|h|h" }
        , { count = en_mult, potency = REJERA, essence = OKO   , aspect = TA , link="|H1:item:26580:308:50:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:0|h|h" }
        }
        local constants = {
          station     = CRAFTING_TYPE_ENCHANTING
        }
        self:RemoveIfAlreadyInBag(q, constants)
        self:LLC_Enqueue(q, constants)
    elseif crafting_type == CRAFTING_TYPE_PROVISIONING then
        local cond_list = LibCraftText.ParseQuest(quest_index)
        local queued_ct = 0
        for _,parse in ipairs(cond_list) do
            if      parse.item
                and parse.item.recipe_list_index
                and parse.item.recipe_index then
                local q = { { count             = cycle_ct
                            , recipe_list_index = parse.item.recipe_list_index
                            , recipe_index      = parse.item.recipe_index
                            }
                          }
                local constants = {
                  station     = CRAFTING_TYPE_PROVISIONING
                }
                self:LLC_Enqueue(q, constants)
                queued_ct = queued_ct + 1
            end
        end
        if queued_ct <= 0 then
            d("Autoqueue skipped: PR writ not parsed.")
        end
        elseif crafting_type == CRAFTING_TYPE_ALCHEMY then
            local cond_list = LibCraftText.ParseQuest(quest_index)
            for _,parse in ipairs(cond_list) do
                if parse.trait and parse.solvent then
                    local m = LibCraftText.MATERIAL -- for less typing
                        -- Pairs of reagents that I know will produce the right
                        -- potion/poison name. There are many more pairs, could
                        -- swap in different ones if these start to become rare
                        -- or expensive

                    local REAGENT = {
                        [01] = { m.BLUE_ENTOLOMA    , m.LUMINOUS_RUSSULA } -- "Restore Health"
                    ,   [02] = { m.EMETIC_RUSSULA   , m.NIRNROOT         } -- "Ravage Health"
                    ,   [03] = { m.CORN_FLOWER      , m.BUGLOSS          } -- "Restore Magicka"
                    ,   [04] = { m.EMETIC_RUSSULA   , m.BLUE_ENTOLOMA    } -- "Ravage Magicka"
                    ,   [05] = { m.DRAGONTHORN      , m.MOUNTAIN_FLOWER  } -- "Restore Stamina"
                    ,   [06] = { m.STINKHORN        , m.FLESHFLY_LARVA   } -- "Ravage Stamina"
                    }
                    local reagent = REAGENT[parse.trait.trait_index]

                        -- Make 16x potions (4 crafts of 4x) or 16x poisons (1 craft of 16x)
                    local count   = 1
                    if parse.solvent == LibCraftText.MATERIAL.ALKAHEST then
                        count = 1
                    end
                    if cycle_ct <= 0 then count = 0 end
                    local q = { { count    = count
                                , solvent  = parse.solvent.item_id
                                , reagent1 = reagent[1].item_id
                                , reagent2 = reagent[2].item_id
                                } }
                    local constants = {
                      station     = CRAFTING_TYPE_ALCHEMY
                    }
                    self:LLC_Enqueue(q, constants)
                end
            end
    end
end

function DW.MaskedLink(orig, mask)
    local orig_w = {zo_strsplit(':', orig)}
    local mask_w = {zo_strsplit(':', mask)}
    local result_w = {}
    for i,o in ipairs(orig_w) do
        if (mask_w[i] ~= "0") then
            table.insert(result_w, o)
        else
            table.insert(result_w, "0")
        end
    end
    local result = table.concat(result_w,":")
    return result
end

-- Scan inventory for all matching items, remove from q.
--
-- I got sick of crafting a full 3 days' worth of stuff when I had at least
-- 1 day's worth of stuff already sitting in my bag.
function CharData:RemoveIfAlreadyInBag(q, constants)
    local supported = {
      [CRAFTING_TYPE_BLACKSMITHING   ] = true
    , [CRAFTING_TYPE_CLOTHIER        ] = true
    , [CRAFTING_TYPE_WOODWORKING     ] = true
    , [CRAFTING_TYPE_JEWELRYCRAFTING ] = true
    , [CRAFTING_TYPE_ALCHEMY         ] = false
    , [CRAFTING_TYPE_ENCHANTING      ] = true
    , [CRAFTING_TYPE_PROVISIONING    ] = false
    }
    if not supported[constants.station] then return end

    -- see https://en.uesp.net/wiki/Online:Item_Link
    --
    -- fields 1-3 = whatcha making
    -- field  16  = motif, don't care!
    -- field  17  = crafted?
    --                       1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    local mask   = "|H1:item:1:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:0|h|h"

                        -- How many of these things did you want?
    local counts = {}
    for _,qi in ipairs(q) do
        if qi.link then
            local masked_link = DW.MaskedLink(qi.link, mask)
            counts[masked_link] = counts[masked_link] or { want = 0, have = 0 }
            counts[masked_link].want = counts[masked_link].want + qi.count or 1
        end
    end

                        -- How many of these do we have?
    local bag_id = BAG_BACKPACK
    local slot_ct = GetBagSize(bag_id)
    for slot_index = 0, slot_ct do
        local inv_link = GetItemLink(bag_id, slot_index, LINK_STYLE_BRACKETS)
        local inv_masked     = DW.MaskedLink(inv_link, mask)
        if counts[inv_masked] then
            counts[inv_masked].have = 1 + (counts[inv_masked].have or 0)
            d("Found: "..inv_link)
        end
    end

                        -- Reduce or remove queued requests that already
                        -- have 1 or more resulting items  in inventory.
    for i = #q,1,-1 do
        local qi = q[i]
        if qi.link then
            local masked_link = DW.MaskedLink(qi.link, mask)
            local count_elem  = counts[masked_link]
            -- d(qi.link)
            if count_elem then
                if count_elem.want <= count_elem.have then
                    table.remove(q,i)
                    d("Removed all: "..qi.link)
                elseif (0 < count_elem.have) then
                    qi.count = count_elem.want - count_elem.have
                    d("Removed "..tostring(count_elem.have)
                      ..", left "..tostring(qi.count)..": "..qi.link)
                end
            end
        end
    end
end

function CharData:LLC_Enqueue(q, constants)
    local queued_ct = 0
    local llc = ZZDailyWrits.GetLLC()
    for _, qe in ipairs(q) do
        for i = 1, qe.count do
            local dol_request = self:LLC_ToOneRequest(qe, constants)
            local o = dol_request.CraftRequestTable
            llc[dol_request.llc_func](llc, unpack(o))
            queued_ct = queued_ct + 1
        end
    end
    d("Autoqueued "..tostring(queued_ct).." requests")
end

local function FindMaxStyleMat()
    local pool = { { style = ITEMSTYLE_RACIAL_HIGH_ELF , link = "|H0:item:33252:30:50:0:0:0:0:0:0:0:0:0:0:0:0:7:0:0:0:0:0|h|h"  , name = "adamantite" }
                 , { style = ITEMSTYLE_RACIAL_BRETON   , link = "|H0:item:33251:30:13:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:0:0|h|h"  , name = "molybdenum" }
                 , { style = ITEMSTYLE_RACIAL_ORC      , link = "|H0:item:33257:30:50:0:0:0:0:0:0:0:0:0:0:0:0:3:0:0:0:0:0|h|h"  , name = "manganese"  }
                 , { style = ITEMSTYLE_RACIAL_REDGUARD , link = "|H0:item:33258:30:0:0:0:0:0:0:0:0:0:0:0:0:0:2:0:0:0:0:0|h|h"   , name = "starmetal"  }
                 , { style = ITEMSTYLE_RACIAL_WOOD_ELF , link = "|H0:item:33194:30:0:0:0:0:0:0:0:0:0:0:0:0:0:8:0:0:0:0:0|h|h"   , name = "bone"       }
                 , { style = ITEMSTYLE_RACIAL_NORD     , link = "|H0:item:33256:30:0:0:0:0:0:0:0:0:0:0:0:0:0:5:0:0:0:0:0|h|h"   , name = "corundum"   }
                 , { style = ITEMSTYLE_RACIAL_DARK_ELF , link = "|H0:item:33253:30:0:0:0:0:0:0:0:0:0:0:0:0:0:4:0:0:0:0:0|h|h"   , name = "obsidian"   }
                 , { style = ITEMSTYLE_RACIAL_ARGONIAN , link = "|H0:item:33150:30:0:0:0:0:0:0:0:0:0:0:0:0:0:6:0:0:0:0:0|h|h"   , name = "flint"      }
                 , { style = ITEMSTYLE_RACIAL_KHAJIIT  , link = "|H0:item:33255:30:50:0:0:0:0:0:0:0:0:0:0:0:0:9:0:0:0:0:0|h|h"  , name = "moonstone"  }
                 -- , { style = ITEMSTYLE_ENEMY_PRIMITIVE , link = "|H0:item:46150:30:16:0:0:0:0:0:0:0:0:0:0:0:0:19:0:0:0:0:0|h|h" , name = "argentum"   }
                 -- , { style = ITEMSTYLE_AREA_REACH      , link = "|H0:item:46149:30:23:0:0:0:0:0:0:0:0:0:0:0:0:17:0:0:0:0:0|h|h" , name = "copper"     }
                 -- , { style = ITEMSTYLE_AREA_ANCIENT_ELF, link = "|H0:item:46152:30:0:0:0:0:0:0:0:0:0:0:0:0:0:15:0:0:0:0:0|h|h"  , name = "palladium"  }
                 -- , { style = ITEMSTYLE_RACIAL_IMPERIAL , link = "|H0:item:33254:30:50:0:0:0:0:0:0:0:0:0:0:0:0:34:0:0:0:0:0|h|h" , name = "nickel"     }
                 }
    local max_element = nil
    local max_ct      = 0
    for _, element in ipairs(pool) do
        local backpack_ct, bank_ct, craft_bag_ct = GetItemLinkStacks(element.link)
        local inv_ct = backpack_ct + bank_ct + craft_bag_ct
        if max_ct < inv_ct then
            max_element = element
            max_ct      = inv_ct
        end
    end
    d("style mat_ct:"..tostring(max_ct).."  "..max_element.name)
    return max_element.style
end

function CharData:MaxStyleMat()
    self.max_style = self.max_style or FindMaxStyleMat()
    return self.max_style
end

-- Return a single item, as a structure suitable for enqueuing with
-- Dolgubon's Lazy Set Crafter.
function CharData:LLC_ToOneRequest(qe, constants)
    DW.savedVariables.counter = (DW.savedVariables.counter or 0) + 1
    local reference = DW.savedVariables.counter

                        -- Is it a Smithing request? They all follow the same
                        -- format.
    local sm = { [CRAFTING_TYPE_BLACKSMITHING   ] = 1
               , [CRAFTING_TYPE_CLOTHIER        ] = 1
               , [CRAFTING_TYPE_WOODWORKING     ] = 1
               , [CRAFTING_TYPE_JEWELRYCRAFTING ] = 1
               }
    if sm[constants.station] then
                        -- API struct passed to LibLazyCrafter for
                        -- eventual crafting.
        local o = {}
        o.patternIndex = qe.pattern_index
        o.isCP         = true
        o.level        = 150
        o.styleIndex   = CharData:MaxStyleMat()
        o.traitIndex   = 0                       + 1
        o.useUniversalStyleItem = false
        o.station      = constants.station
        o.setIndex     = 1 -- no set
        o.quality      = 1 -- white
        o.autocraft    = true
        o.reference    = reference

        if constants.station == CRAFTING_TYPE_JEWELRYCRAFTING then
            o.styleIndex = nil
        end

                        -- Positional arguments to LibLazyCrafter:CraftSmithingItemByLevel()
        local craft_request_table = {
          o.patternIndex            --  1
        , o.isCP                    --  2
        , o.level                   --  3
        , o.styleIndex              --  4
        , o.traitIndex              --  5
        , o.useUniversalStyleItem   --  6
        , o.station                 --  7
        , o.setIndex                --  8
        , o.quality                 --  9
        , o.autocraft               -- 10
        , o.reference               -- 11
        }
                        -- UI row with user-visible strings.
                        -- This is just for display, so okay if strings
                        -- mismatch something Dolgubon would supply. (For
                        -- example, Dolgubon has a private shortening function
                        -- to say "Seducer" instead of "Armor of the Seducer",
                        -- but we don't get to call this.)
        local C = CharData.ToDolCell   -- for less typing
        local request_table = {}
        request_table.Pattern           = C(o.patternIndex    , qe.name        )
        request_table.Weight            = C(1                 , qe.weight_name )
        request_table.Trait             = C(o.traitIndex      , "none"         )
        request_table.Level             = C(150               , "CP150"        )
        if o.styleIndex then
            request_table.Style         = C(o.styleIndex + 1  , "Breton"       )
        end
        request_table.Set               = C(o.setIndex        , "none"         )
        request_table.Quality           = C(o.quality         , "white"        )
        request_table.Reference         =   reference
        request_table.CraftRequestTable =   craft_request_table
        request_table.llc_func          = "CraftSmithingItemByLevel"
        return request_table
    elseif constants.station == CRAFTING_TYPE_ENCHANTING then
        local craft_request_table = {
          qe.potency   -- 1
        , qe.essence   -- 2
        , qe.aspect    -- 3
        , true         -- autocraft
        , reference    -- reference
        }

        local C = CharData.ToDolCell   -- for less typing
        local request_table = {}
        request_table.Reference         =   reference
        request_table.CraftRequestTable =   craft_request_table
        request_table.llc_func          = "CraftEnchantingItemId"
        return request_table
    elseif constants.station == CRAFTING_TYPE_PROVISIONING then
        local craft_request_table = {
          qe.recipe_list_index  -- 1
        , qe.recipe_index       -- 2
        , 1                     -- 3 timesToMake, do NOT use qe.count here,
                                --   we already loop that outside of this function.
        , true                  -- 4 autocraft
        , reference             -- 5 reference
        }
        local request_table = {}
        request_table.Reference         =   reference
        request_table.CraftRequestTable =   craft_request_table
        request_table.llc_func          = "CraftProvisioningItemByRecipeIndex"
        return request_table
    elseif constants.station == CRAFTING_TYPE_ALCHEMY then
        local craft_request_table = {
          qe.solvent      -- 1 solventId
        , qe.reagent1     -- 2 reagentId1
        , qe.reagent2     -- 3 reagentId2
        , nil             -- 4 reagentId3 (optional, nilable)
        , 1               -- 5 timesToMake
        , true            -- 6 autoCraft
        , reference       -- 7 reference
        }
        local request_table             = {}
        request_table.Reference         = reference
        request_table.CraftRequestTable = craft_request_table
        request_table.llc_func          = "CraftAlchemyItemId"
        return request_table
    end

    d("ZZDailyWrits bug: unsupported station:"..tostring(constants.station))
end

-- REQUIRES THAT WE START MANAGING OUR OWN DAMN LLC QUEUE
--
-- Callback from LibLazyCrafting into our code upon completion of a single
-- queued request.
--  - event is "success" or "not enough mats" or some other string.
--          We COULD key off of "success" and display error redness if fail.
--  - llc_result is a table with bag/slot id of the crafted item and
--          its unique_id reference.
--  - station is often nil for many events, including LLC_NO_FURTHER_CRAFT_POSSIBLE.
function ZZDailyWrits.LLCCompleted(event, station, llc_result)
                        -- Just finished crafting at this station.
                        -- Auto-exit the station so that we can move on.
    if      event == LLC_NO_FURTHER_CRAFT_POSSIBLE
        and ZZDailyWrits.auto_exit_soon then
        ZZDailyWrits.auto_exit_soon = nil
        SCENE_MANAGER:ShowBaseScene()
        return
    end
                        -- Avoid auto-exiting immediately after connecting
                        -- to a station that LLC cannot craft anything for.
                        -- That would be super-annoying.
    if event == LLC_CRAFT_SUCCESS then
        ZZDailyWrits.auto_exit_soon = true
        return
    end
end

-- Why 13x Hearty Garlic Corn Chowder (rli:3 ri:40) and 16x Markarth Mead (rli:8 ri:42)?
-- function ZZTest()
--     DolgubonGlobalDebugOutput = d
--     local q = { { recipe_list_index = 8
--                 , recipe_index      = 42
--                 , count             = 4
--               } }
--     local constants = { station = CRAFTING_TYPE_PROVISIONING }
--     CharData:LLC_Enqueue(q, constants)
-- end
-- SLASH_COMMANDS["/zz"] = ZZTest

-- Inventory -----------------------------------------------------------------

DW.MATERIAL = {
  ["RUBEDITE      "] = { inventory_ct = nil
                       , required_ct  = 348
                       , label        = "hvy"
                       , link = "|H0:item:64489:30:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
                       }
, ["ANCESTOR_SILK "] = { inventory_ct = nil
                       , required_ct  = 243
                       , label        = "lgt"
                       , link = "|H0:item:64504:30:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
                       }
, ["RUBEDO_LEATHER"] = { inventory_ct = nil
                       , required_ct  = 117
                       , label        = "med"
                       , link = "|H0:item:64506:30:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
                       }
, ["RUBY_ASH      "] = { inventory_ct = nil
                       , required_ct  = 336
                       , label        = "ww"
                       , link = "|H0:item:64502:30:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
                       }
, ["PLATINUM      "] = { inventory_ct = nil
                       , required_ct  = 255
                       , label        = "jw"
                       , link = "|H0:item:135146:30:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
                       }
}

function DW.ScanInventory()
    local inventory = {}
    for key,mat in pairs(DW.MATERIAL) do
        local ct_list = { GetItemLinkStacks(mat.link)}
        local ct = 0
        for _,c in ipairs(ct_list) do ct = ct + c end
        mat.inventory_ct = ct
    end
    return inventory
end

function DW.ScanQueue()
    if not DW.GetLLC().personalQueue then return end
    local ct = {}
    for ctype,queue in pairs(DW.GetLLC().personalQueue) do
        ct[ctype] = #queue
    end
    DW.queued_ct = ct
end

-- File I/O ------------------------------------------------------------------

function CharData:ReadSavedVariables()
    local saved = DW.savedVariables
    if not saved.char_data then return end
    local quest_status_list = {}
    for i, ct in ipairs(DW.CRAFTING_TYPE) do
        quest_status_list[i] = DW.QuestStatus:FromSaved(saved.char_data[i]) or DW.QuestStatus:New()
    end
    self.quest_status = quest_status_list
end

function CharData:WriteSavedVariables()
    local quest_status_list = {}
    for i, ct in ipairs(DW.CRAFTING_TYPE) do
        quest_status_list[i] = DW.QuestStatus:ToSaved(self.quest_status[i], ct)
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

-- crafting_type is solely for debugging, its abbr written to SavedVariables
-- to make them easier for humans to read.
function DW.QuestStatus:ToSaved(quest_status, crafting_type)
    if not quest_status then return nil end
    local saved = { state       = quest_status.state.order
                  , text        = quest_status.text
                  , acquired_ts = quest_status.acquired_ts
                  , abbr        = crafting_type.abbr
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

DW.log = LibDebugLogger.Create(self.name)

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
                          , EVENT_QUEST_REMOVED     -- n anything --> 0 acquire or 4 done
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

    self.CreateSettingsWindow()
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

function DW.ShowWindow()
    ui = DWUI
    if not ui then
        d("No UI")
        return
    end
    local h = DWUI:IsHidden()
    if h then
        DW:RestorePos()
        DWUI:SetHidden(not h)
    end
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
    DW.ScanInventory()
    DW.ScanQueue()
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

                        -- HACK until Summerset is released:
                        -- Sick of blue "needs acquire" text on
                        -- jewelry line.
                        --
                        -- Inserting the hack as shallow as possible, just
                        -- at the UI display point.
        if (not CAN_JEWELRY) and ct.abbr == "jw" then
            state = DW.STATE_X_IMPOSSIBLE
        end

        local q_ct      = "??"
        if DW.queued_ct and 0 < DW.queued_ct[ct.ct] then
            q_ct = tostring(DW.queued_ct[ct.ct])
        else
            q_ct = ""
        end

        local ui_status = ZZDailyWritsUI:GetNamedChild("_status_"..ct.abbr)
        local ui_label  = ZZDailyWritsUI:GetNamedChild("_label_" ..ct.abbr)
        local ui_q      = ZZDailyWritsUI:GetNamedChild("_q_"     ..ct.abbr)

        ui_status:SetText("|c"..state.color..state.id.."|r")
        ui_label:SetText ("|c"..state.color..ct.abbr .."|r")
        ui_q:SetText     ("|c"..state.color..q_ct    .."|r")
    end

                        -- Inventory
    for mat_name, mat in pairs(DW.MATERIAL) do
        local ui_inv = ZZDailyWritsUI:GetNamedChild("_inv_"..mat.label)
        local num_str = ZO_AbbreviateNumber(mat.inventory_ct
                            , NUMBER_ABBREVIATION_PRECISION_LARGEST_UNIT
                            , true)
        local color = COLOR.GREY
        if mat.inventory_ct < mat.required_ct then
            color = COLOR.RED
        elseif mat.inventory_ct < 2000 then
            color = COLOR.ORANGE
        end
        ui_inv:SetText("|c"..color..num_str)
    end

                        -- Don't forget your XP potion!
    local is_xp_active = DW.IsXPBuffed()
    local status = "need"
    local color  = DW.STATE_1_NEEDS_CRAFTING.color
    if is_xp_active then
        status = "active"
        color  = DW.STATE_2_NEEDS_TURN_IN.color
    end
    local ui_status = ZZDailyWritsUI:GetNamedChild("_status_xp")
    local ui_label  = ZZDailyWritsUI:GetNamedChild("_label_xp")
    ui_status:SetText("|c"..color..status.."|r")
    ui_label:SetText( "|c"..color.."xp".."|r")
end

function DW.IsXPBuffed()
    for i = 1,GetNumBuffs("player") do
        local o = { GetUnitBuffInfo("player",i)}
        if o[1] and o[1]:lower():find("experience") then
            return true
        end
        -- d(o)
    end
    return false
end

                        -- Abandon all the daily crafting quests we can find.
                        -- Return the count of quests that we abandoned.
function DW.AbandonDailies()
                        -- Iterate backwards to avoid problems with quest
                        -- indexes changing each time we delete a quest.
    local abandon_ct = 0
    for quest_index = MAX_JOURNAL_QUESTS,1,-1  do
        local jqi = { GetJournalQuestInfo(quest_index) }
        local repeat_type = GetJournalQuestRepeatType(quest_index)
        if jqi[DW.JQI.quest_type] == QUEST_TYPE_CRAFTING
            and repeat_type == QUEST_REPEAT_DAILY then
            local name = jqi[DW.JQI.quest_name]
            d(string.format("abandoned %d:%s", quest_index, tostring(name)))
            AbandonQuest(quest_index)
            abandon_ct = abandon_ct + 1
        end
    end
    return abandon_ct
end

function DW.Test()
    DW.AbandonDailies()
    DW.char_data:EnqueueCrafting(CRAFTING_TYPE_BLACKSMITHING, 1)
    DW:DisplayCharData()
end

function DW.SlashCommand(args)
    if args:lower() == "abandon" then
        DW.AbandonDailies()
    elseif args:lower() == "test" then
        DW.Test()
    else
        d("Unknown command: '"..tostring(args).."'")
    end
end
SLASH_COMMANDS["/zzdw"] = DW.SlashCommand

-- UI ------------------------------------------------------------------------

function DW.CreateSettingsWindow()
    local LAM2 = LibStub("LibAddonMenu-2.0")
    local lam_addon_id = "ZZDailyWrits_LAM"
    local self = DW
    local panelData = {
        type                = "panel",
        name                = self.name,
        displayName         = self.name,
        author              = "ziggr",
        version             = self.version,
        registerForRefresh  = false,
        registerForDefaults = false,
    }
    local cntrlOptionsPanel = LAM2:RegisterAddonPanel( lam_addon_id
                                                     , panelData
                                                     )
    local optionsData = {
        { type      = "dropdown"
        , name      = "Days to craft"
        , choices   = { "0"
                      , "3"
                      , "9"
                      }
        , getFunc   = function()
                        if self.savedVariables.enable then
                            return self.savedVariables.days_to_craft or "0"
                        end
                        return "0"
                      end
        , setFunc   = function(e)
                        if e == "9" or e == "3" then
                            self.savedVariables.enable = true
                            self.savedVariables.days_to_craft = e
                        else
                            self.savedVariables.enable = false
                            self.savedVariables.days_to_craft = nil
                        end
                      end
        },

    }

    LAM2:RegisterOptionControls(lam_addon_id, optionsData)
end


--  1   string buffName             "Increased Experience"
--  2, number timeStarted
--  3, number timeEnding
--  4, number buffSlot              9
--  5, number stackCount
--  6, textureName iconFilename
--  7, string buffType
--  8, number BuffEffectType effectType         1
--  9, number AbilityType abilityType           5
-- 10, number StatusEffectType statusEffectType 0
-- 11, number abilityId                         85501
-- 12, boolean canClickOff                      false
-- 13, boolean castByPlayer                     true

-- Postamble -----------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent( DW.name
                              , EVENT_ADD_ON_LOADED
                              , DW.OnAddOnLoaded
                              )

ZO_CreateStringId("SI_BINDING_NAME_DW_DoIt", "Show me")
