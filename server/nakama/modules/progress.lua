--[[
  Goofy Balls — Phase 2 cloud progress (Lua).
  Storage: collection "player" / key "progress"
  RPCs: progress_pull, progress_push, progress_merge
]]

local nk = require("nakama")

local MODULE_VERSION = "1.0.0"
local COLLECTION = "player"
local KEY = "progress"
local SCHEMA_VERSION = 1

local function empty_progress()
  return {
    schema_version = SCHEMA_VERSION,
    updated_at = 0,
    matches_played = 0,
    wins_two_player = 0,
    wins_vs_ai = 0,
    losses_vs_ai = 0,
    wins_ranked = 0
  }
end

local function as_nonneg_int(v)
  local n = tonumber(v) or 0
  if n < 0 then
    n = 0
  end
  return math.floor(n)
end

local function sanitize_progress(input)
  local out = empty_progress()
  if type(input) ~= "table" then
    return out
  end
  out.matches_played = as_nonneg_int(input.matches_played)
  out.wins_two_player = as_nonneg_int(input.wins_two_player)
  out.wins_vs_ai = as_nonneg_int(input.wins_vs_ai)
  out.losses_vs_ai = as_nonneg_int(input.losses_vs_ai)
  out.wins_ranked = as_nonneg_int(input.wins_ranked)
  out.updated_at = as_nonneg_int(input.updated_at)
  if out.updated_at == 0 then
    out.updated_at = os.time()
  end
  out.schema_version = SCHEMA_VERSION
  return out
end

local function merge_progress(local_p, remote_p)
  local a = sanitize_progress(local_p)
  local b = sanitize_progress(remote_p)
  return {
    schema_version = SCHEMA_VERSION,
    updated_at = math.max(a.updated_at, b.updated_at, os.time()),
    matches_played = math.max(a.matches_played, b.matches_played),
    wins_two_player = math.max(a.wins_two_player, b.wins_two_player),
    wins_vs_ai = math.max(a.wins_vs_ai, b.wins_vs_ai),
    losses_vs_ai = math.max(a.losses_vs_ai, b.losses_vs_ai),
    wins_ranked = math.max(a.wins_ranked, b.wins_ranked)
  }
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
  -- HTTP clients sometimes double-encode: JSON string containing JSON object text.
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

local function extract_progress(body)
  if type(body) ~= "table" then
    return empty_progress()
  end
  if type(body.progress) == "table" then
    return sanitize_progress(body.progress)
  end
  -- Allow bare progress fields at top level.
  if body.matches_played ~= nil or body.wins_vs_ai ~= nil or body.schema_version ~= nil then
    return sanitize_progress(body)
  end
  return empty_progress()
end

local function require_user(context)
  if context.user_id == nil or context.user_id == "" then
    error("Auth required")
  end
  return context.user_id
end

local function read_progress(user_id)
  local objects = nk.storage_read({
    { collection = COLLECTION, key = KEY, user_id = user_id }
  })
  if objects == nil or #objects == 0 then
    return empty_progress(), false
  end
  local value = objects[1].value
  return sanitize_progress(value), true
end

local function write_progress(user_id, value)
  nk.storage_write({
    {
      collection = COLLECTION,
      key = KEY,
      user_id = user_id,
      value = value,
      permission_read = 1,
      permission_write = 0
    }
  })
end

local function rpc_progress_pull(context, payload)
  local user_id = require_user(context)
  local progress, exists = read_progress(user_id)
  return nk.json_encode({
    ok = true,
    exists = exists,
    progress = progress,
    module_version = MODULE_VERSION
  })
end

local function rpc_progress_push(context, payload)
  local user_id = require_user(context)
  local body = decode_payload(payload)
  local local_p = extract_progress(body)
  local remote_p, exists = read_progress(user_id)
  if exists and remote_p.updated_at > local_p.updated_at then
    return nk.json_encode({
      ok = false,
      conflict = true,
      progress = remote_p,
      module_version = MODULE_VERSION
    })
  end
  write_progress(user_id, local_p)
  return nk.json_encode({
    ok = true,
    conflict = false,
    progress = local_p,
    module_version = MODULE_VERSION
  })
end

local function rpc_progress_merge(context, payload)
  local user_id = require_user(context)
  if type(payload) == "string" then
    nk.logger_info("progress_merge payload=" .. string.sub(payload, 1, 180))
  else
    nk.logger_info("progress_merge payload type=" .. type(payload))
  end
  local body = decode_payload(payload)
  local local_p = extract_progress(body)
  local remote_p, _exists = read_progress(user_id)
  local merged = merge_progress(local_p, remote_p)
  write_progress(user_id, merged)
  return nk.json_encode({
    ok = true,
    progress = merged,
    module_version = MODULE_VERSION
  })
end

nk.register_rpc(rpc_progress_pull, "progress_pull")
nk.register_rpc(rpc_progress_push, "progress_push")
nk.register_rpc(rpc_progress_merge, "progress_merge")
nk.logger_info("Goofy Balls progress module loaded v" .. MODULE_VERSION)
