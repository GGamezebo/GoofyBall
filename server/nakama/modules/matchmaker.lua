--[[
  Goofy Balls — Phase 4 ranked matchmaker (HTTP-friendly lobby).
  Pool: ranked_1v1  |  properties: skill, region  |  count = 2
  RPCs: mm_enqueue, mm_status, mm_cancel
  Realtime join uses returned match_id (bridge later).
]]

local nk = require("nakama")

local MODULE_VERSION = "1.1.0"
local POOL = "ranked_1v1"
local OPEN_COLLECTION = "mm_open"
local TICKET_COLLECTION = "mm_tickets"
local TICKET_TTL_SEC = 120
local SKILL_RANGE = 200

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

local function open_key(region)
  return POOL .. "_" .. tostring(region or "any")
end

local function read_open(region)
  local objects = nk.storage_read({
    { collection = OPEN_COLLECTION, key = open_key(region), user_id = nil }
  })
  if objects == nil or #objects == 0 then
    return nil
  end
  return objects[1].value
end

local function write_open(region, value)
  nk.storage_write({
    {
      collection = OPEN_COLLECTION,
      key = open_key(region),
      user_id = nil,
      value = value,
      permission_read = 0,
      permission_write = 0
    }
  })
end

local function clear_open(region)
  nk.storage_delete({
    { collection = OPEN_COLLECTION, key = open_key(region), user_id = nil }
  })
end

local function write_ticket(ticket_id, value)
  nk.storage_write({
    {
      collection = TICKET_COLLECTION,
      key = ticket_id,
      user_id = nil,
      value = value,
      permission_read = 0,
      permission_write = 0
    }
  })
end

local function read_ticket(ticket_id)
  local objects = nk.storage_read({
    { collection = TICKET_COLLECTION, key = ticket_id, user_id = nil }
  })
  if objects == nil or #objects == 0 then
    return nil
  end
  return objects[1].value
end

local function delete_ticket(ticket_id)
  nk.storage_delete({
    { collection = TICKET_COLLECTION, key = ticket_id, user_id = nil }
  })
end

local function skill_compatible(a, b)
  return math.abs(a - b) <= SKILL_RANGE
end

local function rpc_mm_enqueue(context, payload)
  local user_id = require_user(context)
  local body = decode_payload(payload)
  local region = tostring(body.region or "any")
  local skill = as_nonneg_int(body.skill)
  local now = os.time()

  local open = read_open(region)
  if open ~= nil then
    if as_nonneg_int(open.expires_at) <= now or open.user_id == user_id then
      clear_open(region)
      open = nil
    end
  end

  if open ~= nil and skill_compatible(skill, as_nonneg_int(open.skill)) then
    local match_name = "gb_mm_" .. string.gsub(nk.uuid_v4(), "%-", "")
    local ticket_a = open.ticket_id
    local ticket_b = nk.uuid_v4()
    local matched_at = now
    write_ticket(ticket_a, {
      ticket_id = ticket_a,
      user_id = open.user_id,
      status = "matched",
      pool = POOL,
      region = region,
      skill = as_nonneg_int(open.skill),
      match_name = match_name,
      match_id = match_name,
      opponent_id = user_id,
      created_at = as_nonneg_int(open.created_at),
      matched_at = matched_at,
      expires_at = matched_at + TICKET_TTL_SEC
    })
    write_ticket(ticket_b, {
      ticket_id = ticket_b,
      user_id = user_id,
      status = "matched",
      pool = POOL,
      region = region,
      skill = skill,
      match_name = match_name,
      match_id = match_name,
      opponent_id = open.user_id,
      created_at = now,
      matched_at = matched_at,
      expires_at = matched_at + TICKET_TTL_SEC
    })
    clear_open(region)
    return nk.json_encode({
      ok = true,
      status = "matched",
      pool = POOL,
      ticket_id = ticket_b,
      match_name = match_name,
      match_id = match_name,
      opponent_id = open.user_id,
      module_version = MODULE_VERSION
    })
  end

  local ticket_id = nk.uuid_v4()
  local expires_at = now + TICKET_TTL_SEC
  write_ticket(ticket_id, {
    ticket_id = ticket_id,
    user_id = user_id,
    status = "waiting",
    pool = POOL,
    region = region,
    skill = skill,
    match_id = "",
    created_at = now,
    expires_at = expires_at
  })
  write_open(region, {
    ticket_id = ticket_id,
    user_id = user_id,
    skill = skill,
    region = region,
    created_at = now,
    expires_at = expires_at
  })

  return nk.json_encode({
    ok = true,
    status = "waiting",
    pool = POOL,
    ticket_id = ticket_id,
    match_id = "",
    expires_at = expires_at,
    module_version = MODULE_VERSION
  })
end

local function rpc_mm_status(context, payload)
  local user_id = require_user(context)
  local body = decode_payload(payload)
  local ticket_id = tostring(body.ticket_id or "")
  if ticket_id == "" then
    error("ticket_id required")
  end
  local ticket = read_ticket(ticket_id)
  if ticket == nil then
    return nk.json_encode({
      ok = false,
      error = "ticket_not_found",
      module_version = MODULE_VERSION
    })
  end
  if ticket.user_id ~= user_id then
    return nk.json_encode({
      ok = false,
      error = "forbidden",
      module_version = MODULE_VERSION
    })
  end
  local now = os.time()
  if ticket.status == "waiting" and as_nonneg_int(ticket.expires_at) <= now then
    ticket.status = "expired"
    write_ticket(ticket_id, ticket)
    local open = read_open(ticket.region)
    if open ~= nil and open.ticket_id == ticket_id then
      clear_open(ticket.region)
    end
  end
  return nk.json_encode({
    ok = true,
    status = ticket.status,
    pool = ticket.pool or POOL,
    ticket_id = ticket_id,
    match_name = ticket.match_name or ticket.match_id or "",
    match_id = ticket.match_id or ticket.match_name or "",
    opponent_id = ticket.opponent_id or "",
    expires_at = ticket.expires_at,
    module_version = MODULE_VERSION
  })
end

local function rpc_mm_cancel(context, payload)
  local user_id = require_user(context)
  local body = decode_payload(payload)
  local ticket_id = tostring(body.ticket_id or "")
  if ticket_id == "" then
    error("ticket_id required")
  end
  local ticket = read_ticket(ticket_id)
  if ticket == nil then
    return nk.json_encode({
      ok = false,
      error = "ticket_not_found",
      module_version = MODULE_VERSION
    })
  end
  if ticket.user_id ~= user_id then
    return nk.json_encode({
      ok = false,
      error = "forbidden",
      module_version = MODULE_VERSION
    })
  end
  if ticket.status == "waiting" then
    local open = read_open(ticket.region)
    if open ~= nil and open.ticket_id == ticket_id then
      clear_open(ticket.region)
    end
  end
  delete_ticket(ticket_id)
  return nk.json_encode({
    ok = true,
    cancelled = true,
    ticket_id = ticket_id,
    module_version = MODULE_VERSION
  })
end

nk.register_rpc(rpc_mm_enqueue, "mm_enqueue")
nk.register_rpc(rpc_mm_status, "mm_status")
nk.register_rpc(rpc_mm_cancel, "mm_cancel")
nk.logger_info("Goofy Balls matchmaker module loaded v" .. MODULE_VERSION)
