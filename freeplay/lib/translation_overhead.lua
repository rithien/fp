local Public = {}
local OFFSET = { 0, -2.5 }       
local DEFAULT_SCALE, MIN_SCALE, MAX_SCALE = 1.2, 0.8, 4.0       
local DEFAULT_TTL_SEC, MIN_TTL_SEC, MAX_TTL_SEC = 5, 2, 20      
local COLOR_PALETTE = {
    { key = 'white',  caption = { 'fp-admin.color-white' },  rgb = { r = 1,    g = 1,    b = 1 } },
    { key = 'yellow', caption = { 'fp-admin.color-yellow' }, rgb = { r = 1,    g = 0.9,  b = 0.3 } },
    { key = 'cyan',   caption = { 'fp-admin.color-cyan' },   rgb = { r = 0.45, g = 0.9,  b = 1 } },
    { key = 'green',  caption = { 'fp-admin.color-green' },  rgb = { r = 0.5,  g = 1,    b = 0.5 } },
    { key = 'orange', caption = { 'fp-admin.color-orange' }, rgb = { r = 1,    g = 0.65, b = 0.25 } },
    { key = 'pink',   caption = { 'fp-admin.color-pink' },   rgb = { r = 1,    g = 0.6,  b = 0.85 } },
    { key = 'red',    caption = { 'fp-admin.color-red' },    rgb = { r = 1,    g = 0.4,  b = 0.4 } },
    { key = 'black',  caption = { 'fp-admin.color-black' },  rgb = { r = 0.05, g = 0.05, b = 0.05 } },
}
local DEFAULT_COLOR_KEY = 'white'
local function ensure_storage()
    if not storage.translation_overhead then storage.translation_overhead = {} end
end
function Public.get_scale_bounds() return MIN_SCALE, MAX_SCALE end
function Public.get_ttl_bounds() return MIN_TTL_SEC, MAX_TTL_SEC end
function Public.get_scale()
    ensure_storage()
    local s = storage.translation_overhead.scale
    return type(s) == 'number' and s or DEFAULT_SCALE
end
function Public.set_scale(v)
    if type(v) ~= 'number' then return end
    ensure_storage()
    if v < MIN_SCALE then v = MIN_SCALE elseif v > MAX_SCALE then v = MAX_SCALE end
    storage.translation_overhead.scale = math.floor(v * 10 + 0.5) / 10  
end
function Public.get_ttl_seconds()
    ensure_storage()
    local t = storage.translation_overhead.ttl_seconds
    return type(t) == 'number' and t or DEFAULT_TTL_SEC
end
function Public.set_ttl_seconds(v)
    if type(v) ~= 'number' then return end
    ensure_storage()
    if v < MIN_TTL_SEC then v = MIN_TTL_SEC elseif v > MAX_TTL_SEC then v = MAX_TTL_SEC end
    storage.translation_overhead.ttl_seconds = math.floor(v + 0.5)  
end
local function rgb_for_key(key)
    for _, c in ipairs(COLOR_PALETTE) do
        if c.key == key then return c.rgb end
    end
    return nil
end
function Public.get_color_choices()
    local out = {}
    for i, c in ipairs(COLOR_PALETTE) do
        out[i] = { key = c.key, caption = c.caption }
    end
    return out
end
function Public.get_color_rgb(key)
    return rgb_for_key(key)
end
function Public.get_color_key()
    ensure_storage()
    local k = storage.translation_overhead.color_key
    if type(k) == 'string' and rgb_for_key(k) then return k end
    return DEFAULT_COLOR_KEY
end
function Public.set_color_key(key)
    if type(key) ~= 'string' or not rgb_for_key(key) then return end
    ensure_storage()
    storage.translation_overhead.color_key = key
end
local function resolve_anchor(player)
    if player.controller_type == defines.controllers.remote then
        local surface = player.surface
        if surface and surface.valid then
            local pos = player.position  
            return surface, { position = { x = pos.x, y = pos.y + OFFSET[2] } }
        end
    end
    local char = player.character
    if char and char.valid then
        return char.surface, { entity = char, offset = OFFSET }
    end
    local surface = player.surface
    if surface and surface.valid then
        local pos = player.position
        return surface, { position = { x = pos.x, y = pos.y + OFFSET[2] } }
    end
    return nil, nil
end
local function draw_for_viewer(surface, target_spec, viewer, text, scale, ttl_ticks, color)
    if type(text) ~= 'string' or text == '' then return end
    rendering.draw_text({
        text = text,
        surface = surface,
        target = target_spec,
        players = { viewer },
        time_to_live = ttl_ticks,
        scale = scale,
        scale_with_zoom = true,  
        color = color,
        alignment = 'center',
        vertical_alignment = 'bottom',
    })
end
function Public.show(payload)
    local speaker = payload.speaker
    if type(speaker) ~= 'string' or speaker == '' then return end
    local t = type(payload.t) == 'table' and payload.t or nil
    local original = type(payload.original) == 'string' and payload.original or nil
    local scale = Public.get_scale()
    local ttl_ticks = math.floor(Public.get_ttl_seconds() * 60)
    local color = Public.get_color_rgb(Public.get_color_key())
    for _, p in pairs(game.connected_players) do
        if p.valid and p.name ~= speaker then  
            local variant = t and t[p.locale]   
            if type(variant) ~= 'string' or variant == '' then
                variant = original              
            end
            if type(variant) == 'string' and variant ~= '' then
                local surface, target_spec = resolve_anchor(p)  
                if surface then
                    draw_for_viewer(surface, target_spec, p, speaker .. ': ' .. variant, scale, ttl_ticks, color)
                end
            end
        end
    end
end
return Public
