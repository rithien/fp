local AdminPanel = require 'gui.admin_panel'
local Overhead = require 'lib.translation_overhead'
AdminPanel.register_dropdown({
    id = 'overhead_color',
    caption = { 'fp-admin.overhead-color-caption' },
    tooltip = { 'fp-admin.overhead-color-tooltip' },
    choices = Overhead.get_color_choices(),
    get_value = function() return Overhead.get_color_key() end,
    on_change = function(key, _player) Overhead.set_color_key(key) end,
    preview_color = function(key) return Overhead.get_color_rgb(key) end,
})
