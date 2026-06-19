local Event = require 'lib.event'
local Gui = require 'gui.init'
local Util = require 'lib.rate_calc.util'
local WINDOW_NAME = 'rcalc_window'
local CLOSE_ACTION = 'rcalc_window_close'
local POWER_KEY = Util.POWER_KEY        
local HEAT_KEY = Util.HEAT_KEY          
local POLLUTION_KEY = Util.POLLUTION_KEY 
local SHOW_CALCULATION_ERRORS = true
local SHOW_INTERMEDIATE_BREAKDOWNS = true
local SHOW_POLLUTION = false
local SHOW_POWER_CONSUMPTION = true
local SPECIAL_SPRITES = {
    [POWER_KEY] = 'utility/electricity_icon',
    [HEAT_KEY] = 'item/heat-pipe',
    [POLLUTION_KEY] = 'utility/danger_icon',
}
local SPECIAL_LABELS = {
    [POWER_KEY] = { 'fp-rate-calc.power' },
    [HEAT_KEY] = { 'fp-rate-calc.heat' },
    [POLLUTION_KEY] = { 'fp-rate-calc.pollution' },
}
local function format_si(value, is_watts, positive_prefix)
    local abs = math.abs(value)
    local prefix = ''
    local divisor = 1
    if abs >= 1e12 then
        prefix, divisor = 'T', 1e12
    elseif abs >= 1e9 then
        prefix, divisor = 'G', 1e9
    elseif abs >= 1e6 then
        prefix, divisor = 'M', 1e6
    elseif abs >= 1e3 then
        prefix, divisor = 'k', 1e3
    end
    local scaled = value / divisor
    local fmt
    if math.abs(scaled) >= 100 or divisor > 1 then
        fmt = '%.1f'
    elseif math.abs(scaled) >= 10 then
        fmt = '%.2f'
    elseif math.abs(scaled) >= 1 then
        fmt = '%.3f'
    else
        fmt = '%.4f'
    end
    local result = string.format(fmt, scaled)
    result = result:gsub('%.?0+$', function(suffix)
        if suffix:sub(1, 1) == '.' then return '' end
        return suffix
    end)
    if prefix ~= '' then
        result = result .. ' ' .. prefix
    end
    if is_watts then
        result = result .. (prefix == '' and ' W' or 'W')
    end
    if positive_prefix and value > 0 then
        result = '+' .. result
    end
    return result
end
local function build_machine_icons(machine_counts, include_numbers)
    local out = ''
    for name, count in pairs(machine_counts) do
        out = out .. '[entity=' .. name .. ']'
        if include_numbers then
            out = out .. ' ' .. count .. '  '
        end
    end
    return out
