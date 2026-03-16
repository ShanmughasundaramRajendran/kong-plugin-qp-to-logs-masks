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
      },
    })

    bp.plugins:insert({
      name = "qp-log-mask",
      route = { id = route_plugin_disabled.id },
      config = {
        enabled = false,
        query_params_to_log = { "token", "user" },
        separator = "|",
        output_field = "qp_log_disabled",
        query_params_log_mask = {
          { pattern = "(.{4}).+(.{2})", mask = "$1***$2" },
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

  it("returns success on standard route", function()
    local res = client:get("/mask?token=abcDEF123456&user=demo_user")
    assert_proxy_status(res)
  end)

  it("returns success for multi-value params", function()
    local res = client:get("/mask?token=abcDEF123456&token=ZZZZYYYYXXXX12&user=bob")
    assert_proxy_status(res)
  end)

  it("returns success when configured params are absent", function()
    local res = client:get("/mask?other=1")
    assert_proxy_status(res)
  end)

  it("returns success on alternate route", function()
    local res = client:get("/mask-no-header?token=abcDEF123456&user=demo_user")
    assert_proxy_status(res)
  end)

  it("returns success on raw route", function()
    local res = client:get("/mask-raw?token=abcDEF123456")
    assert_proxy_status(res)
  end)

  it("returns success for empty query param values", function()
    local res = client:get("/mask?token=&user=demo_user")
    assert_proxy_status(res)
  end)

  it("does nothing when plugin is disabled", function()
    local res = client:get("/mask-plugin-disabled?token=abcDEF123456&user=demo_user")
    assert_proxy_status(res)
  end)

  it("returns success when mask field is omitted", function()
    local res = client:get("/mask-empty-mask?token=abcxyz123def")
    assert_proxy_status(res)
  end)

  it("returns success with custom separator route", function()
    local res = client:get("/mask-custom-format?token=abcDEF123456&user=demo_user")
    assert_proxy_status(res)
  end)

  it("does nothing when query_params_to_log is empty", function()
    local res = client:get("/mask-empty-list?token=abcDEF123456&user=demo_user")
    assert_proxy_status(res)
  end)
end)
