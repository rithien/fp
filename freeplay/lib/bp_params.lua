local Event = require 'lib.event'
local Config = require 'lib.config'
local TOGGLE_ID = 'bp_params'
local BpParams = {}
local function ensure_storage()
    if not storage.bp_params then
        storage.bp_params = { slots = {} }
    end
    if not storage.bp_params.slots then storage.bp_params.slots = {} end
end
Event.on_init(ensure_storage)
Event.on_configuration_changed(ensure_storage)
function BpParams.is_enabled()
    return Config.is_enabled(TOGGLE_ID)
end
function BpParams.set_enabled(new_state)
    Config.set(TOGGLE_ID, new_state)
end
function BpParams.get_slots(player_index)
    ensure_storage()
    local slots = storage.bp_params.slots[player_index]
    if not slots then
        slots = {}
        storage.bp_params.slots[player_index] = slots
    end
    return slots
end
function BpParams.clear_slots(player_index)
    ensure_storage()
    storage.bp_params.slots[player_index] = nil
end
local function decode(bp_string)
    if type(bp_string) ~= 'string' or #bp_string < 2 then return nil end
    local json = helpers.decode_string(string.sub(bp_string, 2))
    if not json then return nil end
    local tbl = helpers.json_to_table(json)
    if type(tbl) ~= 'table' then return nil end
    return tbl
end
local function encode(tbl)
    local json = helpers.table_to_json(tbl)
    if not json then return nil end
    local packed = helpers.encode_string(json)
    if not packed then return nil end
    return '0' .. packed
end
function BpParams.snapshot_cursor(player)
    if not player or not player.valid then return nil, nil end
    local stack = player.cursor_stack
    if not stack or not stack.valid_for_read then
        if player.cursor_record then
            return nil, 'fp-bp-params.library-error'
        end
        return nil, 'fp-bp-params.empty-cursor'
    end
    if not stack.is_blueprint then
        return nil, 'fp-bp-params.not-blueprint'
    end
    if not stack.is_blueprint_setup() then
        return nil, 'fp-bp-params.empty-blueprint'
    end
    local exported = stack.export_stack()
    local decoded = decode(exported)
    if not decoded or not decoded.blueprint then
        return nil, 'fp-bp-params.decode-error'
    end
    local params = decoded.blueprint.parameters
    return {
        string = exported,
        label = stack.label,
        param_count = params and #params or 0,
    }, nil
end
function BpParams.get_parameters(bp_string)
    local decoded = decode(bp_string)
    if not decoded or not decoded.blueprint then
        return nil, 'fp-bp-params.decode-error'
    end
    return decoded.blueprint.parameters or {}, nil
end
function BpParams.apply_parameters(bp_string, params)
    local decoded = decode(bp_string)
    if not decoded or not decoded.blueprint then
        return nil, 'fp-bp-params.decode-error'
    end
    if params and #params == 0 then params = nil end
    decoded.blueprint.parameters = params
    local result = encode(decoded)
    if not result then
        return nil, 'fp-bp-params.encode-error'
    end
    return result, nil
end
function BpParams.copy_parameters(source_string, target_string)
    local params, err = BpParams.get_parameters(source_string)
    if not params then
        return nil, err
    end
    if #params == 0 then
        return nil, 'fp-bp-params.no-source-params'
    end
    local result, apply_err = BpParams.apply_parameters(target_string, params)
    if not result then
        return nil, apply_err
    end
    return result, nil, #params
end
Event.add(defines.events.on_player_left_game, function(event)
    if storage.bp_params and storage.bp_params.slots then
        storage.bp_params.slots[event.player_index] = nil
    end
end)
return BpParams
