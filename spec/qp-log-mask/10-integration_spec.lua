local helpers = require "spec.helpers"

describe("qp-log-mask plugin integration", function()
  local client

  local function assert_proxy_status(res)
    local status = res.status
    assert.is_true(status == 200 or status == 502)
  end

  setup(function()
    local bp = helpers.get_db_utils(nil, {
      "routes",
      "services",
      "plugins",
    }, { "qp-log-mask" })

    local service = bp.services:insert({
      name = "test-service",
      url = "http://127.0.0.1:8001/status",
    })

    local route_enabled = bp.routes:insert({ service = service, paths = { "/mask" } })
    local route_no_header = bp.routes:insert({ service = service, paths = { "/mask-no-header" } })
    local route_no_masks = bp.routes:insert({ service = service, paths = { "/mask-raw" } })
    local route_plugin_disabled = bp.routes:insert({ service = service, paths = { "/mask-plugin-disabled" } })
    local route_legacy = bp.routes:insert({ service = service, paths = { "/mask-legacy" } })
    local route_invalid_pattern = bp.routes:insert({ service = service, paths = { "/mask-invalid-pattern" } })
    local route_empty_mask = bp.routes:insert({ service = service, paths = { "/mask-empty-mask" } })
    local route_custom_format = bp.routes:insert({ service = service, paths = { "/mask-custom-format" } })
    local route_empty_list = bp.routes:insert({ service = service, paths = { "/mask-empty-list" } })

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

  local function assert_no_header(res, header_name)
    assert.is_nil(res.headers[header_name])
    assert.is_nil(res.headers[string.lower(header_name)])
  end

  it("never exposes response header on standard route", function()
    local res = client:get("/mask?token=abcDEF123456&user=cognizant")
    assert_proxy_status(res)
    assert_no_header(res, "X-Kong-QP-Log")
  end)

  it("never exposes response header for multi-value params", function()
    local res = client:get("/mask?token=abcDEF123456&token=ZZZZYYYYXXXX12&user=bob")
    assert_proxy_status(res)
    assert_no_header(res, "X-Kong-QP-Log")
  end)

  it("does not add response header when configured params are absent", function()
    local res = client:get("/mask?other=1")
    assert_proxy_status(res)
    assert_no_header(res, "X-Kong-QP-Log")
  end)

  it("does not add response header when add_response_header is false", function()
    local res = client:get("/mask-no-header?token=abcDEF123456&user=cognizant")
    assert_proxy_status(res)
    assert_no_header(res, "X-Kong-QP-Log")
  end)

  it("never emits custom response header even when configured", function()
    local res = client:get("/mask-raw?token=abcDEF123456")
    assert_proxy_status(res)
    assert_no_header(res, "X-Kong-QP-Raw")
  end)

  it("does not append empty query param values to response headers", function()
    local res = client:get("/mask?token=&user=cognizant")
    assert_proxy_status(res)
    assert_no_header(res, "X-Kong-QP-Log")
  end)

  it("does nothing when plugin is disabled", function()
    local res = client:get("/mask-plugin-disabled?token=abcDEF123456&user=cognizant")
    assert_proxy_status(res)
    assert_no_header(res, "X-Kong-QP-Log-Disabled")
  end)

  it("never emits response header for legacy config", function()
    local res = client:get("/mask-legacy?token=abcDEF123456&user=cognizant")
    assert_proxy_status(res)
    assert_no_header(res, "X-Kong-QP-Log-Legacy")
  end)

  it("never emits response header when regex is invalid", function()
    local res = client:get("/mask-invalid-pattern?token=abcDEF123456")
    assert_proxy_status(res)
    assert_no_header(res, "X-Kong-QP-Log-Invalid-Pattern")
  end)

  it("never emits response header when mask field is omitted", function()
    local res = client:get("/mask-empty-mask?token=abcxyz123def")
    assert_proxy_status(res)
    assert_no_header(res, "X-Kong-QP-Log-Empty-Mask")
  end)

  it("never emits custom separator response header", function()
    local res = client:get("/mask-custom-format?token=abcDEF123456&user=cognizant")
    assert_proxy_status(res)
    assert_no_header(res, "X-Kong-QP-Log-Custom")
  end)

  it("does nothing when query_params_to_log is empty", function()
    local res = client:get("/mask-empty-list?token=abcDEF123456&user=cognizant")
    assert_proxy_status(res)
    assert_no_header(res, "X-Kong-QP-Log-Empty-List")
  end)
end)
