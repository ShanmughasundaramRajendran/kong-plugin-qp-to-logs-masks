-- kong/plugins/qp-to-logs-masks/schema.lua
local typedefs = require "kong.db.schema.typedefs"

return {
  name = "qp-to-logs-masks",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { query_params = { type = "string", required = true, default = "token" } },
          { separator = { type = "string", required = true, default = "|" } },
          { output_field = { type = "string", required = true, default = "qp_log" } },

          { masks = {
              type = "array",
              required = false,
              elements = {
                type = "record",
                fields = {
                  { regex = { type = "string", required = true } },
                  { replace = { type = "string", required = true } },
                },
              },
              default = {},
            }
          },

          { add_response_header = { type = "boolean", required = true, default = false } },
          { response_header_name = { type = "string", required = true, default = "X-Kong-QP-Log" } },
        },
        entity_checks = {
          { conditional = {
              if_field = "add_response_header",
              if_match = { eq = true },
              then_field = "response_header_name",
              then_match = { required = true },
            }
          },
        },
      }
    },
  },
}
