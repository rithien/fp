local Config = require 'lib.config'
local TOGGLE_ID = 'debug_log'
local DebugLog = {}
function DebugLog.is_enabled()
    return Config.is_enabled(TOGGLE_ID)
end
function DebugLog.set_enabled(new_state)
    Config.set(TOGGLE_ID, new_state)
    log(string.format('[debug_log] toggle = %s', new_state and 'ON' or 'OFF'))
end
function DebugLog.log(fmt, ...)
    if not Config.is_enabled(TOGGLE_ID) then return end
    if select('#', ...) > 0 then
        log(string.format(fmt, ...))
    else
        log(fmt)
    end
end
return DebugLog
