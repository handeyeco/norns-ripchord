-- norns ripchord
--
-- by handeyeco
--
-- e1: change screens
-- e2: transpose outgoing
--     notes
-- e3: move onscreen
--     keyboard
-- k2: load preset
-- k3: create new key mapping
--
-- for more info:
--
-- https://github.com
--        /handeyeco
--        /norns-ripchord
UI = require("ui")
fileselect = require('fileselect')
textentry = require('textentry')

-- paths for presets
preset_dir = _path.data.."ripchord/presets"
user_preset_dir = preset_dir.."/user"

-- which UI page to show
-- 0 == ripchord page, 1 == settings page
page = 0

-- midi note number to note name/octave
key_map = {}


-- which preset is currently loaded
selected_preset_name = nil
-- 2D array: note to notes mapping
note_to_notes = {}
-- names of note to notes mappings
mapping_names = {}
-- last active note mapping name
note_map_to_display = nil

-- which notes are being received
pressed_notes = {}
-- which notes are being sent
active_notes = {}

-- output note transpose amount
transpose_output = 0

-- stuff for the settings menu
-- which item in the setting menu is selected
active_settings_index = 1

-- list of virtual MIDI ports
midi_devices = {}
-- MIDI in connection
in_midi = nil
-- MIDI out connection
out_midi = nil

-- used to move the keyboard left/right (x-position offset)
keyboard_offset = -57

-- state for making a new key mapping
-- which step in the process: nil -> "input" -> "output"
map_key_step = nil
-- the trigger key
map_key_input = nil
-- the output keys
map_key_output = {}

-- if a preset has been created/edited but not saved
dirty = false

-- NORNS LIFECYCLE CALLBACKS
-- NORNS LIFECYCLE CALLBACKS
-- NORNS LIFECYCLE CALLBACKS

-- called when script loads
function init()
  os.execute("mkdir -p "..user_preset_dir)
  generate_key_map()
  build_midi_device_list()

  params:add_option("midi_in_device", "midi in device", midi_devices, 1)
  params:set_action("midi_in_device", function() setup_midi_callback() end)

  params:add_number("midi_in_channel", "midi in channel", 1, 16, 1)
  params:set_action("midi_in_channel", function() setup_midi_callback() end)

  params:add_option("midi_out_device", "midi out device", midi_devices, 1)
  params:set_action("midi_out_device", function()  setup_midi_callback() end)

  params:add_number("midi_out_channel", "midi out channel", 1, 16, 1)
  params:set_action("midi_out_channel", function() setup_midi_callback() end)

  setup_midi_callback()
end

-- encoder callback
function enc(n,d)
  if n == 1 and map_key_step == nil then
    -- change pages
    page = util.clamp(page + d, 0, 1)
  elseif (page == 0) then
    handle_ripchord_enc(n,d)
  elseif (page == 1) then
    handle_settings_enc(n,d)
  end
  redraw()
end

-- key callback
function key(n,z)
  if (z == 1) then
    if page == 0 then
      handle_ripchord_key(n,z)
      -- can't redraw here due to fileselect
    elseif page == 1 then
      handle_settings_key(n,z)
      -- can't redraw here due to textentry
    end
  end
end

-- update screen
function redraw()
  screen.clear()
  screen.fill()
  if map_key_step ~= nil then
    draw_mapper_ui()
  elseif page == 0 then
    draw_ripchord_page()
  elseif page == 1 then
    draw_settings_page()
  end
  screen.update()
end

-- called when script unloads
function cleanup()
  stop_all_notes()
end

-- HELPERS
-- HELPERS
-- HELPERS

-- generate the key_map lookup table
function generate_key_map()
  local note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  -- start at -2, but it immediately gets bumped to -1
  local octave = -2
  for i = 0, 127 do
    if (i % 12 == 0) then
      octave = octave + 1
    end
    local name = note_names[(i % 12) + 1]
    key_map[i] = name..octave
  end
end

-- decide which note map name to display
-- (the bottom of the screen when a mapped key is pressed)
function update_map_name_state(note, on)
  if on == false and note == note_map_to_display then
    note_map_to_display = nil
  elseif on == true then
    note_map_to_display = note
  end
