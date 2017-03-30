ZZDailyWrits = {}
local DW = ZZDailyWrits


DW.name            = "ZZDailyWrits"
DW.version         = "2.7.1"
DW.savedVarVersion = 1
DW.default         = {
    position = {350,100}
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


-- RequirementList ------------------------------------------------------
--
-- Inventory list required to fill ONE quest.
--
DW.RequirementList = {
}
function DW.RequirementList:New()
    local o = { ct      = 0
              , item_id = 0
              , name    = nil
              , crafted = true -- true  = must be crafted
                               -- false = extracted from bags
                               --         (usually craft bag)
              }
    setmetatable(o, self)
    self.__index = self
    return o
end

function DW.RequirementList:FromList(list)
    o = self:New()
    for i, e in ipairs(list) do
        o[i].ct      = a[1]
        o[i].item_id = a[2]
        o[i].name    = a[3]
        if a.crafted ~= nil then
            o[i].crafted = a.crafted
        end
    end
end

-- RequirementSequence ----------------------------------------------
--
-- A sequence of THREE quest's worth of inventory requirements. Used to
-- scan through inventory to see how many days' worth of quests we can
-- do before we will have to visit a crafting station.
--
DW.RequirementSequence = {
}
function DW.RequirementSequence:New(r1, r2, r3)
    local o = {
        list = {}
              }
    if r1 then list[1] = DW.RequirementList:FromList(r1) end
    if r2 then list[2] = DW.RequirementList:FromList(r2) end
    if r3 then list[3] = DW.RequirementList:FromList(r3) end

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
-- Day 1
-- Zhaksyr  2017-03-29 zig: D1
-- Zecorwyn 2017-03-29 zig: D1
-- Lilwen   2017-03-29 zig: D1
-- Simone   2017-03-29 zig: D1
-- Al       2017-03-30 zig: D2
  { { 1, 43562, "Rubedite Helm" }
  , { 1, 43535, "Rubedite Dagger" }
  , { 1, 43541, "Rubedite Pauldron" }
  }

-- Day 2
-- Hagnar   2017-03-29 zig: D1
-- Zhaksyr  2017-03-30 zig: D2
-- Zecorwyn 2017-03-30 zig: D2
, { { 1, 43534, "Rubedite Greatsword" }
  , { 1, 43538, "Rubedite Sabatons" }
  , { 1, 43539, "Rubedite Gauntlets" }
  }

-- Day 3
-- Al       2017-03-29 zig: D1
-- Lilwen   2017-03-30 zig: D2
, { { 1, 43531, "Rubedite Sword" }
  , { 1, 43537, "Rubedite Cuirass" }
  , { 1, 43540, "Rubedite Greaves" }
  }
}

local REQSEQ_CLOTHIER_10 = {
-- Day 1
-- Zhaksyr  2017-03-29 zig: D1
-- Zecorwyn 2017-03-29 zig: D1
-- Simone   2017-03-29 zig: D1
-- Al       2017-03-30 zig: D2
  { { 1, 43552, "Rubedo Leather Bracers" }
  , { 1, 43563, "Rubedo Leather Helmet" }
  , { 1, 43554, "Rubedo Leather Arm Cops" }
  }
-- Day 2
-- Lilwen   2017-03-29 zig: D1
-- Hagnar   2017-03-29 zig: D1
-- Zhaksyr  2017-03-30 zig: D2
-- Zecorwyn 2017-03-30 zig: D2
, { { 1, 43544, "Ancestor Silk Shoes" }
  , { 1, 43564, "Ancestor Silk Hat" }
  , { 1, 43548, "Ancestor Silk Sash" }
  }
-- Day 3
-- Al       2017-03-29 zig: D1
-- Lilwen   2017-03-30 zig: D2
, { { 1, 43543, "Ancestor Silk Robe" }
  , { 1, 43546, "Ancestor Silk Breeches" }
  , { 1, 43547, "Ancestor Silk Epaulets" }
  }
}

local REQSEQ_WOODWORKING_10 = {
-- Day 1
-- Zhaksyr  2017-03-29 zig: D1
-- Zecorwyn 2017-03-29 zig: D1
-- Simone   2017-03-29 zig: D1
  { { 2, 43549, "Ruby Ash Bow" }
  , { 1, 43556, "Ruby Ash Shield" }
  }
-- Day 2
-- Lilwen   2017-03-29 zig: D1
-- Hagnar   2017-03-29 zig: D1
-- Zhaksyr  2017-03-30 zig: D2
, { { 1, 43557, "Ruby Ash Inferno Staff" }
  , { 1, 43558, "Ruby Ash Ice Staff" }
  , { 1, 43559, "Ruby Ash Lightning Staff" }
  }
-- Day 3
-- Al       2017-03-29 zig: D1
-- Lilwen   2017-03-30 zig: D2
, { { 2, 43560, "Ruby Ash Restoration Staff" }
  , { 1, 43556, "Ruby Ash Shield" }
  }
}

