describe("qp-log-mask schema", function()
  local bp
  local service
  local route_idx = 0

  local function insert_plugin(config)
    route_idx = route_idx + 1
    local route = bp.routes:insert({
      service = service,
      paths = { "/schema-test-" .. route_idx },
    })

    return bp.plugins:insert({
      name = "qp-log-mask",
      route = { id = route.id },
      config = config,
    })
  end

  setup(function()
    local helpers = require "spec.helpers"
    bp = helpers.get_db_utils(nil, {
      "routes",
      "services",
      "plugins",
    }, { "qp-log-mask" })

    service = bp.services:insert({
      name = "schema-test-service",
      url = "http://127.0.0.1:8001/status",
    })
  end)

  it("accepts default config", function()
    assert.has_no.errors(function()
      insert_plugin({})
    end)
  end)

  it("accepts query_params_log_mask entry without mask", function()
    assert.has_no.errors(function()
      insert_plugin({
        query_params_to_log = { "token" },
        query_params_log_mask = {
          { pattern = "xyz123" },
        },
      })
    end)
  end)

  it("rejects query_params_to_log entries that are not strings", function()
    assert.has_error(function()
      insert_plugin({
        query_params_to_log = { 123 },
      })
    end)
  end)

  it("rejects mask rule when pattern is missing", function()
    assert.has_error(function()
      insert_plugin({
        query_params_to_log = { "token" },
        query_params_log_mask = {
          { mask = "***" },
        },
      })
    end)
  end)

  it("rejects removed legacy query_params + masks keys", function()
    assert.has_error(function()
      insert_plugin({
        query_params = "token,user",
        masks = {
          { regex = "xyz123", replace = "mask_value" },
        },
      })
    end)
  end)
end)
