local AdminPanel = require 'gui.admin_panel'
AdminPanel.register_action({
    id = 'place_landing_pad',
    caption = { 'fp-admin.place-landing-pad-caption' },
    tooltip = { 'fp-admin.place-landing-pad-tooltip' },
    on_click = function(player)
        if not prototypes.entity['cargo-landing-pad'] then
            player.print({ 'fp-admin.place-landing-pad-missing' })
            return
        end
        local position = (player.selected and player.selected.valid and player.selected.position)
            or { player.position.x + 5, player.position.y }
        local pad = player.surface.create_entity({
            name = 'cargo-landing-pad',
            position = position,
            force = player.force,
            raise_built = true,
        })
        if pad and pad.valid then
            player.print({ 'fp-admin.place-landing-pad-result',
                math.floor(pad.position.x), math.floor(pad.position.y) })
        else
            player.print({ 'fp-admin.place-landing-pad-failed' })
        end
    end
})