end

-- compare the current state of notes being played to a new state
-- if there are new notes, send those
-- if there are active notes that are now inactive, turn those off
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
      out_midi:note_on(next_note, 100, params:get("midi_out_channel"))
    end
  end

  -- stop old notes
  for _, active_note in pairs(active_notes) do
    if not next_notes[active_note] then
      out_midi:note_off(active_note, 100, params:get("midi_out_channel"))
    end
  end

  active_notes = next_notes
end

-- stop all notes on the MIDI output
-- so we don't have hanging notes when changing output
function stop_all_notes()
  if out_midi then
    for note=21,108 do
      for ch=1,16 do
        out_midi:note_off(note, 100, ch)
      end
    end
  end
  pressed_notes = {}
  active_notes = {}
  note_map_to_display = nil
end

-- MIDI
-- MIDI
-- MIDI

function midi.add()
  build_midi_device_list()
end

function midi.remove()
  clock.run(function()
    clock.sleep(0.2)
    build_midi_device_list()
  end)
end

function build_midi_device_list()
  midi_devices = {}
  for i = 1, #midi.vports do
    local long_name = midi.vports[i].name
    local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
    table.insert(midi_devices, short_name)
  end
end

-- listen for MIDI events and do things
function setup_midi_callback()
  stop_all_notes()

  for i = 1, 16 do
    midi.vports[i].event = nil
  end

  -- make new connections
  in_midi = midi.connect(params:get("midi_in_device"))
  out_midi = midi.connect(params:get("midi_out_device"))

  in_midi.event = function(data)
    local message = midi.to_msg(data)
  
    if (message.ch == params:get("midi_in_channel")) then
      if message.type == "note_on" then
        -- normal use
        if map_key_step == nil then
          pressed_notes[message.note] = message.note
          diff_output()
          update_map_name_state(message.note, true)

        -- selecting a trigger note in a new mapping
        elseif map_key_step == "input" then
          map_key_input = message.note

        -- selecting output notes in a new mapping
        elseif map_key_step == "output" then
          -- toggle note selected / unselected
          if map_key_output[message.note] then
            map_key_output[message.note] = nil
          else
            map_key_output[message.note] = message.note
          end
        end

      elseif message.type == "note_off" then
        pressed_notes[message.note] = nil
        diff_output()
        update_map_name_state(message.note, false)
      end
    end
  
    redraw()
  end
end

-- PRESETS
-- PRESETS
-- PRESETS

-- parse a Ripchord preset (.rpc)
-- TODO: make this more resilient to poorly formatted files
function parse_preset(path)
  -- clear old preset
  note_to_notes = {}
  local inNote = nil
  local outNotes = {}
  local i, j, match

  -- iterate over each line of the file looking for data
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
        note = tonumber(token)
        outNotes[note] = note
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

