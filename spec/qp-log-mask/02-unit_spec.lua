local function load_handler_with_stubs(stubs)
  _G.ngx = {
    re = {
      gsub = stubs.ngx_re_gsub or function(value, pattern, replacement)
        return (value:gsub(pattern, replacement))
      end,
    },
  }

  _G.kong = stubs.kong

  package.loaded["kong.plugins.qp-log-mask.handler"] = nil
  return require "kong.plugins.qp-log-mask.handler"
end

describe("qp-log-mask handler unit", function()
  local captured_log_field
  local captured_log_value
  local query_args

  local function build_kong_stub()
    captured_log_field = nil
    captured_log_value = nil
    query_args = {}

    return {
      request = {
        get_query = function()
          return query_args
        end,
      },
      log = {
        set_serialize_value = function(field, value)
          captured_log_field = field
          captured_log_value = value
        end,
      },
      ctx = {
        plugin = {},
      },
    }
  end

  it("builds masked value in access phase and writes it in log phase", function()
    local kong_stub = build_kong_stub()
    local handler = load_handler_with_stubs({
      kong = kong_stub,
    })

    query_args = {
      token = "abcxyz123def",
      user = "bob",
    }

    local conf = {
      enabled = true,
      query_params_to_log = { "token", "user" },
      query_params_log_mask = {
        { pattern = "xyz123", mask = "***" },
      },
      separator = "|",
      output_field = "qp_log",
    }

    handler:access(conf)
    assert.are.equal("QP_token:abc***def|QP_user:bob", kong_stub.ctx.plugin.qp_log_masks_value)

    handler:log(conf)
    assert.are.equal("qp_log", captured_log_field)
    assert.are.equal("QP_token:abc***def|QP_user:bob", captured_log_value)
  end)

  it("does nothing when plugin is disabled", function()
    local kong_stub = build_kong_stub()
    local handler = load_handler_with_stubs({
      kong = kong_stub,
    })

    query_args = {
      token = "abcxyz123def",
    }

    local conf = {
      enabled = false,
      query_params_to_log = { "token" },
      query_params_log_mask = {},
      separator = "|",
      output_field = "qp_log",
    }

    handler:access(conf)
    handler:log(conf)

    assert.is_nil(captured_log_field)
    assert.is_nil(captured_log_value)
  end)

  it("applies multiple mask rules in configured order", function()
    local kong_stub = build_kong_stub()
    local handler = load_handler_with_stubs({
      kong = kong_stub,
    })

    query_args = {
      token = "abcxyz123def",
    }

    local conf = {
      query_params_to_log = { "token" },
      query_params_log_mask = {
        { pattern = "xyz123", mask = "ZZZ" },
        { pattern = "ZZZ", mask = "***" },
      },
      separator = "|",
      output_field = "qp_log",
    }

    handler:access(conf)

    assert.are.equal("QP_token:abc***def", kong_stub.ctx.plugin.qp_log_masks_value)
  end)

  it("raises error for invalid regex pattern", function()
    local kong_stub = build_kong_stub()
    local handler = load_handler_with_stubs({
      kong = kong_stub,
    })

    query_args = {
      token = "abcxyz123def",
    }

    local conf = {
      query_params_to_log = { "token" },
      query_params_log_mask = {
        { pattern = "[", mask = "X" },
      },
      separator = "|",
      output_field = "qp_log",
    }

    assert.has_error(function()
      handler:access(conf)
    end)
  end)
end)
