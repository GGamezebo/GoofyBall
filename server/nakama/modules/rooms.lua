--[[
  Goofy Ball — friend rooms by code (iteration 1).
  RPCs: room_create, room_join, room_close
  The room is only a code -> relayed named match mapping (+ match seed). Clients then join
  the relayed match with NakamaMultiplayerBridge.join_named_match(match_name); the first one
  in becomes the host (peer 1). The game itself never runs on the server: only inputs are relayed.
  Storage: collection room_codes / key CODE (uppercase), system-owned.
]]

local nk = require("nakama")

local MODULE_VERSION = "2.0.0"
local COLLECTION = "room_codes"
local RATE_COLLECTION = "player"
local RATE_KEY = "room_join_meta"
-- No 0/O, 1/I: codes are read aloud and typed on phones.
local CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local CODE_LEN = 4
local TTL_SEC = 3 * 60 * 60
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
  local ok, decoded = pcall(nk.json_decode, payload)
  if ok and type(decoded) == "table" then
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
    local byte = string.byte(entropy, (i - 1) * 7 + 1) or 65
    local idx = (byte * 7 + i * 13) % #CODE_ALPHABET + 1
    out[i] = string.sub(CODE_ALPHABET, idx, idx)
  end
  return table.concat(out)
end

-- Match seed is owned by the server (31-bit int, never 0).
local function random_seed()
  local hex = string.sub(string.gsub(nk.uuid_v4(), "%-", ""), 1, 7)
  local seed = tonumber(hex, 16) or 1
  if seed == 0 then
    seed = 1
  end
  return seed
end

local function read_room(code)
  local objects = nk.storage_read({ { collection = COLLECTION, key = code, user_id = nil } })
  if objects == nil or #objects == 0 then
    return nil
  end
  return objects[1].value
end

local function write_room(code, value)
  nk.storage_write({
    { collection = COLLECTION, key = code, user_id = nil, value = value, permission_read = 0, permission_write = 0 }
  })
end

local function delete_room(code)
  nk.storage_delete({ { collection = COLLECTION, key = code, user_id = nil } })
end

local function is_expired(room, now)
  return room == nil or as_nonneg_int(room.expires_at) <= now
end

local function check_join_rate(user_id, now)
  local objects = nk.storage_read({ { collection = RATE_COLLECTION, key = RATE_KEY, user_id = user_id } })
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
    { collection = RATE_COLLECTION, key = RATE_KEY, user_id = user_id, value = meta, permission_read = 0, permission_write = 0 }
  })
  return true, nil
end

local function allocate_code(now)
  for _ = 1, 32 do
    local code = random_code()
    local existing = read_room(code)
    if existing == nil or is_expired(existing, now) then
      return code
    end
  end
  error("could not allocate room code")
end

local function rpc_room_create(context, payload)
  local user_id = require_user(context)
  local now = os.time()
  local code = allocate_code(now)
  local match_name = "gb_room_" .. code
  local room = {
    code = code,
    match_name = match_name,
    host_id = user_id,
    seed = random_seed(),
    max_players = MAX_PLAYERS,
    created_at = now,
    expires_at = now + TTL_SEC,
  }
  write_room(code, room)
  nk.logger_info(string.format("room_created code=%s host=%s", code, user_id))
  return nk.json_encode({
    ok = true,
    code = code,
    match_name = match_name,
    seed = room.seed,
    max_players = MAX_PLAYERS,
    expires_at = room.expires_at,
    module_version = MODULE_VERSION,
  })
end

local function rpc_room_join(context, payload)
  local user_id = require_user(context)
  local body = decode_payload(payload)
  local code = normalize_code(body.code)
  if #code ~= CODE_LEN then
    return nk.json_encode({ ok = false, error = "invalid_code", module_version = MODULE_VERSION })
  end
  local now = os.time()
  local ok_rate, reason = check_join_rate(user_id, now)
  if not ok_rate then
    return nk.json_encode({ ok = false, error = reason, module_version = MODULE_VERSION })
  end
  local room = read_room(code)
  if room == nil or is_expired(room, now) then
    if room ~= nil then
      delete_room(code)
    end
    return nk.json_encode({ ok = false, error = "room_not_found", module_version = MODULE_VERSION })
  end
  nk.logger_info(string.format("room_join code=%s user=%s", code, user_id))
  return nk.json_encode({
    ok = true,
    code = code,
    match_name = room.match_name,
    seed = room.seed,
    host_id = room.host_id,
    max_players = room.max_players or MAX_PLAYERS,
    module_version = MODULE_VERSION,
  })
end

local function rpc_room_close(context, payload)
  local user_id = require_user(context)
  local body = decode_payload(payload)
  local code = normalize_code(body.code)
  local room = read_room(code)
  if room == nil then
    return nk.json_encode({ ok = false, error = "room_not_found", module_version = MODULE_VERSION })
  end
  if room.host_id ~= user_id then
    return nk.json_encode({ ok = false, error = "not_host", module_version = MODULE_VERSION })
  end
  delete_room(code)
  return nk.json_encode({ ok = true, code = code, closed = true, module_version = MODULE_VERSION })
end

nk.register_rpc(rpc_room_create, "room_create")
nk.register_rpc(rpc_room_join, "room_join")
nk.register_rpc(rpc_room_close, "room_close")
nk.logger_info("Goofy Ball rooms module loaded v" .. MODULE_VERSION)
