local Session = require 'lib.sessions'
local Commands = {}
local function reply(cmd, msg)
    if cmd.player_index then
        local p = game.get_player(cmd.player_index)
        if p and p.valid then p.print(msg) end
    else
        log(msg)
    end
end
local Builder = {}
Builder.__index = Builder
function Builder:require_admin()
    self.admin_only = true
    return self
end
function Builder:require_trusted()
    self.trusted_only = true
    return self
end
function Builder:server_only()
    self.server_only_flag = true
    return self
end
function Builder:add_parameter(name, optional, ptype)
    if not self.parameters then self.parameters = {} end
    self.parameters[#self.parameters + 1] = {
        name = name,
        optional = optional and true or false,
        type = ptype or 'string'
    }
    return self
end
function Builder:callback(fn)
    self.callback_fn = fn
    local self_ref = self
    commands.add_command(self.name, self.help or '', function(cmd)
        if self_ref.server_only_flag and cmd.player_index then return end
        if cmd.player_index then
            local player = game.get_player(cmd.player_index)
            if not player or not player.valid then return end
            if self_ref.admin_only and not player.admin then
                player.print({ 'fp-commands.err-admin-only', self_ref.name })
                return
            end
            if self_ref.trusted_only and not Session.get_trusted_player(player) and not player.admin then
                player.print({ 'fp-commands.err-trusted-only', self_ref.name })
                return
            end
        end
        local args = {}
        if self_ref.parameters and #self_ref.parameters > 0 then
            local tokens = {}
            if cmd.parameter then
                for token in string.gmatch(cmd.parameter, '%S+') do
                    tokens[#tokens + 1] = token
                end
            end
            for i, pspec in ipairs(self_ref.parameters) do
                local val = tokens[i]
                if val == nil then
                    if not pspec.optional then
                        reply(cmd, { 'fp-commands.err-missing-param', self_ref.name, pspec.name })
                        return
                    end
                    args[i] = nil
                elseif pspec.type == 'player' then
                    local p = game.get_player(val)
                    if not p then
                        reply(cmd, { 'fp-commands.err-player-not-found', self_ref.name, val })
                        return
                    end
                    args[i] = p
                elseif pspec.type == 'number' then
                    local n = tonumber(val)
                    if not n then
                        reply(cmd, { 'fp-commands.err-not-number', self_ref.name, pspec.name, val })
                        return
                    end
                    args[i] = n
                else
                    args[i] = val
                end
            end
        end
        self_ref.callback_fn(cmd, table.unpack(args, 1, self_ref.parameters and #self_ref.parameters or 0))
    end)
    return self
end
function Commands.new(name, help)
    return setmetatable({
        name = name,
        help = help,
        admin_only = false,
        trusted_only = false,
        server_only_flag = false,
        parameters = nil,
        callback_fn = nil
    }, Builder)
end
return Commands
