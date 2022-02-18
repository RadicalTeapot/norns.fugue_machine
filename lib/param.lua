---@class Param
local Param = {}

---@type Event_subscriber
local event = include('lib/event_subscriber')
---@type Midi_handler
local midi_handler = include('lib/midi_handler')

local events = {
    randomize = event.new(),
    running = event.new(),
    midi_connect = event.new(),
    update_playhead = event.new(),
}

local function handle_midi_connect(index)
    local device = midi_handler.connect(index)
    events.midi_connect:trigger(device)
end

local function handle_playhead_param_update(index)
    local data = {
        index=index,
        use=params:get("usePlayhead"..index) == 1,
        reversed=params:get("reversePlayhead"..index) == 1,
        probability=params:get("probabilityPlayhead"..index) / 100,
        clock_div=params:get("clockDivPlayhead"..index),
        octave_offset=params:get("octOffsetPlayhead"..index),
        channel=params:get("channelPlayhead"..index),
    }
    events.update_playhead:trigger(data)
end

local function add_playhead_params(index)
    local update_playhead_action = function() handle_playhead_param_update(index) end
    params:add_group("Playhead "..index, 6)

    params:add_binary("usePlayhead"..index, "Use", "toggle", 1)
    params:set_action("usePlayhead"..index, update_playhead_action)

    params:add_binary("reversePlayhead"..index, "Reverse", "toggle", 0)
    params:set_action("reversePlayhead"..index, update_playhead_action)

    params:add_number("probabilityPlayhead"..index, "Probability", 1, 100, 80, function(param) return param:get()..' %' end)
    params:set_action("probabilityPlayhead"..index, update_playhead_action)

    params:add_number("clockDivPlayhead"..index, "Clock div", 1, 32, 1)
    params:set_action("clockDivPlayhead"..index, update_playhead_action)

    params:add_number("octOffsetPlayhead"..index, "Octave offset", -3, 3, 0)
    params:set_action("octOffsetPlayhead"..index, update_playhead_action)

    params:add_number("channelPlayhead"..index, "Midi channel", 1, 16, index)
    params:set_action("channelPlayhead"..index, update_playhead_action)
end

function Param.set()
    params:add_trigger("randomize", "Randomize")
    params:set_action("randomize", function() events.randomize:trigger() end)
    params:add_binary("running", "Running", "toggle", 1)
    params:set_action("running", function(state) events.running:trigger(state) end)
    params:add_option("midi_device", "midi out device", midi_handler.get_midi_device_list(), 1)
    params:set_action("midi_device", handle_midi_connect)

    for i=1,4 do
        add_playhead_params(i)
    end
end

function Param.set_playhead_data(data)
    local index = data.index
    params:set("usePlayhead"..index, data.use and 1 or 0, true)
    params:set("reversePlayhead"..index, data.reversed and 1 or 0, true)
    params:set("probabilityPlayhead"..index, math.floor(data.probability * 100), true)
    params:set("clockDivPlayhead"..index, data.clock_div, true)
    params:set("octOffsetPlayhead"..index, data.octave_offset, true)
    params:set("channelPlayhead"..index, data.channel, true)
end

function Param.subscribe(randomize_callbacks, running_callbacks, midi_connect_callbacks, playhead_update_callbacks)
    for _,v in ipairs(randomize_callbacks) do
        events.randomize:subscribe(v)
    end
    for _,v in ipairs(running_callbacks) do
        events.running:subscribe(v)
    end
    for _,v in ipairs(midi_connect_callbacks) do
        events.midi_connect:subscribe(v)
    end
    for _,v in ipairs(playhead_update_callbacks) do
        events.update_playhead:subscribe(v)
    end
end

return Param
