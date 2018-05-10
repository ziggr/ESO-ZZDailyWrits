ZZDailyWrits = {}
local DW = ZZDailyWrits

DW.name            = "ZZDailyWrits"
DW.version         = "4.0.1"
DW.savedVarVersion = 2
DW.default         = { position  = {350,100}
                     , char_data = {}
                     }

local CAN_JEWELRY = ITEM_TRAIT_TYPE_JEWELRY_SWIFT or false
local CRAFTING_TYPE_JEWELRY = CRAFTING_TYPE_JEWELRY or 7

-- Sequence the writs in an order I prefer.
--
-- Use these values for craft_type
--
DW.CRAFTING_TYPE = {
  { abbr = "bs", order = 1, ct = CRAFTING_TYPE_BLACKSMITHING , quest_name = "Blacksmith Writ"}
, { abbr = "cl", order = 2, ct = CRAFTING_TYPE_CLOTHIER      , quest_name = "Clothier Writ" }
, { abbr = "ww", order = 3, ct = CRAFTING_TYPE_WOODWORKING   , quest_name = "Woodworker Writ"}
, { abbr = "jw", order = 4, ct = CRAFTING_TYPE_JEWELRY       , quest_name = "Jewelry Crafting Writ"}
, { abbr = "al", order = 5, ct = CRAFTING_TYPE_ALCHEMY       , quest_name = "Alchemist Writ"}
, { abbr = "en", order = 6, ct = CRAFTING_TYPE_ENCHANTING    , quest_name = "Enchanter Writ"}
, { abbr = "pr", order = 7, ct = CRAFTING_TYPE_PROVISIONING  , quest_name = "Provisioner Writ"}
}

local DWUI = nil



-- Quest states --------------------------------------------------------------

                        -- Not started
                        -- Need to visit a billboard to acquire quest.
DW.STATE_0_NEEDS_ACQUIRE    = { id = "acquire", order = 0, color = "66AABB" }

                        -- Acquired, but at least one item needs to be
                        -- crafted before turnining in.
                        -- Need to visit a crafting station to
                        -- make things.
DW.STATE_1_NEEDS_CRAFTING   = { id = "craft",   order = 1, color = "FF3333" }

                        -- Crafting of all items completed.
                        -- Need to visit turn-in station.
DW.STATE_2_NEEDS_TURN_IN    = { id = "turn in", order = 2, color = "33FF33" }

                        -- Quest completed. Done for the day.
DW.STATE_3_TURNED_IN        = { id = "done",    order = 3, color = "AAAAAA" }

                        -- Quest does not exist on this server or character.
DW.STATE_X_IMPOSSIBLE       = { id = "n/a",     order = 9, color = "333333" }
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
    local seen_quest_ct = 0
    local quest_status = {}
    for qi = 1, MAX_JOURNAL_QUESTS do
        local x = self:AbsorbQuest(qi)
        if x then
            quest_status[x.crafting_type.order] = x.quest_status
--d("Set qs["..tostring(x.crafting_type.order).."]")
--d(x)
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
            self:EnqueueCrafting(ct.ct, max_style)
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
-- if (quest_index == 9) then DEBUG = function(x) d(x) end end
-- DEBUG = function(x) d(x) end

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
        local says_recipes = string.find(c_text:lower(), "recipes")
        if says_recipes then return true end
    end
    return false
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

