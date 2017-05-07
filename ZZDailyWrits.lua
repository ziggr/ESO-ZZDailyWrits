ZZDailyWrits = {}
local DW = ZZDailyWrits


DW.name            = "ZZDailyWrits"
DW.version         = "2.7.1"
DW.savedVarVersion = 1
DW.default         = {
    position = {350,100}
}


-- Requirement ----------------------------------------------------------
--
-- One required item for a quest, such as "3 Nirnroot" or "1 Rubedite Sword"
--
DW.Requirement = {
}
function DW.Requirement:FromArgs(r_args)
    local o =  { ct      = r_args[1]
               , item_id = r_args[2]
               , name    = r_args[3]
               , crafted = true
               }
    if r_args.crafted ~= nil then
        o.crafted = r_args.crafted
    end
    setmetatable(o, self)
    self.__index = self
    return o
end

-- RequirementList ------------------------------------------------------
--
-- isa list of Requirement
--
-- Inventory list required to fill ONE quest.
-- Usually 2-3 elements.
--
DW.RequirementList = {
}
function DW.RequirementList:FromList(rl)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    for i, r_args in ipairs(rl) do
        table.insert(o, DW.Requirement:FromArgs(r_args))
    end
    return o
end

-- RequirementSequence ----------------------------------------------
--
-- isa list of RequirementList
--
-- A sequence of 3-5 quest's worth of inventory requirements. Used to
-- scan through inventory to see how many days' worth of quests we can
-- do before we will have to visit a crafting station.
--
DW.RequirementSequence = {
}
function DW.RequirementSequence:FromList(rl_list)
    local o = {}
    for _, rl in ipairs(rl_list) do
        local req = DW.RequirementList:FromList(rl)
        table.insert(self, req)
    end
    setmetatable(o, self)
    self.__index = self
    return o
end

-- Return the Nth day's requirement after (optional) today
function DW.RequirementSequence:Nth(n, today_n)
    local offset = 0
    if today_n then offset = today_n end
    local index = (offset + n) % #self.list
    return self.list[index]
end

local REQSEQ_BLACKSMITH_10 = {
  { { 1, 43562, "Rubedite Helm" }
  , { 1, 43535, "Rubedite Dagger" }
  , { 1, 43541, "Rubedite Pauldron" }
  }
, { { 1, 43534, "Rubedite Greatsword" }
  , { 1, 43538, "Rubedite Sabatons" }
  , { 1, 43539, "Rubedite Gauntlets" }
  }
, { { 1, 43531, "Rubedite Sword" }
  , { 1, 43537, "Rubedite Cuirass" }
  , { 1, 43540, "Rubedite Greaves" }
  }
}

local REQSEQ_CLOTHIER_10 = {
  { { 1, 43552, "Rubedo Leather Bracers" }
  , { 1, 43563, "Rubedo Leather Helmet" }
  , { 1, 43554, "Rubedo Leather Arm Cops" }
  }
, { { 1, 43544, "Ancestor Silk Shoes" }
  , { 1, 43564, "Ancestor Silk Hat" }
  , { 1, 43548, "Ancestor Silk Sash" }
  }
, { { 1, 43543, "Ancestor Silk Robe" }
  , { 1, 43546, "Ancestor Silk Breeches" }
  , { 1, 43547, "Ancestor Silk Epaulets" }
  }
}

local REQSEQ_WOODWORKING_10 = {
  { { 2, 43549, "Ruby Ash Bow" }
  , { 1, 43556, "Ruby Ash Shield" }
  }
, { { 1, 43557, "Ruby Ash Inferno Staff" }
  , { 1, 43558, "Ruby Ash Ice Staff" }
  , { 1, 43559, "Ruby Ash Lightning Staff" }
  }
, { { 2, 43560, "Ruby Ash Restoration Staff" }
  , { 1, 43556, "Ruby Ash Shield" }
  }
}

local REQSEQ_ALCHEMY_10 = {
  { { 1, 54340, "Essence of Magicka" }
  , { 3, 30165, "Nirnroot", crafted = false }
  }
, { { 1, 54341, "Essence of Stamina" }
  , { 3, 30165, "Nirnroot", crafted = false }
  }
, { { 1, 44812, "Essence of Ravage Health" }
  , { 3, 64501, "Lorkhan's Tears", crafted = false }
  }
, { { 1, 54339, "Essence of Health" }
  , { 3, 30165, "Nirnroot", crafted = false }
  }
}

local REQSEQ_ENCHANTING_10 = {
  { { 1, 26588, "Superb Glyph of Stamina" }
  , { 1, 45850, "Ta" , crafted = false }
  }
, { { 1, 26580, "Superb Glyph of Health" }
  , { 1, 64508, "Jehade", crafted = false }
  }
, { { 1, 26582, "Superb Glyph of Magicka" }
  , { 1, 45831, "Oko", crafted = false }
  }
}

