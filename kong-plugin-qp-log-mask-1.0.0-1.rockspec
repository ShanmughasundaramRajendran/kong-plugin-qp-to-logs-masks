package = "kong-plugin-qp-log-mask"
version = "1.0.0-1"

source = {
  url = "git://example.com/kong-plugin-qp-log-mask",
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
    ["kong.plugins.qp-log-mask.init"]    = "kong/plugins/qp-log-mask/init.lua",
    ["kong.plugins.qp-log-mask.handler"] = "kong/plugins/qp-log-mask/handler.lua",
    ["kong.plugins.qp-log-mask.schema"]  = "kong/plugins/qp-log-mask/schema.lua",
  }
}
