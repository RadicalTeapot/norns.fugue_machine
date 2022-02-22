-- Fugue machine
--
-- TODO
-- Draw something

---@type Param
local param = include("lib/param")

local VELOCITY = 96
local SEQ_LENGTH = 16
local GATE_LENGTH = 0.5
local ROOT_NOTE = 36 -- C2
-- 2 octaves of Phrygian without 3rd
local INTERVALS = {
    0, 1, 5, 7, 8, 10,
    12, 13, 17, 19, 20, 22}

local midi_device = nil
local running = false
local notes = {}

local noteSeq = {
    values = {},
    length = SEQ_LENGTH,
}
local shiftSeq = {
    value = {},
    length = SEQ_LENGTH,
    clock_div = 1,
    pos=1
}
local playheads = {
    {pos=1, use=true, reversed=false, clock_div=1, probability=1, octave_offset=0, channel=1, note_off_metro=metro.init(), active_notes={}},
    {pos=1, use=true, reversed=false, clock_div=1, probability=1, octave_offset=0, channel=2, note_off_metro=metro.init(), active_notes={}},
    {pos=1, use=true, reversed=false, clock_div=1, probability=1, octave_offset=0, channel=3, note_off_metro=metro.init(), active_notes={}},
    {pos=1, use=true, reversed=false, clock_div=1, probability=1, octave_offset=0, channel=4, note_off_metro=metro.init(), active_notes={}},
}

local function set_steps_data(steps)
    noteSeq.length = steps.length
    for i,v in ipairs(steps.values) do
        noteSeq.values[i] = v
    end
end

local function generate_sequence()
    local steps = {length=0, values={}}
    shiftSeq.values = {}
    for i=1,SEQ_LENGTH do
        steps.values[i] = math.random()
        shiftSeq.values[i] = math.random(0, math.floor(#notes / 2) + 1)
    end
    steps.length = math.random(SEQ_LENGTH / 2, SEQ_LENGTH)
    shiftSeq.length = math.random(SEQ_LENGTH / 8, SEQ_LENGTH)
    shiftSeq.clock_div = math.random(4, 16)
    shiftSeq.pos = 1

    set_steps_data(steps)
    param.set_steps_data(steps)
end

local function set_playhead_data(data)
    local index = data.index
    -- Is resetting the pos needed ?
    -- playehead[index].pos = 1
    playheads[index].use = data.use
    playheads[index].reversed = data.reversed
    playheads[index].probability = data.probability
    playheads[index].clock_div = data.clock_div
    playheads[index].octave_offset = data.octave_offset
    playheads[index].channel = data.channel
end

local function generate_playheads()
    for i=1,#playheads do
        local clock_div = math.random(8)
        local data = {
            index=i, use=playheads[i].use, channel=playheads[i].channel,
            reversed=math.random() > 0.5,
            probability=1-math.random() * 0.66 * 1/clock_div,
            clock_div=clock_div,
            octave_offset=math.random(-1, 1),
        }
        set_playhead_data(data)
        param.set_playhead_data(data)
    end
end

local function playhead_all_notes_off(index)
    for _, note in pairs(playheads[index].active_notes) do
        midi_device:note_off(note, nil, playheads[index].channel)
    end
    playheads[index].active_notes = {}
end

local function all_notes_off()
    for i=1,#playheads do
        playhead_all_notes_off(i)
    end
end

local function step_head(playhead_index, shiftAmount)
    local head = playheads[playhead_index]
    if head.use then
        local new_pos = head.pos + 1/head.clock_div
        local is_new_note = math.floor(head.pos) ~= math.floor(new_pos)
        head.pos = new_pos
        local index = util.wrap(math.floor(head.pos), 1, noteSeq.length)

        if is_new_note and math.random() <= head.probability then
            if head.reversed then index = #noteSeq.values - (index - 1) end
            local note_index = util.clamp(math.floor(noteSeq.values[index] * #notes + 1), 1, #notes)
            note_index = util.wrap(note_index + shiftAmount, 1, #notes)
            local note_num = notes[note_index] + head.octave_offset * 12
            midi_device:note_on(note_num, VELOCITY, head.channel)
            table.insert(head.active_notes, note_num)
            head.note_off_metro:start((60 / params:get("clock_tempo") / 4) * head.clock_div * GATE_LENGTH, 1)
        end
    end
end

local function step()
    while true do
        clock.sync(1/4)
        if midi_device ~= nil and running then
            shiftSeq.pos = util.wrap(shiftSeq.pos + 1/shiftSeq.clock_div, 1, shiftSeq.length)
            local shiftAmnount = shiftSeq.values[math.floor(shiftSeq.pos)]

            for i=1,#playheads do
                step_head(i, shiftAmnount)
            end
        end
    end
end

local function subscribe_param_events()
    local randomize_callbacks = {
        function() if midi_device ~= nil then all_notes_off() end end,
        function(sequence, playheads) if sequence then generate_sequence() end end,
        function(sequence, playheads) if playheads then generate_playheads() end end,
    }
    local running_callbacks = {
        function(state)
            running = state == 1
            if not running then all_notes_off() end
        end
    }
    local midi_connect_callbacks = {
        function(device)
            if midi_device ~= nil then all_notes_off() end
            midi_device = device
        end
    }
    local playhead_update_callbacks = {
        set_playhead_data
    }
    local steps_update_callbacks = {
        set_steps_data
    }
    param.subscribe(randomize_callbacks, running_callbacks, midi_connect_callbacks, playhead_update_callbacks, steps_update_callbacks)
end

function init()
    param.set(SEQ_LENGTH)
    subscribe_param_events()

    notes = {}
    for i, v in ipairs(INTERVALS) do notes[i] = v + ROOT_NOTE end

    for i=1,#playheads do
        playheads[i].note_off_metro.event = function() playhead_all_notes_off(i) end
    end
    generate_sequence()
    generate_playheads()
    params:default()

    clock.run(step)
end

function enc(index, delta)
end

function key(index, state)
end

function redraw()
end

function r()
    norns.script.load(norns.state.script)
end