-- Level 20-25 recipes, Hagnar
local REQSEQ_PROVISIONING_2_EP = {
  { { 1, 28394, "Battaglir Chowder" }
  , { 1, 28417, "Eltheric Hooch" }
  }
, { { 1, 28398, "Venison Pasty" }
  , { 1, 28421, "Honey Rye" }
  }
, { { 1, 33552, "Redoran Peppered Melon" }
  , { 1, 28457, "Bitterlemon Tea" }
  }
}

-- Level 30-35 recipes, Zecorwyn.
local REQSEQ_PROVISIONING_3_AD = {
  { { 1, 33789, "Cyrodilic Pumpkin Fritters" }
  , { 1, 33684, "Spiceberry Chai" }
  }
, { { 1, 33514, "Chorrol Corn on the Cob" }
  , { 1, 33636, "Spiced Matze" }
  }
, { { 1, 33520, "Elinhir Roast Antelope" }
  , { 1, 33642, "Sorry, Honey Lager" }
  }
}

-- Level 40-45 recipes, Al
local REQSEQ_PROVISIONING_4_AD = {
  { { 1, 33903, "Mammoth Snout Pie" }
  , { 1, 28473, "Two-Zephyr Tea" }
  }
, { { 1, 33909, "Skyrim Jazbay Crostata" }
  , { 1, 28513, "Blue Road Marathon" }
  }
, { { 1, 33897, "Cyrodilic Cornbread" }
  , { 1, 28433, "Gods-Blind-Me" }
  }
}

-- CP10-50 recipes Simone
local REQSEQ_PROVISIONING_5_DC = {
  { { 1, 43094, "Orcrest Garlic Apple Jelly" }
  , { 1, 28444, "Grandpa's Bedtime Tonic" }
  }
, { { 1, 32160, "West Weald Corn Chowder" }
  , { 1, 28402, "Comely Wench Whisky" }
  }
, { { 1, 43088, "Millet-Stuffed Pork Loin" }
  , { 1, 33602, "Aetherial Tea" }
  }
}

-- Max level provisioning: Zhaksyr
-- CP100-150 recipes
local REQSEQ_PROVISIONING_6_ZH = {
-- Zhaksyr  2017-03-29 zig: D1
  { { 1, 68236, "Firsthold Fruit and Cheese Plate" }
  , { 1, 68260, "Muthsera's Remorse" }
  }
-- Zhaksyr  2017-03-30 zig: D2 D5
, { { 1, 43124, "Pickled Carrot Slurry" }
  , { 1, 33652, "Arenthian Brandy" }
  }
-- Zhaksyr  2017-03-31 zig: D3
, { { 1, 68235, "Lilmoth Garlic Hagfish" }
  , { 1, 68263, "Hagraven's Tonic" }
  }
-- Zhaksyr  2017-04-01 zig: D4
, { { 1, 43154, "Fresh Apples and Eidar Cheese" }
  , { 1, 28482, "Khenarthi's Wings Chai" }
  }
-- Zhaksyr  2017-04-03 zig:    D6
, { { 1, 43142, "Argonian Saddle-Cured Rabbit" }
  , { 1, 33698, "Sipping Imga Tonic" }
  }
}

-- Max level provisioning: Lilwen
-- CP100-150 recipes
local REQSEQ_PROVISIONING_6_LI = {
-- Lilwen   2017-03-29 zig: D1 D4
, { { 1, 68239, "Hearty Garlic Corn Chowder" }
  , { 1, 68257, "Markarth Mead" }
  }
-- Lilwen   2017-03-30 zig: D2
, { { 1, 43142, "Argonian Saddle-Cured Rabbit" }
  , { 1, 33698, "Sipping Imga Tonic" }
  }
-- Lilwen   2017-03-31 zig: D3 D6
  { { 1, 68236, "Firsthold Fruit and Cheese Plate" }
  , { 1, 68260, "Muthsera's Remorse" }
  }
-- Lilwen   2017-04-02 zig:    D5
, { { 1, 68235, "Lilmoth Garlic Hagfish" }
  , { 1, 68263, "Hagraven's Tonic" }
  }
}

-- REMEMBER, crafted = false items can come from craft bag

-- Sequence the writs in an order I prefer.
--
-- Use these values for craft_type
--
DW.CRAFTING_TYPE = {
  CRAFTING_TYPE_BLACKSMITHING
, CRAFTING_TYPE_CLOTHIER
, CRAFTING_TYPE_WOODWORKING
, CRAFTING_TYPE_ALCHEMY
, CRAFTING_TYPE_ENCHANTING
, CRAFTING_TYPE_PROVISIONING
}

-- Character name constants
DW.CHAR_ZHAKSYR  = "Zhaksyr the Mighty"
DW.CHAR_ZECORWYN = "Zecorwyn"
DW.CHAR_LILWEN   = "Lilwen"
DW.CHAR_AL       = "Alexander Mundus"
DW.CHAR_SIMONE   = "Simone Chevalier"
DW.CHAR_HAGNAR   = "Hagnar the Slender"

