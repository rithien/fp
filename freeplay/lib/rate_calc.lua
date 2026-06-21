local Event = require 'lib.event'
local Calc = require 'lib.rate_calc.calc'
local Util = require 'lib.rate_calc.util'
local RateCalcWindow = require 'gui.rate_calc_window'
local DebugLog = require 'lib.debug_log'
local Config = require 'lib.config'
local Task = require 'lib.task'
local Token = require 'lib.token'
local de = defines.events
local RATE_CALC_TOGGLE_ID = 'rate_calc'
local function filter_calculable(entities)
    local calculable = {}
    local skipped = {} 
    for _, e in pairs(entities) do
        if e and e.valid then
            if Calc.CALCULABLE_TYPES[e.type] then
                calculable[#calculable + 1] = e
            else
                skipped[e.type] = (skipped[e.type] or 0) + 1
            end
        end
    end
    return calculable, skipped
end
local function format_breakdown(breakdown)
    local parts = {}
    for type_name, count in pairs(breakdown) do
        parts[#parts + 1] = count .. ' ' .. type_name
    end
    table.sort(parts)
    return table.concat(parts, ', ')
end
local RateCalc = {}
local SELECTION_TOOL = 'copy-paste-tool'
local function ensure_storage()
    if not storage.rate_calc then
        storage.rate_calc = {
            mode = {},       
        }
    end
    if not storage.rate_calc.mode then storage.rate_calc.mode = {} end
end
Event.on_init(ensure_storage)
Event.on_configuration_changed(ensure_storage)
local restore_tool_token = Token.register(function(params)
    local player = game.get_player(params.player_index)
    if not player or not player.valid then return end
    if not storage.rate_calc or not storage.rate_calc.mode[params.player_index] then return end
    local stack = player.cursor_stack
    if stack and stack.valid_for_read and (stack.is_blueprint or stack.is_blueprint_book) then
        stack.set_stack({ name = SELECTION_TOOL, count = 1 })
    end
end)
function RateCalc.is_enabled()
    return Config.is_enabled(RATE_CALC_TOGGLE_ID)
end
function RateCalc.set_enabled(new_state)
    ensure_storage()
    Config.set(RATE_CALC_TOGGLE_ID, new_state)
    if not new_state then
        for player_index in pairs(storage.rate_calc.mode) do
            local player = game.get_player(player_index)
            if player and player.valid then
                local stack = player.cursor_stack
                if stack and stack.valid_for_read and stack.name == SELECTION_TOOL then
                    player.clear_cursor()
                end
            end
        end
        storage.rate_calc.mode = {}
    end
end
function RateCalc.is_in_mode(player_index)
    ensure_storage()
    return storage.rate_calc.mode[player_index] == true
end
function RateCalc.enter_mode(player)
    ensure_storage()
    if not RateCalc.is_enabled() then
        return
    end
    local stack = player.cursor_stack
    if not stack then return end
    if not player.clear_cursor() then return end
    if stack.set_stack({ name = SELECTION_TOOL, count = 1 }) then
        storage.rate_calc.mode[player.index] = true
    end
end
function RateCalc.exit_mode(player, clear_cursor)
    ensure_storage()
    storage.rate_calc.mode[player.index] = nil
    if clear_cursor then
        local stack = player.cursor_stack
        if stack and stack.valid_for_read and stack.name == SELECTION_TOOL then
            player.clear_cursor()
        end
    end
end
local function dump_set_to_chat(set, player)
    local has_errors = false
    for err in pairs(set.errors) do
        if not has_errors then
            player.print({ 'fp-rate-calc.dbg-errors-header' }, { color = { r = 1, g = 0.4, b = 0.4 } })
            has_errors = true
        end
        player.print({ 'fp-rate-calc.dbg-err-line', err }, { color = { r = 1, g = 0.5, b = 0.5 } })
    end
    if set.crash_log and #set.crash_log > 0 then
        player.print({ 'fp-rate-calc.dbg-crash-header', #set.crash_log },
            { color = { r = 1, g = 0.3, b = 0.3 } })
        for i = 1, math.min(#set.crash_log, 5) do
            player.print({ 'fp-rate-calc.dbg-crash-line', set.crash_log[i] }, { color = { r = 1, g = 0.4, b = 0.4 } })
        end
        if #set.crash_log > 5 then
            player.print({ 'fp-rate-calc.dbg-crash-more', #set.crash_log - 5 })
        end
    end
    local empty = true
    for path, rates in pairs(set.rates) do
        empty = false
        local out = rates.output.rate
        local inp = rates.input.rate
        local net = out - inp
        local label = path
        if rates.name == Util.POWER_KEY then label = label .. ' (POWER W)' end
        if rates.name == Util.HEAT_KEY then label = label .. ' (HEAT W)' end
        if rates.name == Util.POLLUTION_KEY then label = label .. ' (POLLUTION/s)' end
        player.print({ 'fp-rate-calc.dbg-rate-line',
            label,
            string.format('%.3f', out),
            string.format('%.3f', inp),
            string.format('%+.3f', net),
            rates.output.machines, rates.input.machines
        })
    end
    if empty and not has_errors and (not set.crash_log or #set.crash_log == 0) then
        player.print({ 'fp-rate-calc.dbg-no-rates' },
            { color = { r = 1, g = 1, b = 0.5 } })
    end
end
local MAX_CALCULABLE = 2000
local function run_calc(player_index, raw_entities, area, surface, invert)
    ensure_storage()
    if not storage.rate_calc.mode[player_index] then
        return 
    end
    local player = game.get_player(player_index)
    if not player or not player.valid then return end
    local entities = raw_entities
    if not entities and area and surface then
        entities = surface.find_entities_filtered({ area = area })
    end
    entities = entities or {}
    local total = 0
    for _ in pairs(entities) do total = total + 1 end
    if total == 0 then
        player.print({ 'fp-rate-calc.empty-selection' })
        return 
    end
    local calculable, skipped = filter_calculable(entities)
    if #calculable == 0 then
        local msg
        if next(skipped) then
            msg = { 'fp-rate-calc.none-calculable-skipped', total, format_breakdown(skipped) }
        else
            msg = { 'fp-rate-calc.none-calculable', total }
        end
        player.print(msg, { color = { r = 1, g = 1, b = 0.5 } })
        return 
    end
    if #calculable > MAX_CALCULABLE then
        player.print({ 'fp-rate-calc.selection-too-large', #calculable, MAX_CALCULABLE },
            { color = { r = 1, g = 1, b = 0.5 } })
        return
    end
    local set = Calc.run(player, calculable, invert)
    local calc_breakdown = {}
    for _, e in pairs(calculable) do
        calc_breakdown[e.type] = (calc_breakdown[e.type] or 0) + 1
    end
    local header
    if next(skipped) then
        header = { 'fp-rate-calc.header-calculable-skipped', #calculable, format_breakdown(calc_breakdown), format_breakdown(skipped) }
    else
        header = { 'fp-rate-calc.header-calculable', #calculable, format_breakdown(calc_breakdown) }
    end
    player.print(header, { color = { r = 0.5, g = 1, b = 0.5 } })
    RateCalcWindow.show(player, set)
    if DebugLog.is_enabled() then
        dump_set_to_chat(set, player)
    end
end
local function handle_selected_area(event)
    if event.item ~= SELECTION_TOOL then return end
    local invert = event.name == de.on_player_reverse_selected_area
        or event.name == de.on_player_alt_reverse_selected_area
    run_calc(event.player_index, event.entities, event.area, event.surface, invert)
end
local function handle_setup_blueprint(event)
    local entities = nil
    if event.mapping and event.mapping.valid then
        entities = event.mapping.get()
    end
    run_calc(event.player_index, entities, event.area, event.surface, false)
    ensure_storage()
    if storage.rate_calc.mode[event.player_index] then
        Task.set_timeout_in_ticks(1, restore_tool_token, { player_index = event.player_index })
    end
end
Event.add(de.on_player_selected_area, handle_selected_area)
Event.add(de.on_player_alt_selected_area, handle_selected_area)
Event.add(de.on_player_reverse_selected_area, handle_selected_area)
Event.add(de.on_player_alt_reverse_selected_area, handle_selected_area)
Event.add(de.on_player_setup_blueprint, handle_setup_blueprint)
Event.add(de.on_player_cursor_stack_changed, function(event)
    ensure_storage()
    if not storage.rate_calc.mode[event.player_index] then
        return
    end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    local stack = player.cursor_stack
    if not stack or not stack.valid_for_read then
        storage.rate_calc.mode[event.player_index] = nil
        return
    end
    if stack.name == SELECTION_TOOL then
        return
    end
    if stack.is_blueprint or stack.is_blueprint_book then
        return
    end
    storage.rate_calc.mode[event.player_index] = nil
end)
return RateCalc
