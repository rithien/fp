local DebugLog = require 'lib.debug_log'
local Compat = require 'lib.compat'  
local M = {}      
local T = {}      
local B = {}      
local function count_pairs(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end
M.max_int53 = 9007199254740991 
function M.clamp(value, lo, hi)
    return math.max(lo, math.min(hi, value))
end
function T.invert(t)
    local r = {}
    for k, v in pairs(t) do r[v] = k end
    return r
end
function B.from_dimensions(pos, w, h)
    return {
        left_top = { x = pos.x - w / 2, y = pos.y - h / 2 },
        right_bottom = { x = pos.x + w / 2, y = pos.y + h / 2 }
    }
end
local POWER_KEY = '__power'
local HEAT_KEY = '__heat'
local POLLUTION_KEY = '__pollution'
local Util = {
    POWER_KEY = POWER_KEY,
    HEAT_KEY = HEAT_KEY,
    POLLUTION_KEY = POLLUTION_KEY,
    count_pairs = count_pairs,  
}
function Util.add_error(set, err)
    DebugLog.log('[rate_calc]     add_error: ' .. err)
    set.errors[err] = true
end
function Util.add_rate(set, category, type, name, quality, amount, invert, machine_name, temperature)
    DebugLog.log('[rate_calc]     add_rate: cat=%s type=%s name=%s qual=%s amount=%.4f machine=%s',
        tostring(category), tostring(type), tostring(name), tostring(quality),
        tonumber(amount) or -1, tostring(machine_name))
    local set_rates = set.rates
    local path = type .. '/' .. name .. '/' .. quality .. (temperature or '')
    local rates = set_rates[path]
    if not rates then
        if invert then
            return 
        end
        rates = {
            type = type,
            name = name,
            quality = quality,
            temperature = temperature,
            output = { machines = 0, machine_counts = {}, rate = 0 },
            input = { machines = 0, machine_counts = {}, rate = 0 },
        }
        set_rates[path] = rates
    end
    if invert then amount = -amount end
    local rate = rates[category]
    local skip_amount = false
    if machine_name then
        local counts = rate.machine_counts
        if not counts[machine_name] and invert then
            skip_amount = true
        else
            counts[machine_name] = (counts[machine_name] or 0) + (invert and -1 or 1)
            if counts[machine_name] == 0 then
                counts[machine_name] = nil
            end
        end
    end
    if not skip_amount then
        rate.rate = math.max(rate.rate + amount, 0)
        rate.machines = rate.machines + (invert and -1 or 1)
        if rate.rate < 0.00001 then rate.rate = 0 end
    end
    if rates.input.machines == 0 and rates.output.machines == 0 then
        set_rates[path] = nil
        DebugLog.log('[rate_calc]     add_rate DONE: path=%s CLEANUP (in=0/out=0) set_rates_ref=%s count=%d',
            path, tostring(set_rates), count_pairs(set_rates))
    else
        DebugLog.log('[rate_calc]     add_rate DONE: path=%s in.machines=%d out.machines=%d in.rate=%.4f out.rate=%.4f set_rates_ref=%s set.rates_ref=%s count=%d still_has_key=%s',
            path, rates.input.machines, rates.output.machines,
            rates.input.rate, rates.output.rate,
            tostring(set_rates), tostring(set.rates),
            count_pairs(set_rates), tostring(set_rates[path] ~= nil))
    end
end
local function get_fluid(entity, index)
    local name = Compat.fluid_name_at(entity, index)
    if name then
        return prototypes.fluid[name]
    end
end
function Util.process_burner(set, entity, invert, emissions_per_second)
    local entity_prototype = entity.prototype
    local burner_prototype = entity_prototype.burner_prototype
    local burner = entity.burner
    local currently_burning = burner.currently_burning
    if not currently_burning then
        local contents = burner.inventory.get_contents()
        for _, content in ipairs(contents) do
            if content and content.name then
                currently_burning = {
                    name = prototypes.item[content.name],
                    quality = prototypes.quality[content.quality or 'normal']
                }
                break
            end
        end
        if not currently_burning then
            for name, value in pairs(contents) do
                if type(name) == 'string' and prototypes.item[name] then
                    currently_burning = {
                        name = prototypes.item[name],
                        quality = prototypes.quality[(type(value) == 'table' and value.quality) or 'normal']
                    }
                    break
                end
            end
        end
    end
    if not currently_burning then
        log(string.format(
            '[rate_calc] process_burner no-fuel: %s @ (%.1f,%.1f) currently_burning=%s contents=%s',
            entity.name, entity.position.x, entity.position.y,
            serpent.line(burner.currently_burning),
            serpent.line(burner.inventory.get_contents())
        ))
        Util.add_error(set, 'no-fuel')
        return emissions_per_second
    end
    local currently_burning_prototype = currently_burning.name
    if type(currently_burning_prototype) == 'string' then
        currently_burning_prototype = prototypes.item[currently_burning_prototype]
    end
    if type(currently_burning.quality) == 'string' then
        currently_burning.quality = prototypes.quality[currently_burning.quality]
    end
    if not currently_burning_prototype then
        log(string.format(
            '[rate_calc] process_burner: unrecognized fuel item — %s @ (%.1f,%.1f) currently_burning=%s',
            entity.name, entity.position.x, entity.position.y,
            serpent.line(burner.currently_burning)
        ))
        Util.add_error(set, 'no-fuel')
        return emissions_per_second
    end
    if currently_burning_prototype.fuel_value <= 0 then
        Util.add_error(set, 'zero-fuel-value')
        return emissions_per_second
    end
    local max_energy_usage = entity_prototype.get_max_energy_usage(entity.quality) * (entity.consumption_bonus + 1)
    local burns_per_second = 1
        / (currently_burning_prototype.fuel_value / (max_energy_usage / burner_prototype.effectivity) / 60)
    Util.add_rate(set, 'input', 'item', currently_burning_prototype.name,
        currently_burning.quality.name, burns_per_second, invert, entity.name)
    local burnt_result = currently_burning_prototype.burnt_result
    if burnt_result then
        Util.add_rate(set, 'output', 'item', burnt_result.name,
            currently_burning.quality.name, burns_per_second, invert, entity.name)
    end
    local emissions = (burner_prototype.emissions_per_joule[set.pollutant] or 0)
        * 60
        * max_energy_usage
        * currently_burning_prototype.fuel_emissions_multiplier
    return emissions_per_second + emissions
end
function Util.process_beacon(set, entity)
    if entity.status == defines.entity_status.no_power then
        Util.add_error(set, 'no-power')
    end
end
function Util.process_boiler(set, entity, invert)
    local entity_prototype = entity.prototype
    local input_fluid = get_fluid(entity, 1)
    if not input_fluid then
        Util.add_error(set, 'no-input-fluid')
        return
    end
    local minimum_temperature = Compat.fluidbox_prototype(entity, 1).minimum_temperature or input_fluid.default_temperature
    local energy_per_amount = (entity_prototype.target_temperature - minimum_temperature) * input_fluid.heat_capacity
    if energy_per_amount <= 0 then
        Util.add_error(set, 'zero-energy-fluid')
        return
    end
    local fluid_usage = entity_prototype.get_max_energy_usage(entity.quality) / energy_per_amount * 60
    Util.add_rate(set, 'input', 'fluid', input_fluid.name, 'normal', fluid_usage, invert, entity.name)
    if entity_prototype.boiler_mode == 'heat-water-inside' then
        Util.add_rate(set, 'output', 'fluid', input_fluid.name, 'normal',
            fluid_usage, invert, entity.name, input_fluid.max_temperature)
        return
    end
    local output_fluid = get_fluid(entity, 2)
    if not output_fluid then
        return
    end
    local min_t = Compat.fluidbox_prototype(entity, 2).minimum_temperature or output_fluid.default_temperature
    local epa = (entity_prototype.target_temperature - min_t) * output_fluid.heat_capacity
    if epa <= 0 then 
        Util.add_error(set, 'zero-energy-fluid')
        return
    end
    local out_usage = entity_prototype.get_max_energy_usage(entity.quality) / epa * 60
    Util.add_rate(set, 'output', 'fluid', output_fluid.name, 'normal', out_usage, invert, entity.name)
end
function Util.process_crafter(set, entity, invert, emissions_per_second)
    local recipe, quality = entity.get_recipe()
    DebugLog.log('[rate_calc]   process_crafter: entity=%s recipe=%s quality=%s',
        entity.name, recipe and recipe.name or 'NIL', quality and quality.name or 'NIL')
    if not recipe and entity.type == 'furnace' then
        local prev = entity.previous_recipe
        if prev then
            recipe = set.player.force.recipes[prev.name.name]
            quality = prev.quality
            DebugLog.log('[rate_calc]   process_crafter: furnace fallback to previous_recipe=%s',
                recipe and recipe.name or 'NIL')
        end
    end
    if not recipe then
        Util.add_error(set, 'no-recipe')
        return emissions_per_second
    end
    local recipe_duration = recipe.energy / entity.crafting_speed
    DebugLog.log('[rate_calc]   process_crafter: ingredients=%d products=%d duration=%.3f',
        #recipe.ingredients, #recipe.products, recipe_duration)
    for _, ingredient in pairs(recipe.ingredients) do
        local amount = ingredient.amount / recipe_duration
        Util.add_rate(set, 'input', ingredient.type, ingredient.name,
            ingredient.type == 'item' and quality.name or 'normal',
            amount, invert, entity.name)
    end
    local productivity = 1
        + math.min(entity.productivity_bonus + recipe.productivity_bonus, recipe.prototype.maximum_productivity)
    for _, product in pairs(recipe.products) do
        if product.type == 'research-progress' then
            goto continue
        end
        local extra_count_fraction = product.extra_count_fraction or 0
        local max_amount = product.amount_max or product.amount
        local min_amount = product.amount_min or product.amount
        local expected_amount = (product.probability or 1) * 0.5 * (max_amount + min_amount) + extra_count_fraction
        local productivity_base_complement = math.min(expected_amount, product.ignored_by_productivity or 0)
        local productivity_base = expected_amount - productivity_base_complement
        local amount = (productivity_base_complement + productivity_base * productivity) / recipe_duration
        Util.add_rate(set, 'output', product.type, product.name,
            product.type == 'item' and quality.name or 'normal',
            amount, invert, entity.name, product.temperature)
        ::continue::
    end
    return emissions_per_second * recipe.prototype.emissions_multiplier * (1 + entity.pollution_bonus)
end
function Util.process_electric_energy_source(set, entity, invert, emissions_per_second)
    local entity_prototype = entity.prototype
    DebugLog.log('[rate_calc]   process_eep: entity=%s max_energy_usage=%s max_energy_production=%s drain=%s',
        entity.name,
        tostring(entity_prototype.get_max_energy_usage(entity.quality)),
        tostring(entity_prototype.get_max_energy_production(entity.quality)),
        tostring(entity_prototype.electric_energy_source_prototype and entity_prototype.electric_energy_source_prototype.drain))
    if entity.type == 'electric-energy-interface' then
        local production = entity.power_production * 60
        if production > 0 then
            Util.add_rate(set, 'output', 'item', POWER_KEY, 'normal', production, invert, entity.name)
        end
        local usage = entity.power_usage * 60
        if usage > 0 then
            Util.add_rate(set, 'input', 'item', POWER_KEY, 'normal', usage, invert, entity.name)
        end
        return emissions_per_second
    end
    local electric_source_prototype = entity_prototype.electric_energy_source_prototype
    local added_emissions = 0
    local max_energy_usage = entity_prototype.get_max_energy_usage(entity.quality) or 0
    if max_energy_usage > 0 and max_energy_usage < M.max_int53 then
        local consumption_bonus = (entity.consumption_bonus + 1)
        local drain = electric_source_prototype.drain
        local amount = max_energy_usage * consumption_bonus
        if max_energy_usage ~= drain then
            amount = amount + drain
        end
        Util.add_rate(set, 'input', 'item', POWER_KEY, 'normal', amount * 60, invert, entity.name)
        if entity.status == defines.entity_status.no_power then
            Util.add_error(set, 'no-power')
        end
        added_emissions = (electric_source_prototype.emissions_per_joule[set.pollutant] or 0)
            * (max_energy_usage * consumption_bonus)
            * 60
    end
    local max_energy_production = entity_prototype.get_max_energy_production(entity.quality)
    if max_energy_production > 0 and max_energy_production < M.max_int53 then
        if entity.type == 'solar-panel' then
            max_energy_production = max_energy_production
                * entity.surface.solar_power_multiplier
                * entity.surface.get_property('solar-power')
                / prototypes.surface_property['solar-power'].default_value
        end
        Util.add_rate(set, 'output', 'item', POWER_KEY, 'normal',
            max_energy_production * 60, invert, entity.name)
    end
    return emissions_per_second + added_emissions
end
function Util.process_fluid_energy_source(set, entity, invert, emissions_per_second)
    local entity_prototype = entity.prototype
    local fluid_source_prototype = entity_prototype.fluid_energy_source_prototype
    local fluid_count = Compat.fluidbox_count(entity)
    local fluid_prototype
    if entity.type == 'boiler' then
        fluid_prototype = get_fluid(entity, fluid_count)
    else
        fluid_prototype = get_fluid(entity, 1)
    end
    if not fluid_prototype then
        Util.add_error(set, 'no-input-fluid')
        return emissions_per_second
    end
    local max_energy_usage = entity_prototype.get_max_energy_usage(entity.quality) * (entity.consumption_bonus + 1)
    local value
    if fluid_source_prototype.scale_fluid_usage then
        if fluid_source_prototype.burns_fluid and fluid_prototype.fuel_value > 0 then
            value = max_energy_usage / (fluid_prototype.fuel_value / 60) / fluid_source_prototype.effectivity
        else
            local fluid = Compat.fluid_at(entity, fluid_count)
            if not fluid then
                Util.add_error(set, 'no-input-fluid')
                return emissions_per_second
            end
            local temperature_value = fluid.temperature - fluid_prototype.default_temperature
            if temperature_value > 0 then
                value = max_energy_usage
                    / (temperature_value * fluid_prototype.heat_capacity)
                    / fluid_source_prototype.effectivity
                    * 60
            end
        end
    else
        value = fluid_source_prototype.fluid_usage_per_tick / fluid_source_prototype.effectivity * 60
    end
    if not value then
        return emissions_per_second
    end
    Util.add_rate(set, 'input', 'fluid', fluid_prototype.name, 'normal', value, invert, entity.name)
    return (fluid_source_prototype.emissions_per_joule[set.pollutant] or 0) * max_energy_usage * 60
end
function Util.process_generator(set, entity, invert)
    local entity_prototype = entity.prototype
    local fluid = get_fluid(entity, 1)
    if not fluid then
        Util.add_error(set, 'no-input-fluid')
        return
    end
    Util.add_rate(set, 'input', 'fluid', fluid.name, 'normal',
        entity_prototype.get_fluid_usage_per_tick(entity.quality) * 60, invert, entity.name)
end
function Util.process_heat_energy_source(set, entity, invert)
    Util.add_rate(set, 'input', 'item', HEAT_KEY, 'normal',
        entity.prototype.get_max_energy_usage(entity.quality) * (1 + entity.consumption_bonus) * 60,
        invert, entity.name)
end
function Util.process_lab(set, entity, invert)
    local research_data = set.research_data
    if not research_data then
        Util.add_error(set, 'no-active-research')
        return
    end
    local science_pack_drain = entity.prototype.science_pack_drain_rate_percent / 100
    local research_multiplier = research_data.multiplier
    local researching_speed = entity.prototype.get_researching_speed(entity.quality)
    local speed_modifier = research_data.speed_modifier
    local lab_multiplier = research_multiplier
        * ((entity.speed_bonus + 1 - speed_modifier) * (speed_modifier + 1))
        * researching_speed
        * science_pack_drain
    local inputs = T.invert(entity.prototype.lab_inputs)
    for _, ingredient in pairs(research_data.ingredients) do
        if not inputs[ingredient.name] then
            Util.add_error(set, 'incompatible-science-packs')
            return
        end
    end
    for _, ingredient in ipairs(research_data.ingredients) do
        local amount = (ingredient.amount * lab_multiplier) / prototypes.item[ingredient.name].get_durability()
        Util.add_rate(set, 'input', 'item', ingredient.name, 'normal', amount, invert, entity.name)
    end
end
function Util.process_mining_drill(set, entity, invert)
    local entity_prototype = entity.prototype
    local entity_productivity_bonus = entity.productivity_bonus
    local entity_speed_bonus = entity.speed_bonus
    local radius = entity_prototype.mining_drill_radius + 0.01
    local box = B.from_dimensions(entity.position, radius * 2, radius * 2)
    local resource_entities = entity.surface.find_entities_filtered({ area = box, type = 'resource' })
    local resource_entities_len = #resource_entities
    if resource_entities_len == 0 then
        Util.add_error(set, 'no-mineable-resources')
        return
    end
    local resources = {}
    local num_resource_entities = 0
    local has_fluidbox = next(entity_prototype.fluidbox_prototypes) and true or false
    local resource_categories = entity_prototype.resource_categories or {}
    for i = 1, resource_entities_len do
        local resource = resource_entities[i]
        local resource_name = resource.name
        local resource_data = resources[resource_name]
        if resource_data then
            resource_data.occurrences = resource_data.occurrences + 1
            num_resource_entities = num_resource_entities + 1
            goto continue
        end
        local resource_prototype = resource.prototype
        if not resource_categories[resource_prototype.resource_category] then
            goto continue
        end
        local mineable_properties = resource_prototype.mineable_properties
        local required_fluid = mineable_properties.required_fluid
        if required_fluid and not has_fluidbox then
            goto continue
        end
        num_resource_entities = num_resource_entities + 1
        resource_data = {
            occurrences = 1,
            products = mineable_properties.products,
            mining_time = mineable_properties.mining_time,
        }
        if resource_prototype.infinite_resource then
            resource_data.mining_time = resource_data.mining_time
                / (resource.amount / resource_prototype.normal_resource_amount)
        end
        if required_fluid then
            resource_data.required_fluid = {
                type = 'fluid',
                name = required_fluid,
                amount = mineable_properties.fluid_amount / 10, 
                probability = 1,
            }
        end
        resources[resource_name] = resource_data
        ::continue::
    end
    if num_resource_entities == 0 then
        Util.add_error(set, 'no-mineable-resources')
        return
    end
    local adjusted_mining_speed = entity_prototype.mining_speed
        * (entity_speed_bonus + 1)
        * (entity_productivity_bonus + 1)
    for _, resource_data in pairs(resources) do
        local resource_multiplier = (adjusted_mining_speed / resource_data.mining_time)
            * (resource_data.occurrences / num_resource_entities)
        local required_fluid = resource_data.required_fluid
        if required_fluid then
            local fluid_per_second = required_fluid.amount * resource_multiplier / (entity_productivity_bonus + 1)
            Util.add_rate(set, 'input', 'fluid', required_fluid.name, 'normal',
                fluid_per_second, invert, entity.name)
        end
        for _, product in pairs(resource_data.products or {}) do
            local product_per_second
            if product.amount then
                product_per_second = product.amount * resource_multiplier
            else
                product_per_second = ((product.amount_max + product.amount_min) / 2) * resource_multiplier
            end
            local adjusted_product_per_second = product_per_second * (product.probability or 1)
            Util.add_rate(set, 'output', product.type, product.name, 'normal',
                adjusted_product_per_second, invert, entity.name, product.temperature)
        end
    end
end
function Util.process_offshore_pump(set, entity, invert)
    local fluid = Compat.fluid_at(entity, 1)
    if not fluid then
        return
    end
    local pumping_speed = entity.prototype.get_pumping_speed(entity.quality)
    Util.add_rate(set, 'output', 'fluid', fluid.name, 'normal',
        pumping_speed * 60, invert, entity.name)
end
function Util.process_reactor(set, entity, invert)
    Util.add_rate(set, 'output', 'item', HEAT_KEY, 'normal',
        entity.prototype.get_max_energy_usage(entity.quality)
            * (1 + entity.neighbour_bonus)
            * (1 + entity.consumption_bonus)
            * 60,
        invert, entity.name)
end
return Util
