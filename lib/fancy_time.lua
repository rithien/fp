local Public = {}
function Public.seconds_to_fancy(seconds, short)
    short = short or false
    local time_left = seconds
    if time_left < 1 then
        return {'0 seconds'}
    end
    local names = {
        {'second', 's'},
        {'minute', 'min'},
        {'hour', 'h'},
        {'day', 'd'},
        {'week', 'w'},
        {'month', 'm'},
        {'year', 'y'}
    }
    local modulos = {
        1,
        60,
        3600,
        3600 * 24,
        3600 * 24 * 7,
        3600 * 24 * 30,
        3600 * 24 * 365.25
    }
    local values = {}
    local pretty = {}
    for i = #modulos, 1, -1 do
        local fit_time = math.floor(time_left / modulos[i])
        table.insert(values, fit_time)
        time_left = time_left - fit_time * modulos[i]
    end
    local internal_name_index = 1
    if not short then
        internal_name_index = 1
    else
        internal_name_index = 2
    end
    for i = #names, 1, -1 do
        if values[#values - i + 1] > 0 then
            local _name = names[i][internal_name_index]
            if values[#values - i + 1] > 1 and not short then
                _name = _name .. 's'
            end
            table.insert(pretty, values[#values - i + 1] .. ' ' .. _name)
        end
    end
    return pretty
end
function Public.fancy_time_formatting(fancy_array)
    if #fancy_array == 0 then
        return
    end
    local fancy_string = ''
    if #fancy_array > 1 then
        for i = 1, #fancy_array, 1 do
            if i == 1 then
                fancy_string = fancy_array[1]
            else
                fancy_string = fancy_string .. ', ' .. fancy_array[i]
            end
        end
        return fancy_string
    else
        return fancy_array[1]
    end
end
function Public.filter_time(fancy_array, filter_words, mode)
    local filtered_array = {}
    for i = 1, #fancy_array, 1 do
        local _subject = fancy_array[i]
        for fi = 1, #filter_words, 1 do
            local result = string.find(_subject, filter_words[fi]) 
            local suc = type(result) ~= type(nil) 
            if suc == true and mode == true then
                table.insert(filtered_array, _subject)
                break
            elseif suc == true and mode == false then
                break
            elseif suc == false and mode == false and fi == #filter_words then
                table.insert(filtered_array, _subject)
            end
        end
    end
    if #filtered_array == 0 then
        filtered_array = fancy_array
    end
    return filtered_array
end
function Public.fancy_time(seconds)
    local fancy = Public.seconds_to_fancy(seconds, false)
    local formatted = Public.fancy_time_formatting(fancy)
    return formatted
end
function Public.short_fancy_time(seconds)
    local fancy = Public.seconds_to_fancy(seconds, true)
    fancy = Public.filter_time(fancy, {'seconds', 's'}, false)
    local formatted = Public.fancy_time_formatting(fancy)
    return formatted
end
return Public
