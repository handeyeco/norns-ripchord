-- ripchord

page = 0
active_preset_index = 1
file_names = {}

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

function parsePreset()
  presets = util.scandir(_path.code..'ripchord/presets')
  print_file(_path.code..'ripchord/presets/'..presets[1])
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

function redraw()
  screen.clear()
  screen.fill()
  if page == 0 then
    drawPresets()
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

  print("running")
  norns.system_cmd('find '.._path.code..'ripchord/presets -name *.rpc', cb)
end

function handlePresetEnc(n,d)
  if (n == 2) then
    active_preset_index = util.clamp(active_preset_index + d, 1, #file_names)
  end
end

function handlePresetKey(n,z)
  if (n == 3) then
    parsePreset()
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