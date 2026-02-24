local helpers = require "spec.helpers"

describe("qp-to-logs-masks plugin", function()
  local client

  setup(function()
    local bp = helpers.get_db_utils(nil, {
      "routes",
      "services",
      "plugins",
    }, { "qp-to-logs-masks" })

    local service = bp.services:insert({
      name = "test-service",
      url = helpers.mock_upstream_url,
    })

    local route_enabled = bp.routes:insert({
      service = service,
      paths = { "/mask-enabled" },
    })

    local route_no_header = bp.routes:insert({
      service = service,
      paths = { "/mask-disabled" },
    })

    local route_no_masks = bp.routes:insert({
      service = service,
      paths = { "/mask-raw" },
    })

    bp.plugins:insert({
      name = "qp-to-logs-masks",
      route = { id = route_enabled.id },
      config = {
        query_params = "token,user",
        separator = "|",
        output_field = "qp_log",
        add_response_header = true,
        response_header_name = "X-Kong-QP-Log",
        masks = {
          { regex = "(.{4}).+(.{2})", replace = "$1***$2" },
        },
      },
    })

    bp.plugins:insert({
      name = "qp-to-logs-masks",
      route = { id = route_no_header.id },
      config = {
        query_params = "token,user",
        separator = "|",
        output_field = "qp_log_no_header",
        add_response_header = false,
        masks = {
          { regex = "(.{4}).+(.{2})", replace = "$1***$2" },
        },
      },
    })

    bp.plugins:insert({
      name = "qp-to-logs-masks",
      route = { id = route_no_masks.id },
      config = {
        query_params = "token",
        separator = "|",
        output_field = "qp_log_raw",
        add_response_header = true,
        response_header_name = "X-Kong-QP-Raw",
      },
    })

    assert(helpers.start_kong({
      database = "off",
      plugins = "bundled,qp-to-logs-masks",
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
    local res = client:get("/mask-enabled?token=abcDEF123456&user=cognizant")
    assert.response(res).has.status(200)

    local header_value = res.headers["X-Kong-QP-Log"] or res.headers["x-kong-qp-log"]
    assert.is_not_nil(header_value)
    assert.matches("QP%-token:abcD%*%*%*56", header_value)
    assert.matches("QP%-user:cogn%*%*%*nt", header_value)
  end)

  it("joins multi-value params with comma before adding route separator", function()
    local res = client:get("/mask-enabled?token=abcDEF123456&token=ZZZZYYYYXXXX12&user=bob")
    assert.response(res).has.status(200)

    local header_value = res.headers["X-Kong-QP-Log"] or res.headers["x-kong-qp-log"]
    assert.is_not_nil(header_value)
    assert.matches("QP%-token:abcD%*%*%*56,ZZZZ%*%*%*12", header_value)
    assert.matches("%|QP%-user:", header_value)
  end)

  it("does not add response header when configured params are absent", function()
    local res = client:get("/mask-enabled?other=1")
    assert.response(res).has.status(200)

    assert.is_nil(res.headers["X-Kong-QP-Log"])
    assert.is_nil(res.headers["x-kong-qp-log"])
  end)

  it("does not add response header when add_response_header is false", function()
    local res = client:get("/mask-disabled?token=abcDEF123456&user=cognizant")
    assert.response(res).has.status(200)

    assert.is_nil(res.headers["X-Kong-QP-Log"])
    assert.is_nil(res.headers["x-kong-qp-log"])
  end)

  it("supports configs without masks and passes raw values", function()
    local res = client:get("/mask-raw?token=abcDEF123456")
    assert.response(res).has.status(200)

    local header_value = res.headers["X-Kong-QP-Raw"] or res.headers["x-kong-qp-raw"]
    assert.are.equal("QP-token:abcDEF123456", header_value)
  end)
end)
