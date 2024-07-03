# Norns Ripchord reader

This is an app for [Norns](https://monome.org/docs/norns/) that reads and writes [Ripchord](https://trackbout.com/ripchord) presets. Thank you to the creators of these open-source projects.

It allows you to associate a single note with a preset- or user-defined chord.

Outputs both MIDI and audio (thanks to the PolyPerc engine).

## Use

> [!CAUTION]
> If you see `preset: !` that means your note-to-chord mapping is not saved. Saving Ripchord presets is different than saving Norns PSETs. PSETs save a reference to a Ripchord file, not the Ripchord mapping itself. If there is no Ripchord file written, there is no reference to it.

> [!IMPORTANT]
> If you're having trouble getting MIDI, check the settings page (e1) _and_ your device settings (SYSTEM > DEVICES > MIDI).

All screens

- e1: switch between screens

Main screen

- e2: transpose outgoing notes
- e3: reposition onscreen keyboard
- k2: load preset
  - looks in `dust/data/ripchord/presets` for `.rpc` files
  - saving presets saves to `dust/data/ripchord/presets/user`
  - consider using [SMB](https://monome.org/docs/norns/fileshare/) to copy/paste presets in the `presets` folder or upload other Ripchord presets you might find
- k3: create a new key mapping
  - using MIDI, pick a trigger note
  - using MIDI, pick notes to play when triggered
  - pick a name for the mapping (optional)

Settings screen

- e2: select a parameter
- e3: change the parameter
- k3: trigger action if action is selected

Onscreen Keyboard

- Top = incoming notes, bottom = outgoing notes
- Dim = inactive, bright = active
- Empty = no mapping for key, filled = mapping for key (top only)
- The weird looking key is middle C

## Additional features

- `preset: !`: the exclamation point is saying the preset has been changed but not saved
- strumming
  - **strum delay**: time between notes
  - **strum sort**: the order strummed notes are played
- output note filtering
  - **filter low notes**: the lowest note that will be be played
  - **filter high notes**: the highest note that will be be played
- **legato**: handles whether a note being played by two mappings should play twice (_false_) or not (_true_)
- **use nearest map**: if a note is played but doesn't have a mapping, the nearest mapping is played instead
- **save preset**: triggers the save preset flow; user presets are saved in `dust/data/ripchord/presets/user`
- **load random preset**: randomly loads a preset from your `dust/data/ripchord/presets` folder
- **mapping from presets**: opens a few random presets from your `dust/data/ripchord/presets` folder and makes a new preset from random chords in the saved presets
- **clear preset**: clears the current presets
