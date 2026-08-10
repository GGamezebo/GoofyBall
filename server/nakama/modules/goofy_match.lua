--[[
  Goofy Balls — Phase 4 stub authoritative match (relay later).
  Created via nk.match_create("goofy_match", setupstate).
]]

local nk = require("nakama")

local M = {}

local function count_presences(presences)
  local n = 0
  for _ in pairs(presences) do
    n = n + 1
  end
  return n
end

local function build_label(state)
  return nk.json_encode({
    mode = state.mode or "friend_room",
    code = state.code or "",
    region = state.region or "any",
    skill = state.skill or 0,
    open = (count_presences(state.presences) < (state.max_size or 2)) and 1 or 0,
    host_id = state.host_id or ""
  })
end

function M.match_init(context, setupstate)
  local setup = setupstate or {}
  local gamestate = {
    presences = {},
    mode = tostring(setup.mode or "friend_room"),
    code = tostring(setup.code or ""),
    region = tostring(setup.region or "any"),
    skill = tonumber(setup.skill) or 0,
    host_id = tostring(setup.host_id or ""),
    max_size = tonumber(setup.max_size) or 2,
    created_at = os.time()
  }
  local tickrate = 1
  local label = build_label(gamestate)
  return gamestate, tickrate, label
end

function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  if count_presences(state.presences) >= (state.max_size or 2) then
    return state, false
  end
  return state, true
end

function M.match_join(context, dispatcher, tick, state, presences)
  for _, presence in ipairs(presences) do
    state.presences[presence.session_id] = presence
  end
  return state
end

function M.match_leave(context, dispatcher, tick, state, presences)
  for _, presence in ipairs(presences) do
    state.presences[presence.session_id] = nil
  end
  if count_presences(state.presences) == 0 then
    return nil
  end
  return state
end

function M.match_loop(context, dispatcher, tick, state, messages)
  for _, m in ipairs(messages) do
    -- Relay stub: echo payload to all (bridge wiring later).
    dispatcher.broadcast_message(1, m.data)
  end
  return state
end

function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
  return nil
end

function M.match_signal(context, dispatcher, tick, state, data)
  return state, data
end

return M