local REQSEQ_ALCHEMY_10 = {
-- Day 1
-- Zhaksyr  2017-03-29 zig: D1
-- Lilwen   2017-03-29 zig: D1
  { { 1, 54340, "Essence of Magicka" }
  , { 3, 30165, "Nirnroot", crafted = false }
  }
-- Day 2
-- Simone   2017-03-29 zig: D1
-- Zhaksyr  2017-03-30 zig: D2
-- Lilwen   2017-03-30 zig: D2
, { { 1, 54341, "Essence of Stamina" }
  , { 3, 30165, "Nirnroot", crafted = false }
  }
-- Day 3
-- Zecorwyn 2017-03-29 zig: D1
-- Al       2017-03-29 zig: D1
-- Hagnar   2017-03-29 zig: D1
, { { 1, 44812, "Essence of Ravage Health" }
  , { 3, 64501, "Lorkhan's Tears", crafted = false }
  }
-- Day 4 Zecorwyn
-- Al       2017-03-30 zig: D2
-- Zecorwyn 2017-03-30 zig: D2
, { { 1, 54339, "Essence of Health" }
  , { 3, 30165, "Nirnroot", crafted = false }
  }
}

local REQSEQ_ENCHANTING_10 = {
-- Day 1
-- Zhaksyr  2017-03-29 zig: D1
-- Zecorwyn 2017-03-29 zig: D1
-- Simone   2017-03-29 zig: D1
-- Al       2017-03-30 zig: D2
  { { 1, 26588, "Superb Glyph of Stamina" }
  , { 1, 45850, "Ta" , crafted = false }
  }
-- Day 2
-- Lilwen   2017-03-29 zig: D1
-- Hagnar   2017-03-29 zig: D1
-- Zhaksyr  2017-03-30 zig: D2
-- Zecorwyn 2017-03-30 zig: D2
, { { 1, 26580, "Superb Glyph of Health" }
  , { 1, 64508, "Jehade", crafted = false }
  }
-- Day 3
-- Al       2017-03-29 zig: D1
-- Lilwen   2017-03-30 zig: D2
, { { 1, 26582, "Superb Glyph of Magicka" }
  , { 1, 45831, "Oko", crafted = false }
  }
}

-- Level 20-25 recipes, Hagnar
local REQSEQ_PROVISIONING_2_EP = {
-- Day 1
-- Hagnar  2017-03-29 zig:
  { { 1, 28394, "Battaglir Chowder" }
  , { 1, 28417, "Eltheric Hooch" }
  }
-- Day 2
, { { 1, 28398, "Venison Pasty" }
  , { 1, 28421, "Honey Rye" }
  }
-- Day 3
, { { 1, 33552, "Redoran Peppered Melon" }
  , { 1, 28457, "Bitterlemon Tea" }
  }
}

-- Level 30-35 recipes, Zecorwyn.
local REQSEQ_PROVISIONING_3_AD = {
-- Day 1
-- Zecorwyn 2017-03-29 zig: D1
  { { 1, 33789, "Cyrodilic Pumpkin Fritters" }
  , { 1, 33684, "Spiceberry Chai" }
  }
-- Day 2
-- Zecorwyn 2017-03-30 zig: D2
, { { 1, 33514, "Chorrol Corn on the Cob" }
  , { 1, 33636, "Spiced Matze" }
  }
-- Day 3
, { { 1, 33520, "Elinhir Roast Antelope" }
  , { 1, 33642, "Sorry, Honey Lager" }
  }
}

-- Level 40-45 recipes, Al
local REQSEQ_PROVISIONING_4_AD = {
-- Day 1
-- Al 2017-03-29 zig:
  { { 1, 33903, "Mammoth Snout Pie" }
  , { 1, 28473, "Two-Zephyr Tea" }
  }
-- Day 2
, { { 1, 33909, "Skyrim Jazbay Crostata" }
  , { 1, 28513, "Blue Road Marathon" }
  }
-- Day 3
, { { 1, 33897, "Cyrodilic Cornbread" }
  , { 1, 28433, "Gods-Blind-Me" }
  }
}

-- CP10-50 recipes Simone
local REQSEQ_PROVISIONING_5_DC = {
-- Day 1
-- Simone 2017-03-29 zig:
  { { 1, 43094, "Orcrest Garlic Apple Jelly" }
  , { 1, 28444, "Grandpa's Bedtime Tonic" }
  }
-- Day 2
, { { 1, 32160, "West Weald Corn Chowder" }
  , { 1, 28402, "Comely Wench Whisky" }
  }
--Day 3
, { { 1, 43088, "Millet-Stuffed Pork Loin" }
  , { 1, 33602, "Aetherial Tea" }
  }
}

