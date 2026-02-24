package = "kong-plugin-qp-to-logs-masks"
version = "1.0.0-1"

source = {
  url = "git://example.com/kong-plugin-qp-to-logs-masks",
  tag = "1.0.0"
}

description = {
  summary = "Kong plugin to log selected query parameters with regex masking",
  detailed = [[
Extracts configured query parameters, applies PCRE masks using ngx.re.gsub,
joins results, and injects it into Kong log serializer.
]],
  license = "Apache 2.0"
}

dependencies = { "lua >= 5.1" }

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.qp-to-logs-masks.init"]    = "kong/plugins/qp-to-logs-masks/init.lua",
    ["kong.plugins.qp-to-logs-masks.handler"] = "kong/plugins/qp-to-logs-masks/handler.lua",
    ["kong.plugins.qp-to-logs-masks.schema"]  = "kong/plugins/qp-to-logs-masks/schema.lua",
  }
}
