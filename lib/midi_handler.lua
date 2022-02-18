---@class Midi_handler
local Midi_handler = {}
Midi_handler.__index = Midi_handler

function Midi_handler.get_midi_device_list()
    devices = {}
    for i = 1,#midi.vports do
        local long_name = midi.vports[i].name
        local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
        table.insert(devices,i..": "..short_name)
    end
    return devices
end

function Midi_handler.connect(device_index)
    local device = midi.connect(device_index)
    return device
end

return Midi_handler
