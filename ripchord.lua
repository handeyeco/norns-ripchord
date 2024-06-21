-- ripchord

page = 0
active_preset_index = 1
file_names = {}
notes = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
key_map = {}
low_note = 36
octaves = 4

note_to_notes = {}
pressed_notes = {}

in_midi = midi.connect()
in_midi.event = function(data)
  local message = midi.to_msg(data)

  if message.type == "note_on" then
    pressed_notes[message.note] = message.note
  elseif message.type == "note_off" then
    pressed_notes[message.note] = nil
  end

  redraw()
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
        match = string.sub(line,i,j)
        i, j = string.find(match, '%d+')
        inNote = string.sub(match,i,j)
      end

      -- look for mapped notes
      i, j = string.find(line, 'notes="[0-9;]+"')
      if i and j then
        outNotes = {}
        match = string.sub(line,i,j)
        i, j = string.find(match, '[0-9;]+')
        match = string.sub(match,i,j)
        for token in string.gmatch(match, "[0-9]+") do
          table.insert(outNotes, tonumber(token))
        end
        note_to_notes[tonumber(inNote)] = outNotes
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

function drawPreset()
  generate_key_map()

  local sorted_keys = tab.sort(key_map)
  local yPos = 45
  local xPos = 1

  for _, note in pairs(sorted_keys) do
    local name = key_map[note]
    local highlight = pressed_notes[note]
    local fill = note_to_notes[note]

    if string.len(name) == 2 then
      yPos = 45
      drawKey(xPos, yPos, highlight, fill)
      xPos = xPos + 4
    else
      yPos = 41
      xPos = xPos - 2
      drawKey(xPos, yPos, highlight, fill)
      xPos = xPos + 2
    end
  end
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