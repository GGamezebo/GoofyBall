--[[
  Goofy Balls — Phase 4 friend rooms (Lua).
  RPCs: room_create, room_join, room_close
  Clients join via NakamaMultiplayerBridge.join_named_match(match_name).
  Storage: collection room_codes / key CODE (uppercase)
]]

local nk = require("nakama")

local MODULE_VERSION = "1.1.0"
local COLLECTION = "room_codes"
local RATE_COLLECTION = "player"
local RATE_KEY = "room_join_meta"
local CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local CODE_LEN = 4
local TTL_SEC = 45 * 60
local MAX_PLAYERS = 2
local MIN_JOIN_INTERVAL_SEC = 1
local MAX_JOIN_ATTEMPTS_WINDOW = 20
local JOIN_WINDOW_SEC = 60

local function as_nonneg_int(v)
  local n = tonumber(v) or 0
  if n < 0 then
    n = 0
  end
  return math.floor(n)
end

local function decode_payload(payload)
  if payload == nil or payload == "" then
    return {}
  end
  if type(payload) == "table" then
    return payload
  end
  if type(payload) ~= "string" then
    return {}
  end
  local ok, decoded = pcall(nk.json_decode, payload)
  if not ok then
    return {}
  end
  if type(decoded) == "string" then
    local ok2, decoded2 = pcall(nk.json_decode, decoded)
    if ok2 and type(decoded2) == "table" then
      return decoded2
    end
    return {}
  end
  if type(decoded) == "table" then
    return decoded
  end
  return {}
end

local function require_user(context)
  if context.user_id == nil or context.user_id == "" then
    error("Auth required")
  end
  return context.user_id
end

local function normalize_code(raw)
  local code = string.upper(tostring(raw or ""))
  code = string.gsub(code, "%s+", "")
  return code
end

local function random_code()
  local entropy = string.gsub(nk.uuid_v4() .. nk.uuid_v4(), "%-", "")
  local out = {}
  for i = 1, CODE_LEN do
    local byte = string.byte(entropy, ((i - 1) * 4) % #entropy + 1) or 65
    local idx = (byte % #CODE_ALPHABET) + 1
    out[i] = string.sub(CODE_ALPHABET, idx, idx)
  end
  return table.concat(out)
end

local function read_room(code)
  local objects = nk.storage_read({
    { collection = COLLECTION, key = code, user_id = nil }
  })
  if objects == nil or #objects == 0 then
    return nil
  end
  return objects[1].value
end

local function write_room(code, value)
  nk.storage_write({
    {
      collection = COLLECTION,
      key = code,
      user_id = nil,
      value = value,
      permission_read = 0,
      permission_write = 0
    }
  })
end

local function delete_room(code)
  nk.storage_delete({
    { collection = COLLECTION, key = code, user_id = nil }
  })
end

local function is_expired(room, now)
  return room == nil or as_nonneg_int(room.expires_at) <= now
end

local function check_join_rate(user_id, now)
  local objects = nk.storage_read({
    { collection = RATE_COLLECTION, key = RATE_KEY, user_id = user_id }
  })
  local meta = { window_start = now, attempts = 0, last_at = 0 }
  if objects ~= nil and #objects > 0 and type(objects[1].value) == "table" then
    meta.window_start = as_nonneg_int(objects[1].value.window_start)
    meta.attempts = as_nonneg_int(objects[1].value.attempts)
    meta.last_at = as_nonneg_int(objects[1].value.last_at)
  end
  if meta.last_at > 0 and (now - meta.last_at) < MIN_JOIN_INTERVAL_SEC then
    return false, "rate_limited"
  end
  if (now - meta.window_start) > JOIN_WINDOW_SEC then
    meta.window_start = now
    meta.attempts = 0
  end
  if meta.attempts >= MAX_JOIN_ATTEMPTS_WINDOW then
    return false, "too_many_attempts"
  end
  meta.attempts = meta.attempts + 1
  meta.last_at = now
  nk.storage_write({
    {
      collection = RATE_COLLECTION,
      key = RATE_KEY,
      user_id = user_id,
      value = meta,
      permission_read = 0,
      permission_write = 0
    }
  })
  return true, nil
end

local function allocate_code()
  for _ = 1, 32 do
    local code = random_code()
    local existing = read_room(code)
    local now = os.time()
    if existing == nil or is_expired(existing, now) then
      return code
    end
  end
  error("could not allocate room code")
end

local function rpc_room_create(context, payload)
  local user_id = require_user(context)
  local body = decode_payload(payload)
  local region = tostring(body.region or "any")
  local now = os.time()
  local code = allocate_code()
  -- Relayed named match for NakamaMultiplayerBridge.join_named_match
  local match_name = "gb_room_" .. code

  local room = {
    code = code,
    match_name = match_name,
    match_id = match_name,
    host_id = user_id,
    region = region,
    max_players = MAX_PLAYERS,
    created_at = now,
    expires_at = now + TTL_SEC,
    closed = false,
    relayed = true
  }
  write_room(code, room)

  return nk.json_encode({
    ok = true,
    code = code,
    match_name = match_name,
    match_id = match_name,
    expires_at = room.expires_at,
    max_players = MAX_PLAYERS,
    module_version = MODULE_VERSION
  })
end

local function rpc_room_join(context, payload)
  local user_id = require_user(context)
  local body = decode_payload(payload)
  local code = normalize_code(body.code)
  if #code ~= CODE_LEN then
    error("invalid room code")
  end
  local now = os.time()
  local ok_rate, reason = check_join_rate(user_id, now)
  if not ok_rate then
    return nk.json_encode({
      ok = false,
      error = reason,
      module_version = MODULE_VERSION
    })
  end

  local room = read_room(code)
  if room == nil or room.closed == true or is_expired(room, now) then
    if room ~= nil then
      delete_room(code)
    end
    return nk.json_encode({
      ok = false,
      error = "room_not_found",
      module_version = MODULE_VERSION
    })
  end

  local match_name = room.match_name or room.match_id or ("gb_room_" .. code)
  return nk.json_encode({
    ok = true,
    code = code,
    match_name = match_name,
    match_id = match_name,
    host_id = room.host_id,
    expires_at = room.expires_at,
    module_version = MODULE_VERSION
  })
end

local function rpc_room_close(context, payload)
  local user_id = require_user(context)
  local body = decode_payload(payload)
  local code = normalize_code(body.code)
  if #code ~= CODE_LEN then
    error("invalid room code")
  end
  local room = read_room(code)
  if room == nil then
    return nk.json_encode({
      ok = false,
      error = "room_not_found",
      module_version = MODULE_VERSION
    })
  end
  if room.host_id ~= user_id then
    return nk.json_encode({
      ok = false,
      error = "not_host",
      module_version = MODULE_VERSION
    })
  end
  delete_room(code)
  return nk.json_encode({
    ok = true,
    code = code,
    closed = true,
    module_version = MODULE_VERSION
  })
end

nk.register_rpc(rpc_room_create, "room_create")
nk.register_rpc(rpc_room_join, "room_join")
nk.register_rpc(rpc_room_close, "room_close")
nk.logger_info("Goofy Balls rooms module loaded v" .. MODULE_VERSION)