end
local function categorize_rates(set)
    local products = {}
    local intermediates = {}
    local ingredients = {}
    for path, rates in pairs(set.rates) do
        local is_watts = rates.name == POWER_KEY or rates.name == HEAT_KEY
        local is_pollution = rates.name == POLLUTION_KEY
        local is_power = rates.name == POWER_KEY
        if is_pollution and not SHOW_POLLUTION then
            goto continue
        end
        if is_power and not SHOW_POWER_CONSUMPTION and rates.output.rate == 0 then
            goto continue
        end
        local out = rates.output.rate
        local inp = rates.input.rate
        local category, sorting_rate
        if out > 0 and inp > 0 then
            category = 'intermediates'
            sorting_rate = out - inp
        elseif out > 0 then
            category = 'products'
            sorting_rate = out
        elseif inp > 0 then
            category = 'ingredients'
            sorting_rate = inp
        else
            goto continue 
        end
        local data = {
            path = path,
            type = rates.type,
            name = rates.name,
            quality = rates.quality,
            temperature = rates.temperature,
            output = rates.output,
            input = rates.input,
            category = category,
            sorting_rate = sorting_rate,
            is_watts = is_watts,
        }
        if category == 'products' then
            products[#products + 1] = data
        elseif category == 'intermediates' then
            intermediates[#intermediates + 1] = data
        else
            ingredients[#ingredients + 1] = data
        end
        ::continue::
    end
    local sort_desc = function(a, b) return a.sorting_rate > b.sorting_rate end
    table.sort(products, sort_desc)
    table.sort(intermediates, sort_desc)
    table.sort(ingredients, sort_desc)
    return {
        products = products,
        intermediates = intermediates,
        ingredients = ingredients,
    }
end
local function add_material_icon(parent, data)
    local sprite = SPECIAL_SPRITES[data.name]
    if sprite then
        parent.add({
            type = 'sprite-button',
            sprite = sprite,
            style = 'transparent_slot',
            tooltip = SPECIAL_LABELS[data.name] or data.name,
            ignored_by_interaction = true,
        })
        return
    end
    local sprite_path = data.type .. '/' .. data.name
    parent.add({
        type = 'sprite-button',
        sprite = sprite_path,
        style = 'transparent_slot',
        number = data.temperature, 
        ignored_by_interaction = true,
    })
end
local function build_row(parent, data)
    local flow = parent.add({
        type = 'flow',
        direction = 'horizontal',
    })
    flow.style.vertical_align = 'center'
    add_material_icon(flow, data)
    local category_rate = (data.category == 'ingredients') and data.input or data.output
    local machine_caption = build_machine_icons(category_rate.machine_counts, true)
    if data.category == 'intermediates' then
        machine_caption = machine_caption .. '→ ' .. build_machine_icons(data.input.machine_counts, true)
    end
    local machine_label = flow.add({
        type = 'label',
        caption = machine_caption,
        ignored_by_interaction = true,
    })
    machine_label.style.minimal_width = 100
    local pusher = flow.add({
        type = 'empty-widget',
        ignored_by_interaction = true,
    })
    pusher.style.horizontally_stretchable = true
    pusher.style.minimal_width = 20
    if data.category == 'intermediates' and SHOW_INTERMEDIATE_BREAKDOWNS then
        local breakdown_caption = string.format(
            '[color=150,255,150]%s[/color] - [color=255,150,150]%s[/color]',
            format_si(data.output.rate, data.is_watts, false),
            format_si(data.input.rate, data.is_watts, false)
        )
        flow.add({
            type = 'label',
            caption = breakdown_caption,
            ignored_by_interaction = true,
        })
    end
    local raw_rate, rate_color
    if data.category == 'intermediates' then
        raw_rate = data.output.rate - data.input.rate
        if raw_rate > 0.00001 then
            rate_color = '150,255,150' 
        elseif raw_rate < -0.00001 then
            rate_color = '255,150,150' 
        else
            rate_color = '255,255,255' 
        end
    else
        raw_rate = category_rate.rate
        rate_color = '255,255,255'
    end
    local rate_str = format_si(raw_rate, data.is_watts, data.category == 'intermediates')
    local rate_caption = string.format('[color=%s]%s[/color]', rate_color, rate_str)
    flow.add({
        type = 'label',
        caption = rate_caption,
        ignored_by_interaction = true,
    })
end
local function build_category(parent, header, rates_list)
    if #rates_list == 0 then return end
    local section = parent.add({
        type = 'flow',
        direction = 'vertical',
    })
    section.add({
        type = 'label',
        style = 'caption_label',
        caption = header,
    })
    for _, data in pairs(rates_list) do
        build_row(section, data)
    end
end
local RateCalcWindow = {}
function RateCalcWindow.destroy(player)
    if not player or not player.valid then return end
    Gui.destroy_if_exists(player.gui.screen, WINDOW_NAME)
end
function RateCalcWindow.show(player, set)
    if not player or not player.valid then return end
    RateCalcWindow.destroy(player)
    local frame = player.gui.screen.add({
        type = 'frame',
        name = WINDOW_NAME,
        direction = 'vertical',
    })
    frame.auto_center = true
    local titlebar = frame.add({ type = 'flow', direction = 'horizontal' })
    titlebar.add({
        type = 'label',
        caption = { 'fp-rate-calc.title' },
        style = 'frame_title',
    }).drag_target = frame
    local dragger = titlebar.add({
        type = 'empty-widget',
        style = 'draggable_space_header',
    })
    dragger.style.horizontally_stretchable = true
    dragger.style.vertically_stretchable = true
    dragger.style.height = 24
    dragger.drag_target = frame
    Gui.add(titlebar, {
        type = 'sprite-button',
        sprite = 'utility/close',
        style = 'frame_action_button',
        tooltip = { 'fp-rate-calc.close' },
        tags = { action = CLOSE_ACTION },
    })
    local inside = frame.add({
        type = 'frame',
        style = 'inside_shallow_frame',
        direction = 'vertical',
    })
    local scroll = inside.add({
        type = 'scroll-pane',
    })
    scroll.style.maximal_height = 600
    scroll.style.minimal_width = 500
    scroll.style.padding = 8
    local categories = categorize_rates(set)
    local has_ingredients = #categories.ingredients > 0
    local has_products = #categories.products > 0
    local has_intermediates = #categories.intermediates > 0
    if not has_ingredients and not has_products and not has_intermediates then
        scroll.add({
            type = 'label',
            caption = { 'fp-rate-calc.no-rates' },
        })
    else
        local main = scroll.add({ type = 'flow', direction = 'horizontal' })
        if has_ingredients then
            local left = main.add({ type = 'flow', direction = 'vertical' })
            build_category(left, { 'fp-rate-calc.ingredients' }, categories.ingredients)
            if has_products or has_intermediates then
                main.add({ type = 'line', direction = 'vertical' })
            end
        end
        if has_products or has_intermediates then
            local right = main.add({ type = 'flow', direction = 'vertical' })
            if has_products then
                build_category(right, { 'fp-rate-calc.products' }, categories.products)
                if has_intermediates then
                    right.add({ type = 'line', direction = 'horizontal' })
                end
            end
            if has_intermediates then
                build_category(right, { 'fp-rate-calc.intermediates' }, categories.intermediates)
            end
        end
    end
    if SHOW_CALCULATION_ERRORS and next(set.errors) then
        local errors_frame = frame.add({
            type = 'frame',
            style = 'subfooter_frame',
            direction = 'vertical',
        })
        for err in pairs(set.errors) do
            errors_frame.add({
                type = 'label',
                style = 'bold_label',
                caption = { '', '[img=utility/warning_white]  ', { 'fp-rate-calc.err-' .. err } },
            })
        end
    end
    player.opened = frame
end
Gui.on_click(CLOSE_ACTION, function(_, player)
    RateCalcWindow.destroy(player)
    if player.opened_gui_type == defines.gui_type.custom then
        player.opened = nil
    end
end)
Event.add(defines.events.on_gui_closed, function(event)
    if event.element and event.element.valid and event.element.name == WINDOW_NAME then
        event.element.destroy()
    end
end)
return RateCalcWindow
