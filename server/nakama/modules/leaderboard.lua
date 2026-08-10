--[[
  Goofy Balls — Phase 3 leaderboard (Lua).
  Board: global_wins (authoritative, desc, set)
  RPCs: submit_match_result, leaderboard_top
  Policy: vs_ai / local_2p update progress only; ranked also writes the board.
]]

local nk = require("nakama")

local MODULE_VERSION = "1.0.0"
local BOARD_ID = "global_wins"
local COLLECTION = "player"
local PROGRESS_KEY = "progress"
local RATE_KEY = "match_submit_meta"
local SCHEMA_VERSION = 1
local MIN_SUBMIT_INTERVAL_SEC = 2

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

local function read_progress(user_id)
  local objects = nk.storage_read({
    { collection = COLLECTION, key = PROGRESS_KEY, user_id = user_id }
  })
  if objects == nil or #objects == 0 then
    return empty_progress(), false
  end
  return sanitize_progress(objects[1].value), true
end

local function write_progress(user_id, value)
  nk.storage_write({
    {
      collection = COLLECTION,
      key = PROGRESS_KEY,
      user_id = user_id,
      value = value,
      permission_read = 1,
      permission_write = 0
    }
  })
end

local function read_rate_meta(user_id)
  local objects = nk.storage_read({
    { collection = COLLECTION, key = RATE_KEY, user_id = user_id }
  })
  if objects == nil or #objects == 0 then
    return { last_submit_at = 0 }
  end
  local v = objects[1].value or {}
  return { last_submit_at = as_nonneg_int(v.last_submit_at) }
end

local function write_rate_meta(user_id, meta)
  nk.storage_write({
    {
      collection = COLLECTION,
      key = RATE_KEY,
      user_id = user_id,
      value = meta,
      permission_read = 0,
      permission_write = 0
    }
  })
end

local function ensure_board()
  -- authoritative=true → clients cannot write scores directly
  nk.leaderboard_create(BOARD_ID, true, "desc", "set", "", {
    game = "goofy_balls",
    metric = "ranked_wins"
  }, true)
end

local function username_for(user_id)
  local ok, account = pcall(nk.account_get_id, user_id)
  if not ok or account == nil or account.user == nil then
    return ""
  end
  return account.user.username or ""
end

local function serialize_record(r)
  if r == nil then
    return nil
  end
  return {
    owner_id = r.owner_id or "",
    username = r.username or "",
    score = as_nonneg_int(r.score),
    subscore = as_nonneg_int(r.subscore),
    rank = as_nonneg_int(r.rank),
    num_score = as_nonneg_int(r.num_score)
  }
end

local function rpc_submit_match_result(context, payload)
  local user_id = require_user(context)
  local body = decode_payload(payload)
  local mode = tostring(body.mode or "")
  if mode ~= "vs_ai" and mode ~= "local_2p" and mode ~= "ranked" then
    error("invalid mode (expected vs_ai|local_2p|ranked)")
  end

  local now = os.time()
  local rate = read_rate_meta(user_id)
  if rate.last_submit_at > 0 and (now - rate.last_submit_at) < MIN_SUBMIT_INTERVAL_SEC then
    return nk.json_encode({
      ok = false,
      rate_limited = true,
      retry_after_sec = MIN_SUBMIT_INTERVAL_SEC - (now - rate.last_submit_at),
      module_version = MODULE_VERSION
    })
  end

  local winner_side = math.floor(tonumber(body.winner_side) or -1)
  local local_side = math.floor(tonumber(body.local_side) or 0)
  if local_side ~= 0 and local_side ~= 1 then
    local_side = 0
  end
  local local_won = (winner_side == local_side)

  -- Casual modes: progress stays on client → progress_merge (offline-first).
  -- Ranked: server increments wins_ranked + authoritative board write.
  local progress = read_progress(user_id)
  local board_updated = false
  local record = nil

  if mode == "ranked" then
    progress.matches_played = progress.matches_played + 1
    progress.updated_at = now
    progress.schema_version = SCHEMA_VERSION
    if local_won then
      progress.wins_ranked = progress.wins_ranked + 1
      write_progress(user_id, progress)
      ensure_board()
      local username = username_for(user_id)
      local written = nk.leaderboard_record_write(
        BOARD_ID,
        user_id,
        username,
        progress.wins_ranked,
        0,
        {
          mode = mode,
          updated_at = now
        },
        "set"
      )
      record = serialize_record(written)
      board_updated = true
    else
      write_progress(user_id, progress)
    end
  end

  write_rate_meta(user_id, { last_submit_at = now })

  return nk.json_encode({
    ok = true,
    rate_limited = false,
    mode = mode,
    local_won = local_won,
    board_updated = board_updated,
    board_id = BOARD_ID,
    progress = progress,
    record = record,
    module_version = MODULE_VERSION
  })
end

local function rpc_leaderboard_top(context, payload)
  require_user(context)
  ensure_board()
  local body = decode_payload(payload)
  local limit = as_nonneg_int(body.limit)
  if limit <= 0 then
    limit = 10
  end
  if limit > 100 then
    limit = 100
  end
  local cursor = body.cursor
  if cursor ~= nil then
    cursor = tostring(cursor)
    if cursor == "" then
      cursor = nil
    end
  end
  -- nil owners = list global top; empty table {} filters to nobody.
  local records, _owner_records, next_cursor, prev_cursor = nk.leaderboard_records_list(
    BOARD_ID,
    nil,
    limit,
    cursor,
    0
  )
  local out = {}
  if type(records) == "table" then
    for _, r in ipairs(records) do
      table.insert(out, serialize_record(r))
    end
  end
  return nk.json_encode({
    ok = true,
    board_id = BOARD_ID,
    records = out,
    next_cursor = next_cursor or "",
    prev_cursor = prev_cursor or "",
    module_version = MODULE_VERSION
  })
end

ensure_board()
nk.register_rpc(rpc_submit_match_result, "submit_match_result")
nk.register_rpc(rpc_leaderboard_top, "leaderboard_top")
nk.logger_info("Goofy Balls leaderboard module loaded v" .. MODULE_VERSION)
