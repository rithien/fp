local AdminPanel = require 'gui.admin_panel'
local Overhead = require 'lib.translation_overhead'
local SLIDER_ID = 'overhead_scale'
local MIN, MAX = Overhead.get_scale_bounds()
AdminPanel.register_slider({
    id = SLIDER_ID,
    caption = { 'fp-admin.overhead-scale-caption' },
    tooltip = { 'fp-admin.overhead-scale-tooltip' },
    min = MIN,
    max = MAX,
    step = 0.2,
    format = function(v) return string.format('%.1f\195\151', v) end,  
    get_value = function() return Overhead.get_scale() end,
    on_change = function(new_value, _player)
        Overhead.set_scale(new_value)
    end,
})
