local const = require 'lib.belt_visualizer.constants'
local color = const.color
local width = const.width
local dash_length = const.dash_length
local gap_length = const.gap_length
local curved = const.curved
local arc_radius = const.arc_radius
local radius = const.radius
local draw = {}
local function offset_key(offset)
    return offset[1] .. ',' .. offset[2]
end
function draw.line(pd, entity, from_offset, to_offset)
    local drawn = pd.drawn_offsets[entity.unit_number]
    if not drawn then
        drawn = {}
        pd.drawn_offsets[entity.unit_number] = drawn
    end
    local from_key = offset_key(from_offset)
    local to_key = offset_key(to_offset)
    if drawn[from_key] and drawn[to_key] then return end
    drawn[from_key] = true
    drawn[to_key] = true
    local render = rendering.draw_line{
        color = color,
        width = width,
        from = { entity = entity, offset = from_offset },
        to = { entity = entity, offset = to_offset },
        surface = entity.surface,
        players = { pd.index },
    }
    pd.render[render.id] = render
end
function draw.dash(pd, from, to, from_offset, to_offset)
    local render = rendering.draw_line{
        color = color,
        width = width,
        from = { entity = from, offset = from_offset },
        to = { entity = to, offset = to_offset },
        dash_length = dash_length,
        gap_length = gap_length,
        surface = from.surface,
        players = { pd.index },
    }
    pd.render[render.id] = render
end
function draw.arc(pd, entity, lane, clockwise)
    local drawn = pd.drawn_arcs[entity.unit_number]
    if not drawn then
        drawn = {}
        pd.drawn_arcs[entity.unit_number] = drawn
    end
    if drawn[lane] then return end
    drawn[lane] = true
    local offset = ((clockwise and 4 or 0) + entity.direction) % 16
    lane = clockwise and lane % 2 + 1 or lane
    local radii = arc_radius[lane]
    local render = rendering.draw_arc{
        color = color,
        min_radius = radii.min,
        max_radius = radii.max,
        start_angle = math.rad(offset * 45 / 2),
        angle = math.rad(90),
        target = { entity = entity, offset = curved[offset] },
        surface = entity.surface,
        players = { pd.index },
    }
    pd.render[render.id] = render
end
function draw.circle(pd, entity, offset)
    local render = rendering.draw_circle{
        color = color,
        radius = radius,
        filled = true,
        target = { entity = entity, offset = offset },
        surface = entity.surface,
        players = { pd.index },
    }
    pd.render[render.id] = render
end
function draw.rectangle(pd, entity, offsets)
    local render = rendering.draw_rectangle{
        color = color,
        filled = true,
        left_top = { entity = entity, offset = offsets.left_top },
        right_bottom = { entity = entity, offset = offsets.right_bottom },
        surface = entity.surface,
        players = { pd.index },
    }
    pd.render[render.id] = render
end
return draw
