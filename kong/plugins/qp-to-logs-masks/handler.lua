-- kong/plugins/qp-to-logs-masks/handler.lua
local QPToLogsMasks = {
  PRIORITY = 850,
  VERSION = "1.0.0",
}

local ngx_re_gsub = ngx.re.gsub
local tostring = tostring
local table_concat = table.concat
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

local function apply_masks(value, masks)
  if value == nil then
    return nil
  end

  local v = tostring(value)
  if not masks or #masks == 0 then
    return v
  end

  for _, m in ipairs(masks) do
    local ok, res = pcall(ngx_re_gsub, v, m.regex, m.replace, "jo")
    if ok and res then
      v = res
    end
  end

  return v
end

function QPToLogsMasks:access(conf)
  if not conf.query_params_list then
    conf.query_params_list = split_csv(conf.query_params)
  end

  local args = kong.request.get_query()
  if type(args) ~= "table" then
    return
  end

  local pieces = {}

  for _, key in ipairs(conf.query_params_list) do
    local val = args[key]
    if val ~= nil then
      if type(val) == "table" then
        local masked_vals = {}
        for i = 1, #val do
          masked_vals[i] = apply_masks(val[i], conf.masks)
        end
        pieces[#pieces + 1] = "QP-" .. key .. ":" .. table_concat(masked_vals, ",")
      else
        pieces[#pieces + 1] = "QP-" .. key .. ":" .. apply_masks(val, conf.masks)
      end
    end
  end

  if #pieces == 0 then
    return
  end

  local final = table_concat(pieces, conf.separator)

  kong.log.set_serialize_value(conf.output_field, final)

  if conf.add_response_header then
    kong.response.set_header(conf.response_header_name, final)
  end
end

return QPToLogsMasks
