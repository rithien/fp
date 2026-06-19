local AdminPanel = require 'gui.admin_panel'
local Overhead = require 'lib.translation_overhead'
local SLIDER_ID = 'overhead_ttl'
local MIN, MAX = Overhead.get_ttl_bounds()
AdminPanel.register_slider({
    id = SLIDER_ID,
    caption = { 'fp-admin.overhead-ttl-caption' },
    tooltip = { 'fp-admin.overhead-ttl-tooltip' },
    min = MIN,
    max = MAX,
    step = 1,
    format = function(v) return string.format('%.0f s', v) end,
    get_value = function() return Overhead.get_ttl_seconds() end,
    on_change = function(new_value, _player)
        Overhead.set_ttl_seconds(new_value)
    end,
})
