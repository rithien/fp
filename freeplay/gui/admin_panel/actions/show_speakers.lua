local AdminPanel = require 'gui.admin_panel'
AdminPanel.register_action({
    id = 'show_speakers',
    caption = { 'fp-admin.show-speakers-caption' },
    tooltip = { 'fp-admin.show-speakers-tooltip' },
    sprite = 'file/img/gui/admin/show_speakers.png',
    sprite_fallback = 'item/programmable-speaker',
    caption_short = { 'fp-admin.show-speakers-short' },
    on_click = function(player)
        local speakers = player.surface.find_entities_filtered({
            force = player.force,
            type = 'programmable-speaker'
        })
        if #speakers == 0 then
            player.print({ 'fp-admin.show-speakers-none' })
            return
        end
        player.print({ 'fp-admin.show-speakers-header', #speakers })
        for _, speaker in pairs(speakers) do
            local placer = (speaker.last_user and speaker.last_user.name) or '<unknown>'
            player.print({ 'fp-admin.show-speakers-line', placer, speaker.gps_tag or '?' })
        end
    end
})
