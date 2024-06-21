-- ripchord

page = 0
active_preset_index = 1
file_names = {}
notes = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
key_map = {}
low_note = 36
octaves = 4

note_map_to_display = nil

-- 2D array: note to notes mapping
note_to_notes = {}
mapping_names = {}

-- which notes are pressed
pressed_notes = {}
-- which notes are playing
active_notes = {}

in_midi = midi.connect()
in_midi_ch = 1
out_midi = midi.connect()
out_midi_ch = 1

in_midi.event = function(data)
  local message = midi.to_msg(data)

  if message.type == "note_on" then
    pressed_notes[message.note] = message.note
    diff_output()
    updateMapNameState(message.note, true)
  elseif message.type == "note_off" then
    pressed_notes[message.note] = nil
    diff_output()
    updateMapNameState(message.note, false)
  end

  redraw()
end

function updateMapNameState(note, on)
  if on == false and note == note_map_to_display then
    note_map_to_display = nil
  elseif on ==true then
    note_map_to_display = note
  end
end

function diff_output()
  local next_notes = {}

  -- determine which notes need to be playing
  for _, pressed_note in pairs(pressed_notes) do
    if note_to_notes[pressed_note] then
      for _, mapped_note in pairs(note_to_notes[pressed_note]) do
        next_notes[mapped_note] = mapped_note
      end
    else
      next_notes[pressed_note] = pressed_note
    end
  end

  -- send new notes
  for _, next_note in pairs(next_notes) do
    if not active_notes[next_note] then
      out_midi:note_on(next_note)
    end
  end

  -- stop old notes
  for _, active_note in pairs(active_notes) do
    if not next_notes[active_note] then
      out_midi:note_off(active_note)
    end
  end

  active_notes = next_notes
end

function generate_key_map()
  for i=1,octaves do
    local baseNoteNumber = ((i - 1) * 12) + low_note
    local baseOctaveNumber = 3 + (i - 1)
    for j, v in pairs(notes) do
      local noteNumber = baseNoteNumber + (j - 1)
      local note = v..baseOctaveNumber
      key_map[noteNumber] = note
    end
  end
end

function load_preset(preset)
  local path = _path.data..'ripchord/presets/'..preset..".rpc"
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
        print(match)
        inNote = match
      end

      -- look for mapped notes
      i, j = string.find(line, 'notes="[0-9;]+"')
      if i and j then
        outNotes = {}
        match = string.sub(line,i+7,j-1)
        print(match)
        for token in string.gmatch(match, "[0-9]+") do
          table.insert(outNotes, tonumber(token))
        end
        note_to_notes[tonumber(inNote)] = outNotes
      end

      -- stash mapping name
      i, j = string.find(line, 'name="[^"]+"')
      if i and j then
        match = string.sub(line,i+6,j-1)
        print(match)
        mapping_names[tonumber(inNote)] = match
      end

    end
  end

  for k, v in pairs(note_to_notes) do
    print(k)
    tab.print(v)
  end

  page = 1
  redraw()
end

function init()
  get_presets()
end

function drawLine(yPos, leftText, active)
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
end

function drawPresets()
  for i=1, #file_names do
    local file = file_names[i]
    local yPos = 0
    if active_preset_index < 4 then
      yPos = (i - 1) * 10
    else
      yPos = ((i - active_preset_index + 3) * 10)
    end
    drawLine(
      yPos,
      file,
      active_preset_index == i
    )
  end
end

function drawKey(xPos, yPos, highlighted, filled)
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

  local xPos = 10

  for _, note in pairs(sorted_keys) do
    local name = key_map[note]
    local highlight = notesToHighlight[note]
    local fill = notesToFill[note]

    if string.len(name) == 2 then
      drawKey(xPos, yPos, highlight, fill)
      xPos = xPos + 4
    else
      xPos = xPos - 2
      drawKey(xPos, yPos - 4, highlight, fill)
      xPos = xPos + 2
    end
  end
end

function drawPreset()
  generate_key_map()

  local mapping_to_display = ""
  if note_map_to_display then
    mapping_to_display = key_map[note_map_to_display]
    if mapping_names[note_map_to_display] then
      mapping_to_display = mapping_to_display..": "..mapping_names[note_map_to_display]
    end
    screen.level(2)
    screen.move(1, 64)
    screen.text(mapping_to_display)
  end

  drawKeyboard(44, pressed_notes, note_to_notes)
  drawKeyboard(54, active_notes, {})
end

function redraw()
  screen.clear()
  screen.fill()
  if page == 0 then
    drawPresets()
  elseif page == 1 then
    drawPreset()
  end
  screen.update()
end

function get_presets()
  local cb = function(text)
      -- Get a list of filenames
      for line in string.gmatch(text, "/[%w%s_]+.rpc") do
          name = string.sub(line, 2, -5)
          table.insert(file_names, name)
      end
      table.sort(file_names)

      redraw()
  end

  norns.system_cmd('find '.._path.data..'ripchord/presets -name *.rpc', cb)
end

function handlePresetEnc(n,d)
  if (n == 2) then
    active_preset_index = util.clamp(active_preset_index + d, 1, #file_names)
  end
end

function handlePresetKey(n,z)
  if (n == 3) then
    load_preset(file_names[active_preset_index])
  end
end

function enc(n,d)
  if (n == 1) then
    page = util.clamp(page + d, 0, 1)
  elseif (page == 0) then
    handlePresetEnc(n,d)
  end
  redraw()
end


function key(n,z)
  if (z == 1) then
    if (page == 0) then
      handlePresetKey(n,z)
    end
  end
  redraw()
end