-- Max level provisioning: Zhaksyr and Lilwen
-- CP100-150 recipes
local REQSEQ_PROVISIONING_6 = {
-- Day 1
-- Zhaksyr  2017-03-29 zig: D1
  { { 1, 68236, "Firsthold Fruit and Cheese Plate" }
  , { 1, 68260, "Muthsera's Remorse" }
  }
-- Day 2 Zh
-- Zhaksyr  2017-03-30 zig: D2
, { { 1, 43124, "Pickled Carrot Slurry" }
  , { 1, 33652, "Arenthian Brandy" }
  }
-- Day 2
-- Lilwen   2017-03-29 zig: D1
, { { 1, 68239, "Hearty Garlic Corn Chowder" }
  , { 1, 68257, "Markarth Mead" }
  }
-- Day 3
, { { 1, 68235, "Lilmoth Garlig Hagfish" }
  , { 1, 68263, "Hagraven's Tonic" }
  }
-- Day 2
-- Lilwen   2017-03-30 zig: D2
, { { 1, "Argonian Saddle-Cured Rabbit" }
  , { 1, "Sipping Imga Tonic" }
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
  [DW.CHAR_ZHAKSYR] = {
      [CRAFTING_TYPE_BLACKSMITHING] = REQSEQ_BLACKSMITH_10
    , [CRAFTING_TYPE_CLOTHIER]      = REQSEQ_CLOTHIER_10
    , [CRAFTING_TYPE_WOODWORKING]   = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ENCHANTING]    = REQSEQ_ENCHANTING_10
    , [CRAFTING_TYPE_ALCHEMY]       = REQSEQ_ALCHEMY_10
    , [CRAFTING_TYPE_PROVISIONING]  = REQSEQ_PROVISIONING_10
    }
, [DW.CHAR_ZECORWYN] = {
      [CRAFTING_TYPE_BLACKSMITHING] = REQSEQ_BLACKSMITH_10
    , [CRAFTING_TYPE_CLOTHIER]      = REQSEQ_CLOTHIER_10
    , [CRAFTING_TYPE_WOODWORKING]   = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ENCHANTING]    = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ALCHEMY]       = REQSEQ_ALCHEMY_10
    , [CRAFTING_TYPE_PROVISIONING]  = REQSEQ_PROVISIONING_3_AD
    }
, [DW.CHAR_LILWEN] = {
      [CRAFTING_TYPE_BLACKSMITHING] = REQSEQ_BLACKSMITH_10
    , [CRAFTING_TYPE_CLOTHIER]      = REQSEQ_CLOTHIER_10
    , [CRAFTING_TYPE_WOODWORKING]   = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ENCHANTING]    = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ALCHEMY]       = REQSEQ_ALCHEMY_10
    , [CRAFTING_TYPE_PROVISIONING]  = REQSEQ_PROVISIONING_10
    }
, [DW.CHAR_AL] = {
      [CRAFTING_TYPE_BLACKSMITHING] = REQSEQ_BLACKSMITH_10
    , [CRAFTING_TYPE_CLOTHIER]      = REQSEQ_CLOTHIER_10
    , [CRAFTING_TYPE_WOODWORKING]   = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ENCHANTING]    = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ALCHEMY]       = REQSEQ_ALCHEMY_10
    , [CRAFTING_TYPE_PROVISIONING]  = REQSEQ_PROVISIONING_4_AD
    }
, [DW.CHAR_SIMONE] = {
      [CRAFTING_TYPE_BLACKSMITHING] = REQSEQ_BLACKSMITH_10
    , [CRAFTING_TYPE_CLOTHIER]      = REQSEQ_CLOTHIER_10
    , [CRAFTING_TYPE_WOODWORKING]   = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ENCHANTING]    = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ALCHEMY]       = REQSEQ_ALCHEMY_10
    , [CRAFTING_TYPE_PROVISIONING]  = REQSEQ_PROVISIONING_5_DC
    }
, [DW.CHAR_HAGNAR] = {
      [CRAFTING_TYPE_BLACKSMITHING] = REQSEQ_BLACKSMITH_10
    , [CRAFTING_TYPE_CLOTHIER]      = REQSEQ_CLOTHIER_10
    , [CRAFTING_TYPE_WOODWORKING]   = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ENCHANTING]    = REQSEQ_WOODWORKING_10
    , [CRAFTING_TYPE_ALCHEMY]       = REQSEQ_ALCHEMY_10
    , [CRAFTING_TYPE_PROVISIONING]  = REQSEQ_PROVISIONING_2_EP
    }
}

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

,   day_offsets = {}    -- index = CRAFTING_TYPE_XXX
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