-- We've just switched from "acquire" to "needs crafting".
-- Now would be an excellent time to enqueue items for crafting.
--
-- crafting_type is CRAFTING_TYPE_XXX
function CharData:EnqueueCrafting(crafting_type)
                        -- Requires Dolgubon's Lazy Set Crafter
    if not DolgubonSetCrafter then
        d("Autoqueue skipped: requires Dolgubon Lazy Set Crafter")
        return
    end

    if crafting_type == CRAFTING_TYPE_BLACKSMITHING then
        local q = {
          { count = 3, pattern_index =  3, name = "1h sword"      , weight_name = "heavy" }
        , { count = 3, pattern_index =  6, name = "2h g.sword"    , weight_name = "heavy" }
        , { count = 3, pattern_index =  7, name = "dagger"        , weight_name = "heavy" }
        , { count = 3, pattern_index =  8, name = "chest"         , weight_name = "heavy" }
        , { count = 3, pattern_index =  9, name = "feet"          , weight_name = "heavy" }
        , { count = 3, pattern_index = 10, name = "hands"         , weight_name = "heavy" }
        , { count = 3, pattern_index = 11, name = "head"          , weight_name = "heavy" }
        , { count = 3, pattern_index = 12, name = "legs"          , weight_name = "heavy" }
        , { count = 3, pattern_index = 13, name = "shoulders"     , weight_name = "heavy" }
        }
        local constants = {
          station     = CRAFTING_TYPE_BLACKSMITHING
        }
        self:LLC_Enqueue(q, constants)
    elseif crafting_type == CRAFTING_TYPE_CLOTHIER then
        local q = {
          { count = 3, pattern_index =  1, name = "chest"         , weight_name = "light"  }
        , { count = 3, pattern_index =  3, name = "feet"          , weight_name = "light"  }
        , { count = 3, pattern_index =  5, name = "head"          , weight_name = "light"  }
        , { count = 3, pattern_index =  6, name = "legs"          , weight_name = "light"  }
        , { count = 3, pattern_index =  7, name = "shoulders"     , weight_name = "light"  }
        , { count = 3, pattern_index =  8, name = "waist"         , weight_name = "light"  }
        , { count = 3, pattern_index = 11, name = "hands"         , weight_name = "medium" }
        , { count = 3, pattern_index = 12, name = "head"          , weight_name = "medium" }
        , { count = 3, pattern_index = 14, name = "shoulders"     , weight_name = "medium" }
        }
        local constants = {
          station     = CRAFTING_TYPE_CLOTHIER
        }
        self:LLC_Enqueue(q, constants)
    elseif crafting_type == CRAFTING_TYPE_WOODWORKING then
        local q = {
          { count = 6, pattern_index =  1, name = "bow"           , weight_name = "wood"  }
        , { count = 3, pattern_index =  3, name = "flame"         , weight_name = "wood"  }
        , { count = 3, pattern_index =  4, name = "ice"           , weight_name = "wood"  }
        , { count = 3, pattern_index =  5, name = "shock"         , weight_name = "wood"  }
        , { count = 6, pattern_index =  6, name = "resto"         , weight_name = "wood"  }
        , { count = 6, pattern_index =  2, name = "shield"        , weight_name = "wood"  }
        }
        local constants = {
          station     = CRAFTING_TYPE_WOODWORKING
        }
        self:LLC_Enqueue(q, constants)
    elseif crafting_type == CRAFTING_TYPE_ENCHANTING then
        if not (DolgubonSetCrafter.LazyCrafter.CraftEnchantingItemId) then
            d(   "ZZDailyWrits: Set Crafter doesn't load enchanting support."
              .. " Enable add-on Dolgubon's Lazy Writ Crafter.")
            return nil
        end

        local q = {
          { count = 3, potency = REJERA, essence = DENI  , aspect = TA  }
        , { count = 3, potency = REJERA, essence = MAKKO , aspect = TA  }
        , { count = 3, potency = REJERA, essence = OKO   , aspect = TA  }
        }
        local constants = {
          station     = CRAFTING_TYPE_ENCHANTING
        }
        self:LLC_Enqueue(q, constants)
    else
        d("Autoqueue skipped: Only EN/BS/CL/WW supported.")
    end
end

function CharData:LLC_Enqueue(q, constants)
    local DOL = DolgubonSetCrafter -- for less typing
    local queued_ct = 0
    for _, qe in ipairs(q) do
        for i = 1, qe.count do
            local dol_request = self:LLC_ToOneRequest(qe, constants)

                        -- Dolgubon's Set Crafter is designed for smithing ONLY
                        -- and cannot dequeue completed glyphs after crafting.
                        -- The result is after crafting the Set Crafter queue
                        -- holds leftover requests that don't really exist
                        -- anymore in LLC. So don't put enchanting items in the
                        -- Set Crafter queue. Just the LLC queue.
            if dol_request.llc_func == "CraftSmithingItemByLevel" then
                table.insert(DOL.savedvars.queue, dol_request)
            end
            local o = dol_request.CraftRequestTable
            DOL.LazyCrafter[dol_request.llc_func](DOL.LazyCrafter, unpack(o))
            queued_ct = queued_ct + 1
        end
    end
    d("Autoqueued "..tostring(queued_ct).." requests")
    DolgubonSetCrafter.updateList()
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
    DolgubonSetCrafter.savedvars.counter = DolgubonSetCrafter.savedvars.counter + 1
    local reference = DolgubonSetCrafter.savedvars.counter

    local sm = { [CRAFTING_TYPE_BLACKSMITHING] = 1
               , [CRAFTING_TYPE_CLOTHIER     ] = 1
               , [CRAFTING_TYPE_WOODWORKING  ] = 1
               , [CRAFTING_TYPE_JEWELRY      ] = 1
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
        request_table.Style             = C(o.styleIndex + 1  , "Breton"       )
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

                        -- Lie to Set Crafter, tell it that we're enqueing
                        -- an Argonian 1h axe or something, just to prevent
                        -- it from crashing with nil pointer errors as it
                        -- calculates material requirements.

        local C = CharData.ToDolCell   -- for less typing
        local request_table = {}
        request_table.Pattern           = C(1                 , "enchanting"    )
        request_table.Weight            = C(1                 , NAME[qe.potency])
        request_table.Level             = C(150               , NAME[qe.essence])
        request_table.Style             = C(1                 , NAME[qe.aspect ])
        request_table.Trait             = C(0                 , ""              )
        request_table.Set               = C(1                 , ""              )
        request_table.Quality           = C(1                 , "white"         )
        request_table.Reference         =   reference
        request_table.CraftRequestTable =   craft_request_table
        request_table.llc_func          = "CraftEnchantingItemId"
        return request_table
    end

    d("ZZDailyWrits bug: unsupported station:"..tostring(constants.station))
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