-- load a Ripchord preset (.rpc)
function load_preset(path)
  if not path or path == "cancel" then return end

  -- check if the file exists
  local f = io.open(path,"r")
  if f == nil then
    print("file not found: "..path)
    return
  else
    f:close()
    parse_preset(path)
  end

  -- stash the preset name
  local split_at = string.match(path, "^.*()/")
  selected_preset_name = string.sub(path, split_at + 1, #path - 4)

  redraw()
end

-- load a random preset from "ripchord/presets" and subdirectories
-- TODO give feedback if user doesn't have any presets
function load_random_preset()
  -- return to main page
  page = 0

  -- find all presets
  local all_presets = {}
  local pfile = io.popen('find "'..preset_dir..'" -name *.rpc')
  for filename in pfile:lines() do
    table.insert(all_presets, filename)
  end
  pfile:close()

  -- load a random one, if there are any
  if #all_presets > 0 then
    local random_preset = all_presets[math.random(#all_presets)]
    load_preset(random_preset)
  else
    redraw()
  end
end

-- convert in-memory mapping to a Ripchord preset (.rpc) which is XML
function stringify_preset()
  local start_str = '<?xml version="1.0" encoding="UTF-8"?>\n<ripchord>\n  <preset>\n'
  local end_str = '  </preset>\n</ripchord>'

  local output = start_str
  for note, map in pairs(note_to_notes) do
    output = output..'    <input note="'..note..'">\n      <chord name="'
    if mapping_names[note] then
      output = output..mapping_names[note]
    end
    output = output..'" notes="'

    -- bunch of BS to sort the notes
    local arr = {}
    for _, k in pairs(map) do
      table.insert(arr, k)
    end
    table.sort(arr, function(a, b) return a < b end)
    tab.print(arr)
    local merged = table.concat(arr, ";")

    output = output..merged..'"/>\n    </input>\n'
  end

  return output..end_str
end

-- save a Ripchord preset (.rpc) which is XML
function save_preset(name)
  -- need a file name
  if (name == nil or name == "") then
    return
  end

  -- make sure the user preset dir exists
  os.execute("mkdir -p "..user_preset_dir)

  -- write the file
  local path = user_preset_dir.."/"..name..".rpc"
  local file = io.open(path, "w")
  file:write(stringify_preset())
  file:close()

  -- update state
  dirty = false
  selected_preset_name = name
  page = 0

  redraw()
end

-- DRAWERS
-- DRAWERS
-- DRAWERS

-- the main page of the app
function draw_ripchord_page()
  screen.level(2)

  local preset_text = "preset: "
  -- hint user needs to save
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

  -- input keyboard
  draw_keyboard(44, pressed_notes, note_to_notes)
  -- output keyboard
  draw_keyboard(54, active_notes, {})

  -- key: mapping text
  -- ie "C: C Major"
  -- TODO: this seems overly complicated
  if note_map_to_display then
    local mapping_to_display = key_map[note_map_to_display]
    local mapping_name_to_display = mapping_names[note_map_to_display]
    if mapping_name_to_display and mapping_name_to_display ~= "" then
      mapping_to_display = mapping_to_display..": "..mapping_name_to_display
    end
    screen.move(1, 64)
    screen.level(2)
    screen.text(mapping_to_display)
  end
end

-- UI for making a new key mapping
-- TODO: could this just be a separate page?
function draw_mapper_ui()
  local input_text = "input note"
  if map_key_input then
    input_text = input_text..": "..key_map[map_key_input]
  end
  screen.move(1, 10)
  screen.text(input_text)

  -- select the trigger note
  if map_key_step == "input" then
    -- highlight the selected trigger
    local highlight = {}
    if map_key_input then
      highlight[map_key_input] = map_key_input
    end

    draw_keyboard(44, highlight, note_to_notes)

    screen.move(2, 62)
    screen.text("cancel: k2")

    -- only show next if a key has been selected
    if map_key_input ~= nil then
      screen.move(126, 62)
      screen.text_right("next: k3")
    end

  -- select the output notes
  elseif map_key_step == "output" then
    -- show the number of output notes
    local output_count = 0
    for _ in pairs(map_key_output) do
      output_count = output_count + 1
    end
    local text = "output notes: "..output_count
    screen.move(1, 20)
    screen.text(text)

    draw_keyboard(44, map_key_output, {})

    screen.move(2, 62)
    screen.text("back: k2")

    -- only show next if output notes are selected
    if output_count > 0 then
      screen.move(126, 62)
      screen.text_right("next: k3")
    end
  end
end

-- settings page UI
function draw_settings_page()
  -- handle sticky scrolling
  local yOffset = 0
  if active_settings_index < 4 then
    yOffset = 0
  else
    yOffset = -10 * (active_settings_index - 1) + (10 * 3)
  end

  in_midi_index = params:get("midi_in_device")
  draw_line(yOffset + 0, "in:", in_midi_index.." "..midi_devices[in_midi_index], active_settings_index==1)
  draw_line(yOffset + 10, "in ch:", params:get("midi_in_channel"), active_settings_index==2)

  out_midi_index = params:get("midi_out_device")
  draw_line(yOffset + 20, "out:", out_midi_index .." "..midi_devices[out_midi_index], active_settings_index==3)
  draw_line(yOffset + 30, "out ch:", params:get("midi_out_channel"), active_settings_index==4)
  
  draw_line(yOffset + 40, "save preset", "", active_settings_index==5)
  draw_line(yOffset + 50, "load random preset", "", active_settings_index==6)
end

-- draw a selectable line of text
function draw_line(yPos, leftText, rightText, active)
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

-- draw an individual key on the keyboard
function draw_key(xPos, yPos, highlighted, filled)
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

-- draw a fill keyboard
function draw_keyboard(yPos, notesToHighlight, notesToFill)
  local sorted_keys = tab.sort(key_map)

  -- handle moving the keyboard left/right
  local xPos = 10 + keyboard_offset

  for _, note in pairs(sorted_keys) do
    local name = key_map[note]
    local highlight = notesToHighlight[note]
    local fill = notesToFill[note]

    -- check if it's a white or black key by name
    if string.len(name) == 2 then
      -- white keys
      draw_key(xPos, yPos, highlight, fill)

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
      -- black keys
      xPos = xPos - 2
      draw_key(xPos, yPos - 4, highlight, fill)
      xPos = xPos + 2
    end
  end
end

-- HANDLERS
-- HANDLERS
-- HANDLERS

-- callback for keys on the new mapping page
function handle_mapping_key(n, z)
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

    redraw()
  elseif n == 3 then
    if map_key_step == "input" then
      -- next
      map_key_step = "output"

      -- if a mapping exists for that key load it
      if note_to_notes[map_key_input] then
        for _, v in pairs(note_to_notes[map_key_input]) do
          map_key_output[v] = v
        end
      end

      redraw()
    elseif map_key_step == "output" then
      -- textentry callback
      function cb(name)
        -- if they hit the back button
        if (name == nil) then
          map_key_step = "output"
          redraw()
          return
        end

        -- finish

        -- let the user know they need to save
        dirty = true

        -- store mapping data
        note_to_notes[map_key_input] = map_key_output
        mapping_names[map_key_input] = name

        -- reset mapper state
        map_key_step = nil
        map_key_input = nil
        map_key_output = {}

        redraw()
      end

      textentry.enter(cb, "", "mapping name")
    end
  end
end

-- callback for keys on the main page
function handle_ripchord_key(n,z)
  -- cb for when they're in the mapper UI
  if map_key_step ~= nil then
    handle_mapping_key(n, z)

  -- load a preset
  elseif n == 2 then
    fileselect.enter(preset_dir, load_preset)

  -- trigger mapper UI
  elseif n == 3 then
    map_key_step = "input"
    redraw()
  end
end

-- callback for keys on the setting page
function handle_settings_key(n,z)
  if n == 3 then
    if active_settings_index == 5 then
      -- trigger preset save flow when "save" option is selected
      local default = ""
      if selected_preset_name then
        default = selected_preset_name
      end
      textentry.enter(save_preset, default, "save to presets/user")
    elseif active_settings_index == 6 then
      -- load a random preset
      load_random_preset()
    end
  end
end

-- callback for encoders on the main page
function handle_ripchord_enc(n,d)
  if (n == 2) then
    -- transpost output
    local prev_transpose_output = transpose_output
    transpose_output = util.clamp(transpose_output + d, -24, 24)
    if prev_transpose_output ~= transpose_output then
      diff_output()
    end
  elseif (n == 3) then
    -- move keyboard left/right
    keyboard_offset = util.clamp(keyboard_offset + d, -200, 50)
  end
end

-- callback for encoders on the settings page
function handle_settings_enc(n,d)
  if n == 2 then
    -- select which parameter to adjust
    active_settings_index = util.clamp(active_settings_index + d, 1, 6)
  elseif n == 3 then
    if (active_settings_index == 1) then
      -- MIDI in device
      params:set("midi_in_device", params:get("midi_in_device") + d)
    elseif (active_settings_index == 2) then
      -- MIDI in channel
      params:set("midi_in_channel", params:get("midi_in_channel") + d)
    elseif (active_settings_index == 3) then
      -- MIDI out device
      params:set("midi_out_device", params:get("midi_out_device") + d)
    elseif (active_settings_index == 4) then
      -- MIDI out channel
      params:set("midi_out_channel", params:get("midi_out_channel") + d)
    end
  end
end