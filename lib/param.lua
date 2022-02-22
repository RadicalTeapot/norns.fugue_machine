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
    update_steps = event.new(),
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

local function handle_steps_update(count)
    local steps = {length=0, values={}}
    steps.length = params:get("steps_length")
    for i=1,count do
        steps.values[i] = params:get("step"..i)
    end
    events.update_steps:trigger(steps)
end

local function add_steps_params(count)
    params:add_group("Steps", count)
    local step_update_action = function() handle_steps_update(count) end
    local cs = controlspec.new(0,1,'lin',0.01,0)
    for i=1,count do
        params:add_control("step"..i, "Step "..i, cs:copy())
        params:set_action("step"..i, step_update_action)
    end
end

function Param.set(count)
    params:add_separator("Fugue Machine")
    params:add_trigger("randomize_all", "Randomize all")
    params:set_action("randomize_all", function() events.randomize:trigger(true, true) end)
    params:add_trigger("randomize_seq", "Random sequence")
    params:set_action("randomize_seq", function() events.randomize:trigger(true, false) end)
    params:add_trigger("randomize_playheads", "Random play heads")
    params:set_action("randomize_playheads", function() events.randomize:trigger(false, true) end)
    params:add_binary("running", "Running", "toggle", 1)
    params:set_action("running", function(state) events.running:trigger(state) end)
    params:add_option("midi_device", "midi out device", midi_handler.get_midi_device_list(), 1)
    params:set_action("midi_device", handle_midi_connect)

    params:add_separator("Playheads")
    for i=1,4 do
        add_playhead_params(i)
    end
    params:add_separator("Steps")
    params:add_number("steps_length", "Seq Length", 1, count, count / 2)
    params:set_action("steps_length", function() handle_steps_update(count) end)
    add_steps_params(count)
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

function Param.set_steps_data(steps)
    params:set("steps_length", steps.length, true)
    for i,v in ipairs(steps.values) do
        params:set("step"..i, v, true)
    end
end

function Param.subscribe(randomize_callbacks, running_callbacks, midi_connect_callbacks, playhead_update_callbacks, steps_update_callbacks)
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
    for _, v in ipairs(steps_update_callbacks) do
        events.update_steps:subscribe(v)
    end
end

return Param
