ZZDailyWrits = _G['ZZDailyWrits'] or {}
local DW = ZZDailyWrits
DW.Log = {}
local Log = DW.Log

-- LibDebugLogger ------------------------------------------------------------

-- If Sirinsidiator's LibDebugLogger is installed, then return a logger from
-- that. If not, return a NOP replacement.

local NOP = {}
function NOP:Debug(...) end
function NOP:Info(...) end
function NOP:Warn(...) end
function NOP:Error(...) end

DW.log_to_chat            = false
DW.log_to_chat_warn_error = false

function DW.Logger()
    local self = DW
    if not self.logger then
        if LibDebugLogger then
            self.logger = LibDebugLogger.Create(self.name)
        end
        if not self.logger then
            self.logger = NOP
            DW.log_to_chat_warn_error  = true
        end
    end
    return self.logger
end

function DW.LogOne(color, ...)
    if DW.log_to_chat then
        d("|c"..color..DW.name..": "..string.format(...).."|r")
    end
end

function DW.LogOneWarnError(color, ...)
    if DW.log_to_chat or DW.log_to_chat_warn_error then
        d("|c"..color..DW.name..": "..string.format(...).."|r")
    end
end

function Log.Debug(...)
    DW.LogOne("666666",...)
    DW.Logger():Debug(...)
end

function Log.Info(...)
    DW.LogOne("999999",...)
    DW.Logger():Info(...)
end

function Log.Warn(...)
    DW.LogOneWarnError("FF8800",...)
    DW.Logger():Warn(...)
end

function Log.Error(...)
    DW.LogOneWarnError("FF6666",...)
    DW.Logger():Error(...)
end
