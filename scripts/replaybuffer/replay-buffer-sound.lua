--[[
Replay Buffer Sound Script (Unicode-safe + cooldown)
Plays a specified sound file whenever the OBS replay buffer is saved (Windows only).
]]

local obs = obslua
local ffi = require("ffi")

-- Globals
local kernel32, winmm = nil, nil
local MultiByteToWideChar, PlaySoundW = nil, nil

local sound_file_path = ""
local sound_file_path_wide = nil
local file_exists = false
local sound_enabled = true
local cooldown_ms = 0
local last_play_ms = -1

-- WinAPI FFI
ffi.cdef[[
  int __stdcall MultiByteToWideChar(unsigned int CodePage, unsigned int dwFlags,
                                    const char *lpMultiByteStr, int cbMultiByte,
                                    wchar_t *lpWideCharStr, int cchWideChar);
  int __stdcall PlaySoundW(const wchar_t *pszSound, void *hmod, unsigned int fdwSound);
]]

-- Constants
local CP_UTF8 = 65001
local PLAY_FLAGS = 0x00020003  -- SND_FILENAME | SND_ASYNC | SND_NODEFAULT

-- Time helper
local time_func = obs.os_gettime_ns and 
  function() return math.floor(obs.os_gettime_ns() / 1e6) end or
  function() return math.floor((os.clock() or 0) * 1000) end

local function now_ms()
  return time_func()
end

local function can_play_now()
  return cooldown_ms <= 0 or last_play_ms < 0 or (now_ms() - last_play_ms) >= cooldown_ms
end

-- UTF-8 -> UTF-16 helper
local function utf8_to_wide(str)
  if not str or str == "" or not MultiByteToWideChar then return nil end
  
  local needed = MultiByteToWideChar(CP_UTF8, 0, str, #str, nil, 0)
  if needed == 0 then return nil end
  
  local buf = ffi.new("wchar_t[?]", needed + 1)
  local wrote = MultiByteToWideChar(CP_UTF8, 0, str, #str, buf, needed)
  if wrote == 0 then return nil end
  
  buf[needed] = 0
  return buf
end

-- Safely init DLLs
local function init_libs()
  if kernel32 and winmm then return true end
  
  if not kernel32 then
    local ok, res = pcall(function() return ffi.load("kernel32") end)
    if not ok then
      obs.script_log(obs.LOG_ERROR, "[replay-buffer-sound] Failed to load kernel32: " .. tostring(res))
      return false
    end
    kernel32 = res
    MultiByteToWideChar = ffi.C.MultiByteToWideChar
  end
  
  if not winmm then
    local ok, res = pcall(function() return ffi.load("winmm") end)
    if not ok then
      obs.script_log(obs.LOG_ERROR, "[replay-buffer-sound] Failed to load winmm.dll: " .. tostring(res))
      return false
    end
    winmm = res
    PlaySoundW = winmm.PlaySoundW
  end
  
  return true
end

-- Play sound (uses cached wide string)
local function play_sound()
  if not (sound_enabled and file_exists and sound_file_path_wide and can_play_now() and init_libs()) then
    return false
  end

  local ok, ret = pcall(PlaySoundW, sound_file_path_wide, nil, PLAY_FLAGS)

  if ok and ret ~= 0 then
    last_play_ms = now_ms()
    return true
  end
  
  if not ok then
    obs.script_log(obs.LOG_ERROR, "[replay-buffer-sound] Error playing sound: " .. tostring(ret))
  end
  
  return false
end

-- OBS event
local function on_event(event)
  if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
    play_sound()
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
    play_sound()
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
  local new_path = obs.obs_data_get_string(settings, "sound_file")
  
  if new_path ~= sound_file_path then
    sound_file_path = new_path
    file_exists = false
    sound_file_path_wide = nil
    
    if new_path ~= "" and obs.os_file_exists(new_path) then
      sound_file_path_wide = utf8_to_wide(new_path)
      file_exists = sound_file_path_wide ~= nil
      
      if not file_exists then
        obs.script_log(obs.LOG_WARNING, "[replay-buffer-sound] Failed to convert path to UTF-16")
      end
    elseif new_path ~= "" then
      obs.script_log(obs.LOG_WARNING, "[replay-buffer-sound] Sound file not found: " .. new_path)
    end
  end
  
  sound_enabled = obs.obs_data_get_bool(settings, "sound_enabled")
  cooldown_ms = obs.obs_data_get_int(settings, "cooldown_ms") or 0
  
  obs.script_log(obs.LOG_INFO, string.format(
    "[replay-buffer-sound] Sound file: %s, Enabled: %s, Cooldown: %d ms",
    sound_file_path ~= "" and sound_file_path or "<none>",
    tostring(sound_enabled),
    cooldown_ms
  ))
end

function script_load(_settings)
  init_libs()
  obs.obs_frontend_add_event_callback(on_event)
  obs.script_log(obs.LOG_INFO, "[replay-buffer-sound] Loaded")
end

function script_unload()
  if PlaySoundW then pcall(PlaySoundW, nil, nil, 0) end
  obs.script_log(obs.LOG_INFO, "[replay-buffer-sound] Unloaded")
end
