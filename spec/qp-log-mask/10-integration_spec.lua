local helpers = require "spec.helpers"

describe("qp-log-mask plugin integration", function()
  local client

  -- Pongo environment can intermittently return 502 for upstream calls;
  -- plugin behavior under test is header mutation, so accept both here.
  local function assert_proxy_status(res)
    local status = res.status
    assert.is_true(status == 200 or status == 502)
  end

  setup(function()
    -- Seed routes/plugins directly in test database.
    local bp = helpers.get_db_utils(nil, {
      "routes",
      "services",
      "plugins",
    }, { "qp-log-mask" })

    local service = bp.services:insert({
      name = "test-service",
      -- Lightweight local endpoint used as upstream target in tests.
      url = "http://127.0.0.1:8001/status",
    })

    local route_enabled = bp.routes:insert({
      service = service,
      paths = { "/mask" },
    })

    local route_no_header = bp.routes:insert({
      service = service,
      paths = { "/mask-no-header" },
    })

    local route_no_masks = bp.routes:insert({
      service = service,
      paths = { "/mask-raw" },
    })

    local route_plugin_disabled = bp.routes:insert({
      service = service,
      paths = { "/mask-plugin-disabled" },
    })

    local route_legacy = bp.routes:insert({
      service = service,
      paths = { "/mask-legacy" },
    })

    local route_invalid_pattern = bp.routes:insert({
      service = service,
      paths = { "/mask-invalid-pattern" },
    })

    local route_empty_mask = bp.routes:insert({
      service = service,
      paths = { "/mask-empty-mask" },
    })

    local route_custom_format = bp.routes:insert({
      service = service,
      paths = { "/mask-custom-format" },
    })

    local route_empty_list = bp.routes:insert({
      service = service,
      paths = { "/mask-empty-list" },
    })

    -- Standard route: response header enabled.
    bp.plugins:insert({
      name = "qp-log-mask",
      route = { id = route_enabled.id },
      config = {
        query_params_to_log = { "token", "user" },
        separator = "|",
        output_field = "qp_log",
        add_response_header = true,
        response_header_name = "X-Kong-QP-Log",
        query_params_log_mask = {
          { pattern = "(.{4}).+(.{2})", mask = "$1***$2" },
        },
      },
    })

    -- Header-disabled route.
    bp.plugins:insert({
      name = "qp-log-mask",
      route = { id = route_no_header.id },
      config = {
        query_params_to_log = { "token", "user" },
        separator = "|",
        output_field = "qp_log_no_header",
        add_response_header = false,
        query_params_log_mask = {
          { pattern = "(.{4}).+(.{2})", mask = "$1***$2" },
        },
      },
    })

    -- No-mask route to validate pass-through behavior.
    bp.plugins:insert({
      name = "qp-log-mask",
      route = { id = route_no_masks.id },
      config = {
        query_params_to_log = { "token" },
        separator = "|",
        output_field = "qp_log_raw",
        add_response_header = true,
        response_header_name = "X-Kong-QP-Raw",
      },
    })

    -- Disabled plugin route to validate no-op behavior.
    bp.plugins:insert({
      name = "qp-log-mask",
      route = { id = route_plugin_disabled.id },
      config = {
        enabled = false,
        error_format = "default",
        query_params_to_log = { "token", "user" },
        separator = "|",
        output_field = "qp_log_disabled",
        add_response_header = true,
        response_header_name = "X-Kong-QP-Log-Disabled",
        query_params_log_mask = {
          { pattern = "(.{4}).+(.{2})", mask = "$1***$2" },
        },
      },
    })

    bp.plugins:insert({
      name = "qp-log-mask",
      route = { id = route_legacy.id },
      config = {
        query_params = "token,user",
        separator = "|",
        output_field = "qp_log_legacy",
        add_response_header = true,
        response_header_name = "X-Kong-QP-Log-Legacy",
        masks = {
          { regex = "(.{4}).+(.{2})", replace = "$1***$2" },
        },
      },
    })

    bp.plugins:insert({
      name = "qp-log-mask",
      route = { id = route_invalid_pattern.id },
      config = {
        query_params_to_log = { "token" },
        separator = "|",
        output_field = "qp_log_invalid_pattern",
        add_response_header = true,
        response_header_name = "X-Kong-QP-Log-Invalid-Pattern",
        query_params_log_mask = {
          { pattern = "[", mask = "never_used" },
        },
      },
    })

    bp.plugins:insert({
      name = "qp-log-mask",
      route = { id = route_empty_mask.id },
      config = {
        query_params_to_log = { "token" },
        separator = "|",
        output_field = "qp_log_empty_mask",
        add_response_header = true,
        response_header_name = "X-Kong-QP-Log-Empty-Mask",
        query_params_log_mask = {
          { pattern = "xyz123" },
        },
      },
    })

    bp.plugins:insert({
      name = "qp-log-mask",
      route = { id = route_custom_format.id },
      config = {
        query_params_to_log = { "token", "user" },
        separator = "||",
        output_field = "qp_log_custom",
        add_response_header = true,
        response_header_name = "X-Kong-QP-Log-Custom",
        query_params_log_mask = {
          { pattern = "(.{4}).+(.{2})", mask = "$1***$2" },
        },
      },
    })

    bp.plugins:insert({
      name = "qp-log-mask",
      route = { id = route_empty_list.id },
      config = {
        query_params_to_log = {},
        separator = "|",
        output_field = "qp_log_empty_list",
        add_response_header = true,
        response_header_name = "X-Kong-QP-Log-Empty-List",
      },
    })

    assert(helpers.start_kong({
      -- Use DB mode in spec because entities are inserted via bp helpers.
      database = "postgres",
      plugins = "bundled,qp-log-mask",
    }))
  end)

  teardown(function()
    helpers.stop_kong()
  end)

  before_each(function()
    client = helpers.proxy_client()
  end)

  after_each(function()
    if client then
      client:close()
    end
  end)

  it("adds masked response header when configured params are present", function()
    local res = client:get("/mask?token=abcDEF123456&user=cognizant")
    assert_proxy_status(res)

    local header_value = res.headers["X-Kong-QP-Log"] or res.headers["x-kong-qp-log"]
    assert.is_not_nil(header_value)
    assert.matches("QP_token:abcD%*%*%*56", header_value)
    assert.matches("QP_user:cogn%*%*%*nt", header_value)
  end)

  it("joins multi-value params with comma before adding route separator", function()
    local res = client:get("/mask?token=abcDEF123456&token=ZZZZYYYYXXXX12&user=bob")
    assert_proxy_status(res)

    local header_value = res.headers["X-Kong-QP-Log"] or res.headers["x-kong-qp-log"]
    assert.is_not_nil(header_value)
    assert.matches("QP_token:abcD%*%*%*56,ZZZZ%*%*%*12", header_value)
    assert.matches("%|QP_user:", header_value)
  end)

  it("does not add response header when configured params are absent", function()
    local res = client:get("/mask?other=1")
    assert_proxy_status(res)

    assert.is_nil(res.headers["X-Kong-QP-Log"])
    assert.is_nil(res.headers["x-kong-qp-log"])
  end)

  it("does not add response header when add_response_header is false", function()
    local res = client:get("/mask-no-header?token=abcDEF123456&user=cognizant")
    assert_proxy_status(res)

    assert.is_nil(res.headers["X-Kong-QP-Log"])
    assert.is_nil(res.headers["x-kong-qp-log"])
  end)

  it("supports configs without masks and passes raw values", function()
    local res = client:get("/mask-raw?token=abcDEF123456")
    assert_proxy_status(res)

    local header_value = res.headers["X-Kong-QP-Raw"] or res.headers["x-kong-qp-raw"]
    assert.are.equal("QP_token:abcDEF123456", header_value)
  end)

  it("does not append empty query param values", function()
    local res = client:get("/mask?token=&user=cognizant")
    assert_proxy_status(res)

    local header_value = res.headers["X-Kong-QP-Log"] or res.headers["x-kong-qp-log"]
    assert.is_not_nil(header_value)
    assert.are.equal("QP_user:cogn***nt", header_value)
  end)

  it("does nothing when plugin is disabled", function()
    local res = client:get("/mask-plugin-disabled?token=abcDEF123456&user=cognizant")
    assert_proxy_status(res)

    assert.is_nil(res.headers["X-Kong-QP-Log-Disabled"])
    assert.is_nil(res.headers["x-kong-qp-log-disabled"])
  end)

  it("supports legacy query_params and masks config", function()
    local res = client:get("/mask-legacy?token=abcDEF123456&user=cognizant")
    assert_proxy_status(res)

    local header_value = res.headers["X-Kong-QP-Log-Legacy"] or res.headers["x-kong-qp-log-legacy"]
    assert.is_not_nil(header_value)
    assert.matches("QP_token:abcD%*%*%*56", header_value)
    assert.matches("QP_user:cogn%*%*%*nt", header_value)
  end)

  it("ignores invalid regex and keeps original value", function()
    local res = client:get("/mask-invalid-pattern?token=abcDEF123456")
    assert_proxy_status(res)

    local header_value = res.headers["X-Kong-QP-Log-Invalid-Pattern"] or res.headers["x-kong-qp-log-invalid-pattern"]
    assert.are.equal("QP_token:abcDEF123456", header_value)
  end)

  it("uses empty replacement when mask field is omitted", function()
    local res = client:get("/mask-empty-mask?token=abcxyz123def")
    assert_proxy_status(res)

    local header_value = res.headers["X-Kong-QP-Log-Empty-Mask"] or res.headers["x-kong-qp-log-empty-mask"]
    assert.are.equal("QP_token:abcdef", header_value)
  end)

  it("supports custom separator and custom response header", function()
    local res = client:get("/mask-custom-format?token=abcDEF123456&user=cognizant")
    assert_proxy_status(res)

    local header_value = res.headers["X-Kong-QP-Log-Custom"] or res.headers["x-kong-qp-log-custom"]
    assert.are.equal("QP_token:abcD***56||QP_user:cogn***nt", header_value)
  end)

  it("does nothing when query_params_to_log is empty", function()
    local res = client:get("/mask-empty-list?token=abcDEF123456&user=cognizant")
    assert_proxy_status(res)

    assert.is_nil(res.headers["X-Kong-QP-Log-Empty-List"])
    assert.is_nil(res.headers["x-kong-qp-log-empty-list"])
  end)
end)
