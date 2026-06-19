local Event = require 'lib.event'
local Config = require 'lib.config'
local Server = require 'lib.server'
local Constants = require 'constants'
local FEEDBACK_TOGGLE_ID = 'feedback'
local FEEDBACK_DATASET = 'feedback'
local FEEDBACK_COOLDOWN_TICKS = 30 * 60
local FEEDBACK_MAX_LENGTH = 500
local Feedback = {}
local function ensure_storage()
    if not storage.feedback then
        storage.feedback = { cooldown = {} }
    end
    if not storage.feedback.cooldown then storage.feedback.cooldown = {} end
end
Event.on_init(ensure_storage)
Event.on_configuration_changed(ensure_storage)
function Feedback.is_enabled()
    return Config.is_enabled(FEEDBACK_TOGGLE_ID)
end
function Feedback.set_enabled(new_state)
    Config.set(FEEDBACK_TOGGLE_ID, new_state)
end
function Feedback.cooldown_remaining(player)
    ensure_storage()
    local last = storage.feedback.cooldown[player.index]
    if not last then return 0 end
    local elapsed = game.tick - last
    if elapsed >= FEEDBACK_COOLDOWN_TICKS then return 0 end
    return math.ceil((FEEDBACK_COOLDOWN_TICKS - elapsed) / 60)
end
local function sanitize(text)
    if type(text) ~= 'string' then return '', 'fp-feedback.empty-error' end
    local trimmed = text:match('^%s*(.-)%s*$') or ''
    if trimmed == '' then return '', 'fp-feedback.empty-error' end
    if #trimmed > FEEDBACK_MAX_LENGTH then
        return '', 'fp-feedback.too-long-error'
    end
    trimmed = trimmed:gsub('[\r\n]+', ' ')
    return trimmed, nil
end
function Feedback.submit(player, raw_text)
    if not Feedback.is_enabled() then
        return false, 'fp-feedback.disabled-error'
    end
    if not player or not player.valid then return false, nil end
    ensure_storage()
    local remaining = Feedback.cooldown_remaining(player)
    if remaining > 0 then
        return false, 'fp-feedback.cooldown-error'
    end
    local text, err = sanitize(raw_text)
    if err then return false, err end
    storage.feedback.cooldown[player.index] = game.tick
    local ts = math.floor(game.tick / 60) 
    local key = string.format('%d_%s', game.tick, player.name)
    local payload = {
        player = player.name,
        text = text,
        tick = game.tick,
        ts = ts,
    }
    Server.set_data(FEEDBACK_DATASET, key, payload)
    local header = string.format(Constants.audit.feedback_title, player.name)
    Server.to_admin_embed_raw('**' .. header .. '**: ' .. text)
    return true, nil
end
Event.add(defines.events.on_player_left_game, function(event)
    if storage.feedback and storage.feedback.cooldown then
        storage.feedback.cooldown[event.player_index] = nil
    end
end)
Feedback.MAX_LENGTH = FEEDBACK_MAX_LENGTH
Feedback.COOLDOWN_TICKS = FEEDBACK_COOLDOWN_TICKS
return Feedback
