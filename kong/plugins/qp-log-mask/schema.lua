-- kong/plugins/qp-log-mask/schema.lua
local typedefs = require "kong.db.schema.typedefs"

return {
  name = "qp-log-mask",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          -- Global enable switch: when false plugin is a no-op.
          { enabled = { type = "boolean", required = true, default = true } },

          -- Ordered list of query keys to collect into the log token.
          { query_params_to_log = {
              type = "array",
              required = false,
              default = {},
              elements = {
                type = "string",
                len_min = 1,
                len_max = 200,
              },
            }
          },

          -- Ordered list of mask rules applied on each built QP_<key>:<value> entry.
          { query_params_log_mask = {
              type = "array",
              required = false,
              default = {},
              elements = {
                type = "record",
                fields = {
                  { pattern = { type = "string", required = true, len_min = 1, len_max = 1024 } },
                  -- Optional replacement text; empty replacement is allowed by omission.
                  { mask = { type = "string", required = false } },
                },
              },
            }
          },

          -- Delimiter used while joining multiple QP entries.
          { separator = { type = "string", required = true, default = "|" } },
          -- Serializer field name used in log phase.
          { output_field = { type = "string", required = true, default = "qp_log" } },
        },
      }
    },
  },
}
