-- ripchord

page = 1
active_preset_index = 1
file_names = {}
notes = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
key_map = {}
low_note = 24
octaves = 6

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

function print_file(filepath)
  print(filepath)
  local f=io.open(filepath,"r")
  if f==nil then
    print("file not found: "..filepath)
  else
    f:close()
    for line in io.lines(filepath) do
      -- this is where you would do something useful!
      -- but for now we'll just print each line
      print(line)
    end
  end
end

function parsePreset(preset)
  print_file(_path.data..'ripchord/presets/'..preset..".rpc")
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

function drawPreset()
  generate_key_map()

  local sorted_keys = tab.sort(key_map)
  local yPos = 45
  local xPos = 0
  screen.level(15)
  for _, note in pairs(sorted_keys) do
    local name = key_map[note]
    -- white notes go first
    -- since black notes are drawn above
    if string.len(name) == 2 then
      screen.rect(xPos, yPos, 3, 5)
      screen.fill()
      xPos = xPos + 3
    end
  end

  xPos = 2
  screen.level(0)
  for _, note in pairs(sorted_keys) do
    local name = key_map[note]
    -- white notes go first
    -- since black notes are drawn above
    if string.len(name) == 3 then
      screen.rect(xPos, yPos, 2, 3)
      screen.fill()
      local letter = string.sub(name, 1, 1)
      if letter == "A" or letter == "D" then
        xPos = xPos + 6
      else
        xPos = xPos + 3
      end
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
    parsePreset(file_names[active_preset_index])
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