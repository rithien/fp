local AdminPanel = require 'gui.admin_panel'
AdminPanel.register_action({
    id = 'destroy_speakers',
    caption = { 'fp-admin.destroy-speakers-caption' },
    tooltip = { 'fp-admin.destroy-speakers-tooltip' },
    on_click = function(player)
        local speakers = player.surface.find_entities_filtered({
            force = player.force,
            type = 'programmable-speaker'
        })
        local count = 0
        for _, speaker in pairs(speakers) do
            if speaker.valid then
                speaker.destroy()
                count = count + 1
            end
        end
        player.print({ 'fp-admin.destroy-speakers-result', count })
    end
})
