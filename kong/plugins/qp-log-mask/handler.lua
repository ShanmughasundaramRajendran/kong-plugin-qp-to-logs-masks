local QPToLogsMasks = {
  -- Run before most logging plugins so masked data is ready in ctx/header.
  PRIORITY = 850,
  VERSION = "1.0.0",
}

-- Phase map for this plugin:
-- 1) access phase: collect/mask query params and cache masked value in ctx.
-- 2) log phase: write final masked value to Kong log serializer field.
-- This plugin does not implement rewrite, header_filter, body_filter, or response phases.

local ngx_re_gsub = ngx.re.gsub
local tostring = tostring
local table_concat = table.concat
local table_insert = table.insert
local type = type

local function split_csv(s)
  if not s or s == "" then
    return {}
  end
  local out = {}
  for part in s:gmatch("([^,]+)") do
    part = part:gsub("^%s+", ""):gsub("%s+$", "")
    if part ~= "" then
      out[#out + 1] = part
    end
  end
  return out
end

local function normalize_value(value)
  if value == nil then
    return nil
  end

  local v = tostring(value)
  if v == "" then
    return nil
  end

  return v
end

local function normalize_masks(conf)
  -- Preferred config key (new contract).
  if conf.query_params_log_mask and #conf.query_params_log_mask > 0 then
    return conf.query_params_log_mask
  end

  -- Backward compatibility for legacy { regex, replace } format.
  if conf.masks and #conf.masks > 0 then
    local out = {}
    for _, legacy in ipairs(conf.masks) do
      if legacy.regex then
        out[#out + 1] = {
          pattern = legacy.regex,
          mask = legacy.replace or "",
        }
      end
    end
    return out
  end

  return {}
end

local function normalize_query_params(conf)
  -- Preferred config key (new contract).
  if conf.query_params_to_log and #conf.query_params_to_log > 0 then
    return conf.query_params_to_log
  end

  -- Backward compatibility for legacy CSV field.
  if conf.query_params and conf.query_params ~= "" then
    return split_csv(conf.query_params)
  end

  return {}
end

local function apply_masks(value, masks)
  local v = normalize_value(value)
  if not v then
    return nil
  end

  -- Apply rules in order so later masks can transform earlier output.
  for _, m in ipairs(masks) do
    local pattern = m.pattern or m.regex
    if pattern then
      local replacement = m.mask
      if replacement == nil then
        replacement = m.replace or ""
      end

      local ok, res = pcall(ngx_re_gsub, v, pattern, replacement, "jo")
      if ok and res then
        v = res
      end
    end
  end

  return v
end

local function collect_values(value, masks)
  if type(value) == "table" then
    local masked_values = {}
    for i = 1, #value do
      local masked = apply_masks(value[i], masks)
      if masked then
        table_insert(masked_values, masked)
      end
    end
    return masked_values
  end

  local masked = apply_masks(value, masks)
  if masked then
    return { masked }
  end

  return {}
end

function QPToLogsMasks:access(conf)
  -- ACCESS PHASE:
  -- Build the final "QP_<key>:<value>" payload from request query params.
  -- Store it in kong.ctx.plugin for later use in log phase.

  -- Explicit hard stop when plugin is disabled in config.
  if conf.enabled == false then
    return
  end

  -- Nothing to process when no query keys are configured.
  local query_params_to_log = normalize_query_params(conf)
  if #query_params_to_log == 0 then
    return
  end

  local query_params_log_mask = normalize_masks(conf)
  local args = kong.request.get_query()
  if type(args) ~= "table" then
    return
  end

  local qp_log = {}

  for _, key in ipairs(query_params_to_log) do
    local values = collect_values(args[key], query_params_log_mask)
    if #values > 0 then
      -- Access-log token format expected by consumers.
      qp_log[#qp_log + 1] = "QP_" .. key .. ":" .. table_concat(values, ",")
    end
  end

  if #qp_log == 0 then
    return
  end

  local final = table_concat(qp_log, conf.separator or "|")
  -- Keep final value in request context for use during log phase.
  kong.ctx.plugin.qp_log_masks_value = final
end

function QPToLogsMasks:log(conf)
  -- LOG PHASE:
  -- Read the prepared value from kong.ctx.plugin and inject it into
  -- structured log output under config.output_field.

  -- Skip serializer mutation when plugin is disabled.
  if conf.enabled == false then
    return
  end

  local value = kong.ctx.plugin.qp_log_masks_value
  if value then
    -- Write computed value into structured log payload.
    kong.log.set_serialize_value(conf.output_field, value)
  end
end

return QPToLogsMasks
