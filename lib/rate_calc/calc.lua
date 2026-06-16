local Util = require 'lib.rate_calc.util'
local DebugLog = require 'lib.debug_log'
local Calc = {}
local ENTITY_BLACKLIST = {
    ['buffer-depot'] = true,
    ['fluid-depot'] = true,
    ['fuel-depot'] = true,
    ['request-depot'] = true,
}
Calc.CALCULABLE_TYPES = {
    ['accumulator'] = true,
    ['ammo-turret'] = true,
    ['arithmetic-combinator'] = true,
    ['artillery-turret'] = true,
    ['assembling-machine'] = true,
    ['beacon'] = true,
    ['boiler'] = true,
    ['burner-generator'] = true,
    ['constant-combinator'] = true,
    ['decider-combinator'] = true,
    ['electric-energy-interface'] = true,
    ['electric-turret'] = true,
    ['fluid-turret'] = true,
    ['furnace'] = true,
    ['generator'] = true,
    ['heat-interface'] = true,
    ['inserter'] = true,
    ['lab'] = true,
    ['lamp'] = true,
    ['loader'] = true,
    ['loader-1x1'] = true,
    ['locomotive'] = true,
    ['mining-drill'] = true,
    ['offshore-pump'] = true,
    ['programmable-speaker'] = true,
    ['pump'] = true,
    ['radar'] = true,
    ['reactor'] = true,
    ['roboport'] = true,
    ['rocket-silo'] = true,
    ['solar-panel'] = true,
    ['turret'] = true,
}
local function new_calculation_set(player)
    local force = player.force
    local current_research = force.current_research
    local research_data
    if current_research then
        research_data = {
            ingredients = current_research.research_unit_ingredients,
            multiplier = 1 / (current_research.research_unit_energy / 60),
            speed_modifier = force.laboratory_speed_modifier,
        }
    end
    local pollutant = ''
    local pollutant_prototype = player.surface.pollutant_type
    if pollutant_prototype then
        pollutant = pollutant_prototype.name
    end
    return {
        completed = {},
        errors = {},
        player = player,
        rates = {},
        research_data = research_data,
        pollutant = pollutant,
    }
end
local function process_entity(set, entity, invert)
    DebugLog.log('[rate_calc] process_entity: name=%s type=%s', entity.name, entity.type)
    if ENTITY_BLACKLIST[entity.name] then
        DebugLog.log('[rate_calc]   blacklist-hit')
        return
    end
    local emissions_table = entity.prototype.emissions_per_second or {}
    local emissions_per_second = emissions_table[set.pollutant] or 0
    local type = entity.type
    if type == 'burner-generator' or type == 'generator' then
        DebugLog.log('[rate_calc]   energy-branch: burner-generator/generator → add_rate(__power output)')
        Util.add_rate(set, 'output', 'item', Util.POWER_KEY, 'normal',
            entity.prototype.get_max_power_output(entity.quality) * 60,
            invert, entity.name)
    elseif type ~= 'burner-generator' and entity.prototype.electric_energy_source_prototype then
        DebugLog.log('[rate_calc]   energy-branch: electric_energy_source')
        emissions_per_second = Util.process_electric_energy_source(set, entity, invert, emissions_per_second)
    elseif entity.prototype.fluid_energy_source_prototype then
        DebugLog.log('[rate_calc]   energy-branch: fluid_energy_source')
        emissions_per_second = Util.process_fluid_energy_source(set, entity, invert, emissions_per_second)
    elseif entity.prototype.heat_energy_source_prototype then
        DebugLog.log('[rate_calc]   energy-branch: heat_energy_source')
        Util.process_heat_energy_source(set, entity, invert)
    else
        DebugLog.log('[rate_calc]   energy-branch: NONE matched (electric=%s fluid=%s heat=%s)',
            tostring(entity.prototype.electric_energy_source_prototype ~= nil),
            tostring(entity.prototype.fluid_energy_source_prototype ~= nil),
            tostring(entity.prototype.heat_energy_source_prototype ~= nil))
    end
    if entity.burner then
        DebugLog.log('[rate_calc]   entity.burner present → process_burner')
        emissions_per_second = Util.process_burner(set, entity, invert, emissions_per_second)
    end
    if type == 'assembling-machine' or type == 'furnace' or type == 'rocket-silo' then
        DebugLog.log('[rate_calc]   type-branch: process_crafter')
        emissions_per_second = Util.process_crafter(set, entity, invert, emissions_per_second)
    elseif type == 'beacon' then
        DebugLog.log('[rate_calc]   type-branch: process_beacon')
        Util.process_beacon(set, entity)
    elseif type == 'boiler' then
        DebugLog.log('[rate_calc]   type-branch: process_boiler')
        Util.process_boiler(set, entity, invert)
    elseif type == 'lab' then
        DebugLog.log('[rate_calc]   type-branch: process_lab')
        Util.process_lab(set, entity, invert)
    elseif type == 'generator' then
        DebugLog.log('[rate_calc]   type-branch: process_generator')
        Util.process_generator(set, entity, invert)
    elseif type == 'mining-drill' then
        DebugLog.log('[rate_calc]   type-branch: process_mining_drill')
        Util.process_mining_drill(set, entity, invert)
    elseif type == 'offshore-pump' then
        DebugLog.log('[rate_calc]   type-branch: process_offshore_pump')
        Util.process_offshore_pump(set, entity, invert)
    elseif type == 'reactor' then
        DebugLog.log('[rate_calc]   type-branch: process_reactor')
        Util.process_reactor(set, entity, invert)
    else
        DebugLog.log('[rate_calc]   type-branch: NONE matched (no per-type processor)')
    end
    if emissions_per_second > 0 then
        Util.add_rate(set, 'output', 'item', Util.POLLUTION_KEY, 'normal',
            emissions_per_second, invert, entity.name)
    elseif emissions_per_second < 0 then
        Util.add_rate(set, 'input', 'item', Util.POLLUTION_KEY, 'normal',
            -emissions_per_second, invert, entity.name)
    end
    DebugLog.log('[rate_calc] process_entity DONE: %s (rates_count=%d errors_count=%d set.rates_ref=%s)',
        entity.name, Util.count_pairs(set.rates), Util.count_pairs(set.errors),
        tostring(set.rates))
end
function Calc.run(player, entities, invert)
    invert = invert == true
    local set = new_calculation_set(player)
    DebugLog.log('[rate_calc] Calc.run START: set.rates_ref=%s set.rates_count=%d (should be 0)',
        tostring(set.rates), Util.count_pairs(set.rates))
    set.crash_log = {}
    for _, entity in pairs(entities) do
        local ok, err = pcall(process_entity, set, entity, invert)
        if not ok then
            local label = string.format('%s (%s) @ (%.0f,%.0f): %s',
                entity.valid and entity.name or '?',
                entity.valid and entity.type or '?',
                entity.valid and entity.position.x or 0,
                entity.valid and entity.position.y or 0,
                tostring(err))
            table.insert(set.crash_log, label)
            log('[rate_calc] process_entity CRASH: ' .. label)
        end
    end
    DebugLog.log('[rate_calc] Calc.run END: set.rates_ref=%s set.rates_count=%d set.errors_count=%d crash_log_count=%d',
        tostring(set.rates), Util.count_pairs(set.rates), Util.count_pairs(set.errors), #set.crash_log)
    return set
end
return Calc
