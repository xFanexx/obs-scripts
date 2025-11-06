--[[
Replay Buffer Sound Script (Unicode-safe + cooldown)
Plays a specified sound file whenever the OBS replay buffer is saved (Windows only).
- Uses PlaySoundW (UTF-16) to support non-ASCII paths
- Robust DLL loading & error logging
- Cooldown to avoid rapid re-trigger spam
]]

local obs = obslua
local ffi = require("ffi")
local bit = require("bit")

-- Globals
local winmm, kernel32 = nil, nil
local sound_file_path = ""
local sound_enabled = true
local cooldown_ms = 0
local last_play_ms = -1

-- WinAPI FFI
ffi.cdef[[
  // kernel32 for UTF-8 -> UTF-16 conversion
  int __stdcall MultiByteToWideChar(unsigned int CodePage, unsigned int dwFlags,
                                    const char *lpMultiByteStr, int cbMultiByte,
                                    wchar_t *lpWideCharStr, int cchWideChar);

  // winmm PlaySoundW (Unicode)
  int __stdcall PlaySoundW(const wchar_t *pszSound, void *hmod, unsigned int fdwSound);
]]

-- PlaySound flags
local SND_ASYNC     = 0x00000001
local SND_NODEFAULT = 0x00000002
local SND_FILENAME  = 0x00020000

local CP_UTF8 = 65001

-- Time helpers (ms)
local function now_ms()
  if obs.os_gettime_ns then
    return math.floor(obs.os_gettime_ns() / 1e6)
  else
    return math.floor((os.clock() or 0) * 1000)
  end
end

local function can_play_now()
  if cooldown_ms <= 0 or last_play_ms < 0 then return true end
  return (now_ms() - last_play_ms) >= cooldown_ms
end

-- UTF-8 -> UTF-16 helper
local function utf8_to_wide(str)
  if not str or str == "" then return nil end
  local needed = ffi.C.MultiByteToWideChar(CP_UTF8, 0, str, #str, nil, 0)
  if needed == 0 then return nil end
  local buf = ffi.new("wchar_t[?]", needed + 1)
  local wrote = ffi.C.MultiByteToWideChar(CP_UTF8, 0, str, #str, buf, needed)
  if wrote == 0 then return nil end
  buf[needed] = 0
  return buf
end

-- Safely init DLLs
local function init_libs()
  if not kernel32 then
    local ok, res = pcall(function() return ffi.load("kernel32") end)
    if ok then kernel32 = res else
      obs.script_log(obs.LOG_ERROR, "[replay-buffer-sound] Failed to load kernel32: " .. tostring(res))
      return false
    end
  end
  if not winmm then
    local ok, res = pcall(function() return ffi.load("winmm") end)
    if ok then winmm = res else
      obs.script_log(obs.LOG_ERROR, "[replay-buffer-sound] Failed to load winmm.dll: " .. tostring(res))
      return false
    end
  end
  return true
end

-- Play sound
local function play_sound(filepath)
  if not sound_enabled or not filepath or filepath == "" then
    return false
  end
  if not can_play_now() then
    return false
  end
  if not init_libs() then
    return false
  end

  if not obs.os_file_exists(filepath) then
    obs.script_log(obs.LOG_WARNING, "[replay-buffer-sound] Sound file not found: " .. filepath)
    return false
  end

  local wpath = utf8_to_wide(filepath)
  if wpath == nil then
    obs.script_log(obs.LOG_ERROR, "[replay-buffer-sound] Failed converting path to UTF-16: " .. tostring(filepath))
    return false
  end

  local flags = bit.bor(SND_FILENAME, SND_ASYNC, SND_NODEFAULT)

  local ok, ret = pcall(function()
    return winmm.PlaySoundW(wpath, nil, flags)
  end)

  if not ok then
    obs.script_log(obs.LOG_ERROR, "[replay-buffer-sound] Error playing sound: " .. tostring(ret))
    return false
  end

  if ret ~= 0 then
    last_play_ms = now_ms()
    return true
  else
    return false
  end
end

-- OBS event
local function on_event(event)
  if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
    play_sound(sound_file_path)
  end
end

-- UI
function script_properties()
  local props = obs.obs_properties_create()
  obs.obs_properties_add_path(props, "sound_file", "Sound File",
    obs.OBS_PATH_FILE, "Audio Files (*.wav)", nil)
  obs.obs_properties_add_bool(props, "sound_enabled", "Enable Sound")

  local p_cd = obs.obs_properties_add_int(props, "cooldown_ms", "Cooldown (ms)", 0, 60000, 50)
  obs.obs_property_set_long_description(p_cd, "Minimum delay between plays; useful if multiple saves happen quickly.")

  obs.obs_properties_add_button(props, "test_button", "Test Sound", function()
    play_sound(sound_file_path)
    return false
  end)
  return props
end

function script_description()
  return [[
<h2>Replay Buffer Sound</h2>
<p>Plays a sound when the replay buffer is saved.</p>
<ul>
  <li>Select a sound file (.wav recommended)</li>
  <li>Enable the checkbox</li>
  <li>Optional: set a cooldown in milliseconds</li>
  <li>Use "Test Sound" to preview</li>
</ul>
<p><strong>Windows only. Unicode-safe.</strong></p>
]]
end

function script_defaults(settings)
  obs.obs_data_set_default_bool(settings, "sound_enabled", true)
  obs.obs_data_set_default_int(settings, "cooldown_ms", 0)
end

function script_update(settings)
  sound_file_path = obs.obs_data_get_string(settings, "sound_file")
  sound_enabled   = obs.obs_data_get_bool(settings, "sound_enabled")
  cooldown_ms     = obs.obs_data_get_int(settings, "cooldown_ms") or 0
  obs.script_log(obs.LOG_INFO, "[replay-buffer-sound] Sound file: " .. (sound_file_path ~= "" and sound_file_path or "<none>"))
  obs.script_log(obs.LOG_INFO, "[replay-buffer-sound] Enabled: " .. tostring(sound_enabled) .. ", Cooldown: " .. tostring(cooldown_ms) .. " ms")
end

function script_load(_settings)
  init_libs()
  obs.obs_frontend_add_event_callback(on_event)
  obs.script_log(obs.LOG_INFO, "[replay-buffer-sound] Loaded")
end

function script_unload()
  -- stop any playing sound (pass NULL to stop)
  if winmm then pcall(function() winmm.PlaySoundW(nil, nil, 0) end) end
  obs.script_log(obs.LOG_INFO, "[replay-buffer-sound] Unloaded")
end
