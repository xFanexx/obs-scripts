# Replay Buffer Sound Script

## Overview

A Lua script for OBS Studio that plays a sound notification whenever the replay buffer is saved. Supports Unicode file paths and includes customizable cooldown to prevent sound spam.

## Features

- ✅ **Unicode Support**: Handles non-ASCII characters in file paths using UTF-16 conversion
- ✅ **Customizable Cooldown**: Prevents rapid sound repetition when multiple saves occur
- ✅ **Performance Optimized**: Caches conversions and reduces FFI overhead
- ✅ **Test Button**: Preview your sound before using it
- ✅ **Robust Error Handling**: Detailed logging for troubleshooting

## Requirements

- **Platform**: Windows only (uses `winmm.dll` and `kernel32.dll`)
- **OBS Studio**: Version 27.0 or later recommended
- **Audio Format**: `.wav` files recommended for best compatibility

## Installation

1. Download `replay-buffer-sound.lua` from this repository
2. Open OBS Studio
3. Go to **Tools** → **Scripts**
4. Click the **+** button and select the downloaded `.lua` file
5. Configure the settings (see below)

## Configuration

### Settings

| Setting | Description | Default |
|---------|-------------|---------|
| **Sound File** | Path to the audio file to play | None |
| **Enable Sound** | Toggle sound on/off | Enabled |
| **Cooldown (ms)** | Minimum delay between consecutive plays | 0 ms |

### Recommended Settings

- **Cooldown**: Set to 500-1000ms if you frequently save replays in quick succession
- **Sound File**: Use short, subtle sounds (< 2 seconds) to avoid distraction

## Usage

1. Enable the Replay Buffer in OBS (**Settings** → **Output** → **Replay Buffer**)
2. Configure the script with your desired sound file
3. Press your replay buffer hotkey (default: no hotkey set)
4. The sound will play automatically when the replay is saved

## Included Sound

The default sound (`sound.wav`) was downloaded from:
- **Source**: https://freesound.org/people/deadrobotmusic/sounds/750607/
- **License**: [Creative Commons 0 (CC0 1.0 Universal)](https://creativecommons.org/publicdomain/zero/1.0/)
- **Attribution**: Not required, but credit to **deadrobotmusic** is appreciated

### Using Your Own Sound

You can use any `.wav` file. Other formats may work but are not guaranteed. For best results:
- Keep files under 5 seconds
- Use 44.1kHz or 48kHz sample rate
- 16-bit or 24-bit depth recommended

## Troubleshooting

### Sound Not Playing

1. **Check the OBS Script Log** (Tools → Scripts → Script Log)
2. **Verify file path**: Ensure the sound file exists and the path is correct
3. **Test the sound**: Use the "Test Sound" button in the script settings
4. **Check format**: Ensure you're using a `.wav` file

### Common Error Messages

| Error | Solution |
|-------|----------|
| `Sound file not found` | Check that the file path is correct and file exists |
| `Failed to load winmm.dll` | Windows only - ensure you're on Windows OS |
| `Failed converting path to UTF-16` | File path may be corrupted or contain invalid characters |

### Cooldown Not Working

- The cooldown timer starts **after** a sound successfully plays
- Check the Script Log for playback confirmation
- Ensure cooldown value is greater than 0

## Performance Notes

This script is optimized for minimal performance impact:
- UTF-16 conversion is cached (only runs when path changes)
- File existence is validated once per path change
- FFI function references are stored to avoid repeated lookups
- No impact when replay buffer is not being saved

## Technical Details

### How It Works

1. **Event Listener**: Registers for `OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED`
2. **Unicode Handling**: Converts UTF-8 paths to UTF-16 using `MultiByteToWideChar`
3. **Async Playback**: Uses `PlaySoundW` with `SND_ASYNC` flag (non-blocking)
4. **Cooldown Logic**: Tracks last play time using high-resolution timestamps

### FFI Libraries Used

- `kernel32.dll`: Path conversion (UTF-8 → UTF-16)
- `winmm.dll`: Sound playback via `PlaySoundW`

## Version History

### v2.0.0 (2025-11-06)
- Performance optimizations: caching and reduced FFI overhead
- Improved error handling and logging
- Enhanced documentation

### v1.0.0 (Initial)
- Basic replay buffer sound functionality
- Unicode path support
- Cooldown feature

## Contributing

Found a bug or have a feature request? Please open an issue on the [GitHub repository](https://github.com/xFanexx/obs-scripts).

## License

This script is provided as-is for use with OBS Studio. Feel free to modify and redistribute.

## Credits

- **Script Author**: xFanexx
- **Default Sound**: deadrobotmusic (Freesound.org)
- **Optimization**: Performance improvements in v2.0.0

## Related Resources

- [OBS Studio Scripting Documentation](https://obsproject.com/docs/scripting.html)
- [LuaJIT FFI Documentation](http://luajit.org/ext_ffi.html)
- [Freesound.org](https://freesound.org/) - Free sound effects library

---

**Platform Support**: Windows only  
**Last Updated**: 2025-11-06
```The sound was downloaded from https://freesound.org/people/deadrobotmusic/sounds/750607/ 
and is licensed under Creative Commons 0.

SEE : https://creativecommons.org/publicdomain/zero/1.0/
