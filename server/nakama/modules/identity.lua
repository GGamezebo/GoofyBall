--[[
  Goofy Balls — Phase 1 identity runtime (Lua).
  RPCs: health_ext, get_account_view, link_status
  Yandex: custom auth hooks (yandex_<playerId>, YANDEX_AUTH_MODE=dev|prod)
]]

local nk = require("nakama")

local MODULE_VERSION = "1.0.0"
local YANDEX_PREFIX = "yandex_"

local function get_env(context, key, fallback)
  if context ~= nil and context.env ~= nil and context.env[key] ~= nil and context.env[key] ~= "" then
    return context.env[key]
  end
  return fallback
end

local function is_yandex_id(id)
  return type(id) == "string" and string.sub(id, 1, #YANDEX_PREFIX) == YANDEX_PREFIX
end

local function normalize_yandex_player_id(raw)
  local id = tostring(raw or "")
  if is_yandex_id(id) then
    id = string.sub(id, #YANDEX_PREFIX + 1)
  end
  id = string.gsub(id, "[^%w_%-]", "")
  return id
end

local function build_account_view(user_id)
  local account = nk.account_get_id(user_id)
  local user = account.user or {}
  local custom_id = account.custom_id or ""
  local devices = account.devices or {}
  local google_id = user.google_id or ""
  local steam_id = user.steam_id or ""
  return {
    user_id = user_id,
    username = user.username or "",
    display_name = user.display_name or "",
    providers = {
      device = (#devices > 0),
      device_count = #devices,
      google = (google_id ~= ""),
      steam = (steam_id ~= ""),
      yandex = is_yandex_id(custom_id),
      custom_id = custom_id
    },
    module_version = MODULE_VERSION
  }
end

local function rpc_health_ext(context, payload)
  return nk.json_encode({
    ok = true,
    module = "identity",
    version = MODULE_VERSION,
    ts = os.time() * 1000
  })
end

local function rpc_get_account_view(context, payload)
  if context.user_id == nil or context.user_id == "" then
    error("Auth required")
  end
  return nk.json_encode(build_account_view(context.user_id))
end

local function rpc_link_status(context, payload)
  if context.user_id == nil or context.user_id == "" then
    error("Auth required")
  end
  local view = build_account_view(context.user_id)
  return nk.json_encode({
    user_id = view.user_id,
    providers = view.providers,
    can_link = { "google", "steam", "yandex", "device" }
  })
end

local function validate_yandex_custom(context, data, kind)
  local account = data.account or {}
  local raw_id = account.id or ""
  if raw_id == "" then
    error("custom id required")
  end
  if not is_yandex_id(raw_id) then
    error("unsupported custom auth provider (expected yandex_*)")
  end
  local player_id = normalize_yandex_player_id(raw_id)
  if #player_id < 4 then
    error("invalid yandex player id")
  end

  local mode = get_env(context, "YANDEX_AUTH_MODE", "dev")
  if mode == "prod" then
    local secret = get_env(context, "YANDEX_GAMES_SECRET", "")
    if secret == "" then
      error("YANDEX_GAMES_SECRET not configured")
    end
    local vars = account.vars or {}
    local signature = vars.yandex_signature or vars.yandexSignature or ""
    if signature == "" then
      error("yandex_signature required in account.vars for prod")
    end
    nk.logger_warn("yandex " .. kind .. " rejected (prod verify placeholder) id=" .. player_id)
    error("yandex prod verification not enabled; set YANDEX_AUTH_MODE=dev for local")
  else
    nk.logger_debug("yandex " .. kind .. " accepted in dev mode id=" .. player_id)
  end

  account.id = YANDEX_PREFIX .. player_id
  data.account = account
  if data.username == nil or data.username == "" then
    data.username = "yg_" .. string.sub(player_id, 1, 12)
  end
  return data
end

local function before_authenticate_custom(context, data)
  return validate_yandex_custom(context, data, "authenticate")
end

local function before_link_custom(context, data)
  return validate_yandex_custom(context, data, "link")
end

nk.register_rpc(rpc_health_ext, "health_ext")
nk.register_rpc(rpc_get_account_view, "get_account_view")
nk.register_rpc(rpc_link_status, "link_status")
nk.register_req_before(before_authenticate_custom, "AuthenticateCustom")
nk.register_req_before(before_link_custom, "LinkCustom")
nk.logger_info("Goofy Balls identity module loaded v" .. MODULE_VERSION)
