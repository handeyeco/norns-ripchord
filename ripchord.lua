-- ripchord

fileselect = require('fileselect')

page = 0
notes = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
key_map = {}
low_note = 36
octaves = 4

note_map_to_display = nil

selected_preset_name = nil
-- 2D array: note to notes mapping
note_to_notes = {}
-- names of note to notes mappings
mapping_names = {}

-- which notes are pressed
pressed_notes = {}
-- which notes are playing
active_notes = {}

transpose_output = 0

-- stuff for the MIDI menu
-- that's not working
active_midi_index = 1
in_midi_index = 1
in_midi = midi.connect(in_midi_index)
in_midi_channel = 1
out_midi_index = 1
out_midi = midi.connect(out_midi_index)
out_midi_channel = 1

keyboard_offset = -57

-- nil -> input -> output
map_key_step = nil
map_key_input = nil
map_key_output = {}
dirty = false

function init()
  generate_key_map()
  setupMidiCallback()
end

function setupMidiCallback()
  midi.cleanup()
  in_midi.event = function(data)
    local message = midi.to_msg(data)
  
    if (message.ch == in_midi_channel) then
      if message.type == "note_on" then
        if map_key_step == nil then
          pressed_notes[message.note] = message.note
          diff_output()
          updateMapNameState(message.note, true)
        elseif map_key_step == "input" then
          map_key_input = message.note
          redraw()
        elseif map_key_step == "output" then
          if map_key_output[message.note] then
            map_key_output[message.note] = nil
          else
            map_key_output[message.note] = message.note
          end
          redraw()
        end
      elseif message.type == "note_off" then
        pressed_notes[message.note] = nil
        diff_output()
        updateMapNameState(message.note, false)
      end
    end
  
    redraw()
  end
end

function stop_all_notes()
  for note=21,108 do
    for ch=1,16 do
      out_midi:note_off(note, 100, ch)
    end
  end
  pressed_notes = {}
  active_notes = {}
  note_map_to_display = nil
end

function drawMidiOptions()
  drawLine(0, "in:", in_midi_index.." "..midi.devices[in_midi_index].name, active_midi_index==1)
  drawLine(10, "in ch:", in_midi_channel, active_midi_index==2)
  drawLine(20, "out:", out_midi_index .." "..midi.devices[out_midi_index].name, active_midi_index==3)
  drawLine(30, "out ch:", out_midi_channel, active_midi_index==4)
end

function updateMapNameState(note, on)
  if on == false and note == note_map_to_display then
    note_map_to_display = nil
  elseif on == true and mapping_names[note] then
    note_map_to_display = note
  end
end

function diff_output()
  local next_notes = {}

  -- determine which notes need to be playing
  for _, pressed_note in pairs(pressed_notes) do
    if note_to_notes[pressed_note] then
      for _, mapped_note in pairs(note_to_notes[pressed_note]) do
        local transposed = mapped_note + transpose_output
        next_notes[transposed] = transposed
      end
    else
      local transposed = pressed_note + transpose_output
      next_notes[transposed] = transposed
    end
  end

  -- send new notes
  for _, next_note in pairs(next_notes) do
    if not active_notes[next_note] then
      out_midi:note_on(next_note, 100, out_midi_channel)
    end
  end

  -- stop old notes
  for _, active_note in pairs(active_notes) do
    if not next_notes[active_note] then
      out_midi:note_off(active_note, 100, out_midi_channel)
    end
  end

  active_notes = next_notes
end

function generate_key_map()
  local octave = -2
  for i=0,127 do
    if (i % 12 == 0) then
      octave = octave + 1
    end
    local name = notes[(i % 12)+1]
    key_map[i] = name..octave
  end
end

