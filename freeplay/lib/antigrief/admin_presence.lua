local Core = require 'lib.antigrief.core'
local AdminPresence = {}
local this
Core.register_binder(function(s) this = s end)
local color_yellow = { r = 1, g = 1, b = 0 }
local function any_admin_online()
    for _, p in pairs(game.connected_players) do
        if p.admin then return true end
    end
    return false
end
function AdminPresence.is_active()
    if not this then return false end
    if not this.admin_temp_trust then return false end
    return any_admin_online()
end
function AdminPresence.is_permissive()
    if not this then return false end
    if not this.enabled then return true end
    if not this.admin_temp_trust then return false end
    return any_admin_online()
end
function AdminPresence.reevaluate()
    if not this then return end
    local active = AdminPresence.is_active()
    if active == this.admin_temp_trust_announced then return end
    this.admin_temp_trust_announced = active
    if active then
        game.print({ 'fp-antigrief-panel.bc-admin-temp-trust-active' }, { color = color_yellow })
    else
        game.print({ 'fp-antigrief-panel.bc-admin-temp-trust-inactive' }, { color = color_yellow })
    end
end
function AdminPresence.on_player_joined_game(_) AdminPresence.reevaluate() end
function AdminPresence.on_player_left_game(_) AdminPresence.reevaluate() end
function AdminPresence.on_player_promoted(_) AdminPresence.reevaluate() end
function AdminPresence.on_player_demoted(_) AdminPresence.reevaluate() end
return AdminPresence