-- Character-specific requirement sequences.
DW.REQSEQ = {
  [DW.CHAR_ZHAKSYR] = DW.RequirementSequence:FromList({
      [CRAFTING_TYPE_BLACKSMITHING] = REQSEQ_BLACKSMITH_10
    , [CRAFTING_TYPE_CLOTHIER]      = REQSEQ_CLOTHIER_10
    , [CRAFTING_TYPE_WOODWORKING]   = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ENCHANTING]    = REQSEQ_ENCHANTING_10
    , [CRAFTING_TYPE_ALCHEMY]       = REQSEQ_ALCHEMY_10
    , [CRAFTING_TYPE_PROVISIONING]  = REQSEQ_PROVISIONING_6_ZH
    })
, [DW.CHAR_ZECORWYN] = DW.RequirementSequence:FromList({
      [CRAFTING_TYPE_BLACKSMITHING] = REQSEQ_BLACKSMITH_10
    , [CRAFTING_TYPE_CLOTHIER]      = REQSEQ_CLOTHIER_10
    , [CRAFTING_TYPE_WOODWORKING]   = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ENCHANTING]    = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ALCHEMY]       = REQSEQ_ALCHEMY_10
    , [CRAFTING_TYPE_PROVISIONING]  = REQSEQ_PROVISIONING_3_AD
    })
, [DW.CHAR_LILWEN] = DW.RequirementSequence:FromList({
      [CRAFTING_TYPE_BLACKSMITHING] = REQSEQ_BLACKSMITH_10
    , [CRAFTING_TYPE_CLOTHIER]      = REQSEQ_CLOTHIER_10
    , [CRAFTING_TYPE_WOODWORKING]   = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ENCHANTING]    = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ALCHEMY]       = REQSEQ_ALCHEMY_10
    , [CRAFTING_TYPE_PROVISIONING]  = REQSEQ_PROVISIONING_6_LI
    })
, [DW.CHAR_AL] = DW.RequirementSequence:FromList({
      [CRAFTING_TYPE_BLACKSMITHING] = REQSEQ_BLACKSMITH_10
    , [CRAFTING_TYPE_CLOTHIER]      = REQSEQ_CLOTHIER_10
    , [CRAFTING_TYPE_WOODWORKING]   = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ENCHANTING]    = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ALCHEMY]       = REQSEQ_ALCHEMY_10
    , [CRAFTING_TYPE_PROVISIONING]  = REQSEQ_PROVISIONING_4_AD
    })
, [DW.CHAR_SIMONE] = DW.RequirementSequence:FromList({
      [CRAFTING_TYPE_BLACKSMITHING] = REQSEQ_BLACKSMITH_10
    , [CRAFTING_TYPE_CLOTHIER]      = REQSEQ_CLOTHIER_10
    , [CRAFTING_TYPE_WOODWORKING]   = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ENCHANTING]    = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ALCHEMY]       = REQSEQ_ALCHEMY_10
    , [CRAFTING_TYPE_PROVISIONING]  = REQSEQ_PROVISIONING_5_DC
    })
, [DW.CHAR_HAGNAR] = DW.RequirementSequence:FromList({
      [CRAFTING_TYPE_BLACKSMITHING] = REQSEQ_BLACKSMITH_10
    , [CRAFTING_TYPE_CLOTHIER]      = REQSEQ_CLOTHIER_10
    , [CRAFTING_TYPE_WOODWORKING]   = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ENCHANTING]    = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ALCHEMY]       = REQSEQ_ALCHEMY_10
    , [CRAFTING_TYPE_PROVISIONING]  = REQSEQ_PROVISIONING_2_EP
    })
}

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
-- How far along is this quest? When do we thing this quest was first acquired?
DW.QuestStatus = {
}
function DW.QuestStatus:New()
    local o = { status      = DW.STATE_0_NEEDS_ACQUIRE
              , acquired_ts = 0  -- either 11pm yesterday or
                                 -- when we got event for acquiring
              , day_offset  = 0  -- into associated RequirementSequence
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
    char_name   = nil   -- "Zhaksyr the Mighty"
,   reqseq      = nil   -- REQSEQ[char_name]

,   quest_status = {}   -- index1 = craft_type
                        -- index2 = first(1) or second(2) quest today
                        --
                        -- example: quest_status[CRAFTING_TYPE_CLOTHIER][1]
                        --  = status of first clothing quest since 11pm
                        --  last night.
                        --
                        -- XXX Need to struct this, quest status change edges
                        -- XXX must carry a timestamp so that we know when to
                        -- XXX discard "quest completed" edges that occur
                        -- XXX older than 11pm last night.

,   curr_day_offset = {} -- index = CRAFTING_TYPE_XXX
                        -- value = number 0-2 offset into corresponding
                        --         reqseq sequence where next quest
                        --         is/will be.
                        --
                        -- This is the ONLY per-char data really worth writing
                        -- to savedVars and I'm not sure even this is
                        -- worthwhile
--[[
    QuestStatus(craft_type, quest_index=1..2)
    InventoryList(craft_type)
--]]
}
function CharData:New()
    local o = {}
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

function DW_DoIt()
    d("_DoIt")
    ui = DWUI
    if not ui then
        d("No UI")
        return
    end
    h = DWUI:IsHidden()
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
