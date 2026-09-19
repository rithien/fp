local Event = require 'lib.event'
local Server = require 'lib.server'
local Session = require 'lib.sessions'
local DebugLog = require 'lib.debug_log'
local Constants = require 'constants'
local Core = require 'lib.antigrief.core'
local PlayerPresence = require 'lib.player_presence'
local config = require 'lib.leave_report.config'
local AUDIT = Constants.audit
local format = string.format
local floor = math.floor
local FEEDBACK_DATASET = 'feedback'
local LeaveReport = {}
local function noop() end
if not config.enabled then
    LeaveReport.note_removed = noop
    LeaveReport.note_blocked = noop
    LeaveReport.note_built = noop
    return LeaveReport
end
local function get_store()
    if not storage.leave_report then storage.leave_report = {} end
    return storage.leave_report
end
local function note(player, field, name, position, surface_index)
    local store = get_store()
    local entry = store[player.index]
    if not entry then
        entry = {
            removed = 0,
            blocked = 0,
            names = {},
            x = floor(position.x),
            y = floor(position.y),
            surface = surface_index,
            since_tick = game.tick,
        }
        store[player.index] = entry
        DebugLog.log('[leave_report] flag SET for %s (%s %s)', player.name, field, name)
    end
    entry[field] = entry[field] + 1
    entry.names[name] = (entry.names[name] or 0) + 1
end
function LeaveReport.note_removed(player, entity)
    if Core.is_logging_muted_for(player) then return end
    if not Core.is_foreign_same_force(player, entity) then return end
    note(player, 'removed', entity.name, entity.position, entity.surface.index)
end
function LeaveReport.note_blocked(player, name, position, surface_index)
    if Core.is_logging_muted_for(player) then return end
    note(player, 'blocked', name, position, surface_index)
end
function LeaveReport.note_built(player)
    local store = storage.leave_report
    if not store or not store[player.index] then return end
    store[player.index] = nil
    DebugLog.log('[leave_report] flag CLEARED for %s (built)', player.name)
end
local function top_names(names)
    local list = {}
    for name, count in pairs(names) do
        list[#list + 1] = { name = name, count = count }
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    local parts = {}
    for i = 1, math.min(#list, config.max_names) do
        parts[i] = format('%s x%d', list[i].name, list[i].count)
    end
    if #list > config.max_names then
        parts[#parts + 1] = format('+%d more', #list - config.max_names)
    end
    return table.concat(parts, ', ')
end
Event.add(defines.events.on_player_joined_game, function(event)
    local store = storage.leave_report
    if store then store[event.player_index] = nil end
end)
Event.add(defines.events.on_player_left_game, function(event)
    local store = storage.leave_report
    local entry = store and store[event.player_index]
    if not entry then return end
    store[event.player_index] = nil
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local scope = Session.get_trust_scope(player)
    local trust = scope and ('trusted-' .. scope) or 'untrusted'
    local flagged_s = floor((game.tick - entry.since_tick) / 60)
    local text = format(AUDIT.leave_report_body,
        entry.removed, entry.blocked, top_names(entry.names),
        entry.x, entry.y, entry.surface,
        floor(flagged_s / 60), flagged_s % 60,
        PlayerPresence.reason_name(event.reason))
    DebugLog.log('[leave_report] REPORT %s [%s]: %s', player.name, trust, text)
    Server.set_data(FEEDBACK_DATASET, format('%d_%s', game.tick, player.name), {
        player = player.name,
        text = text,
        tick = game.tick,
        ts = floor(game.tick / 60),
        source = 'auto',
    })
    Server.to_admin_embed_raw('**' .. format(AUDIT.leave_report_title, player.name, trust) .. '**: ' .. text)
end)
return LeaveReport
