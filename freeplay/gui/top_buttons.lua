local Event = require 'lib.event'
local de = defines.events
local Public = {}
local ensure_fns = {}
local SWEEP_INTERVAL = 600
function Public.register(ensure_fn)
    assert(type(ensure_fn) == 'function', 'TopButtons.register: ensure_fn must be a function')
    ensure_fns[#ensure_fns + 1] = ensure_fn
end
local function sweep_player(player)
    if not (player and player.valid) then
        return
    end
    for _, fn in ipairs(ensure_fns) do
        local ok, err = pcall(fn, player)
        if not ok then
            log('[top_buttons] ensure_fn failed: ' .. tostring(err))
        end
    end
end
local function sweep_all()
    for _, player in pairs(game.connected_players) do
        sweep_player(player)
    end
end
Event.on_nth_tick(SWEEP_INTERVAL, sweep_all)
Event.add(de.on_player_created, function(event)
    sweep_player(game.get_player(event.player_index))
end)
return Public