function load_preset(path)
  if not path or path == "cancel" then return end

  local f=io.open(path,"r")
  note_to_notes = {}
  local inNote = nil
  local outNotes = {}
  if f==nil then
    print("file not found: "..path)
  else
    f:close()
    local i, j, match
    for line in io.lines(path) do
      -- look for incoming note
      i, j = string.find(line, 'note="%d+"')
      if i and j then
        match = string.sub(line,i+6,j-1)
        inNote = match
      end

      -- look for mapped notes
      i, j = string.find(line, 'notes="[0-9;]+"')
      if i and j then
        outNotes = {}
        match = string.sub(line,i+7,j-1)
        for token in string.gmatch(match, "[0-9]+") do
          table.insert(outNotes, tonumber(token))
        end
        note_to_notes[tonumber(inNote)] = outNotes
      end

      -- stash mapping name
      i, j = string.find(line, 'name="[^"]+"')
      if i and j then
        match = string.sub(line,i+6,j-1)
        mapping_names[tonumber(inNote)] = match
      end

    end
  end

  local split_at = string.match(path, "^.*()/")
  selected_preset_name = string.sub(path, split_at + 1, #path - 4)
  redraw()
end

function drawLine(yPos, leftText, rightText, active)
  local textPos = yPos + 7
  if active then
    screen.level(15)
    screen.rect(0,yPos,256,9)
    screen.fill()
    screen.level(0)
  else
    screen.level(2)
  end

  screen.move(1, textPos)
  screen.text(leftText)
  screen.move(128-1, textPos)
  screen.text_right(rightText)
end

function drawKey(xPos, yPos, highlighted, filled)
  -- don't draw outside of set bounds
  if xPos < 8 or xPos > 118 then
    return
  end

  if highlighted then
    screen.level(15)
  else
    screen.level(2)
  end

  if filled then
    screen.rect(xPos - 1, yPos - 1, 3, 3)
    screen.fill()
  else
    screen.rect(xPos, yPos, 2, 2)
    screen.stroke()
  end
end

function drawKeyboard(yPos, notesToHighlight, notesToFill)
  local sorted_keys = tab.sort(key_map)

  local xPos = 10 + keyboard_offset

  for _, note in pairs(sorted_keys) do
    local name = key_map[note]
    local highlight = notesToHighlight[note]
    local fill = notesToFill[note]

    if string.len(name) == 2 then
      drawKey(xPos, yPos, highlight, fill)

      -- mark middle c
      if note == 60 then
        screen.level(0)
        screen.pixel(xPos - 1, yPos + 1)
        screen.pixel(xPos + 1, yPos + 1)
        screen.pixel(xPos - 1, yPos - 1)
        screen.pixel(xPos + 1, yPos - 1)
        screen.fill()
      end

      xPos = xPos + 4
    else
      xPos = xPos - 2
      drawKey(xPos, yPos - 4, highlight, fill)
      xPos = xPos + 2
    end
  end
end

function drawRipchord()
  screen.level(2)

  local preset_text = "preset: "
  if dirty then
    preset_text = preset_text.."! "
  end

  if selected_preset_name then
    preset_text = preset_text..selected_preset_name
  else
    preset_text = preset_text.."none"
  end
  screen.move(1, 10)
  screen.text(preset_text)

  screen.move(1, 20)
  screen.text("output transpose: "..transpose_output)

  drawKeyboard(44, pressed_notes, note_to_notes)
  drawKeyboard(54, active_notes, {})

  if note_map_to_display then
    local mapping_to_display = key_map[note_map_to_display]
    if mapping_names[note_map_to_display] then
      mapping_to_display = mapping_to_display..": "..mapping_names[note_map_to_display]
    end
    screen.move(1, 64)
    screen.level(2)
    screen.text(mapping_to_display)
  end
end

function drawMapper()
  local input_text = "input note"
  if map_key_input then
    input_text = input_text..": "..key_map[map_key_input]
  end

  if map_key_step == "input" then
    screen.move(64, 20)
    screen.text_center(input_text)

    local highlight = {}
    if map_key_input then
      highlight[map_key_input] = map_key_input
    end
    drawKeyboard(40, highlight, note_to_notes)

    screen.move(2, 62)
    screen.text("cancel: k2")

    if map_key_input ~= nil then
      screen.move(126, 62)
      screen.text_right("next: k3")
    end
  elseif map_key_step == "output" then
    screen.move(64, 15)
    screen.text_center(input_text)

    local output_count = 0
    for _ in pairs(map_key_output) do
      output_count = output_count + 1
    end
    local text = "output notes: "..output_count
    screen.move(64, 27)
    screen.text_center(text)
    drawKeyboard(40, map_key_output, {})

    screen.move(2, 62)
    screen.text("back: k2")

    if output_count > 0 then
      screen.move(126, 62)
      screen.text_right("finish: k3")
    end
  end
end

function redraw()
  screen.clear()
  screen.fill()
  if map_key_step ~= nil then
    drawMapper()
  elseif page == 0 then
    drawRipchord()
  elseif page == 1 then
    drawMidiOptions()
  end
  screen.update()
end

function handleRipchordEnc(n,d)
  if (n == 2) then
    local prev_transpose_output = transpose_output
    transpose_output = util.clamp(transpose_output + d, -24, 24)
    if prev_transpose_output ~= transpose_output then
      diff_output()
    end
  elseif (n == 3) then
    keyboard_offset = util.clamp(keyboard_offset + d, -200, 50)
    redraw()
  end
end

function handleMappingKey(n, z)
  if n == 2 then
    if map_key_step == "input" then
      -- cancel
      map_key_step = nil
      map_key_input = nil
      map_key_output = {}
    elseif map_key_step == "output" then
      -- back
      map_key_step = "input"
    end
  elseif n == 3 then
    if map_key_step == "input" then
      -- next
      map_key_step = "output"
      -- if a mapping exists for that key
      -- load it
      if note_to_notes[map_key_input] then
        for _, v in pairs(note_to_notes[map_key_input]) do
          map_key_output[v] = v
        end
      end
    elseif map_key_step == "output" then
      -- finish
      dirty = true
      note_to_notes[map_key_input] = map_key_output
      map_key_step = nil
      map_key_input = nil
      map_key_output = {}
    end
  end

  redraw()
end

function handleRipchordKey(n,z)
  if map_key_step ~= nil then
    handleMappingKey(n, z)
  elseif n == 2 then
    fileselect.enter(_path.data..'ripchord/presets', load_preset)
  elseif n == 3 then
    map_key_step = "input"
    redraw()
  end
end

function handleMidiEncoder(n,d)
  if n == 2 then
    active_midi_index = util.clamp(active_midi_index + d, 1, 4)
  elseif n == 3 then
    if (active_midi_index == 1) then
      in_midi_index = util.clamp(in_midi_index + d, 1, #midi.devices)
      in_midi = midi.connect(in_midi_index)
      setupMidiCallback()
    elseif (active_midi_index == 2) then
      in_midi_channel = util.clamp(in_midi_channel + d, 1, 16)
    elseif (active_midi_index == 3) then
      stop_all_notes()
      out_midi_index = util.clamp(out_midi_index + d, 1, #midi.devices)
      out_midi = midi.connect(out_midi_index)
    elseif (active_midi_index == 4) then
      stop_all_notes()
      out_midi_channel = util.clamp(out_midi_channel + d, 1, 16)
    end
  end
end

function enc(n,d)
  if (n == 1) then
    page = util.clamp(page + d, 0, 1)
  elseif (page == 0) then
    handleRipchordEnc(n,d)
  elseif (page == 1) then
    handleMidiEncoder(n,d)
  end
  redraw()
end

function key(n,z)
  if (z == 1) then
    if (page == 0) then
      handleRipchordKey(n,z)
      -- can't redraw here due to fileselect
    end
  end
end