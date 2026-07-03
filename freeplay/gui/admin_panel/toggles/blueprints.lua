local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local Event = require 'lib.event'
local Constants = require 'constants'
local de = defines.events
local TOGGLE_ID = 'blueprints'
local BLUEPRINT_ACTIONS = {
    defines.input_action.grab_blueprint_record,
    defines.input_action.import_blueprint_string,
    defines.input_action.import_blueprint,
    defines.input_action.export_blueprint
}
local UNTRUSTED_DENY_IDS = {}
for _, name in ipairs(Constants.untrusted.blocked_actions or {}) do
    local id = defines.input_action[name]
    if id then UNTRUSTED_DENY_IDS[id] = true end
end
local function apply(state)
    local default = game.permissions.get_group('Default')
    if default then
        for _, action in ipairs(BLUEPRINT_ACTIONS) do
            default.set_allows_action(action, state and true or false)
        end
    end
    local untrusted = game.permissions.get_group(Constants.untrusted.group_name)
    if untrusted then
        for _, action in ipairs(BLUEPRINT_ACTIONS) do
            local allow = state and not UNTRUSTED_DENY_IDS[action]
            untrusted.set_allows_action(action, allow and true or false)
        end
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.blueprints-caption' },
    tooltip = { 'fp-admin.blueprints-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = apply,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        apply(new_state)
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.blueprints-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
Event.add(de.on_player_joined_game, function()
    apply(Config.is_enabled(TOGGLE_ID))
end)
