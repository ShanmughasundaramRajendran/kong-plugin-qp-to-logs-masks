"use strict";

const assert = require("assert");

const BASE_URL = process.env.BASE_URL || "http://localhost:8000";
const ADMIN_URL = process.env.ADMIN_URL || "http://localhost:8001";
const APIKEY_C1 = process.env.APIKEY_C1 || "demo-consumer-apikey";

async function getJson(url, headers) {
  const response = await fetch(url, {
    method: "GET",
    headers,
  });

  const body = await response.json();
  return { response, body };
}

function assertNoHeaders(response, headerNames) {
  for (const headerName of headerNames) {
    assert.strictEqual(response.headers.get(headerName.toLowerCase()), null);
  }
}

describe("qp-log-mask functional suite (mocha)", function () {
  this.timeout(30000);

  it("requires api key on protected route", async function () {
    const response = await fetch(`${BASE_URL}/mask?token=abcDEF123456`);
    assert.strictEqual(response.status, 401);
  });

  describe("global config routes", function () {
    it("does not expose masked value in response headers", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask?token=abcDEF123456&user=cognizant`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log"]);
    });

    it("does not expose headers when no configured query params are present", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask?other=1`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log"]);
    });

    it("does not expose headers for empty query values", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask?token=&user=cognizant`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log"]);
    });

    it("does not expose headers for multiple values", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask?token=abcDEF123456&token=ZZZZYYYYXXXX12&user=bob`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log"]);
    });
  });

  describe("endpoint config routes", function () {
    it("does not expose advanced header when pattern does not match", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?key1=will_not_mask1&qparam2=will_not_mask2`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-advanced"]);
    });

    it("does not expose advanced header when values are masked", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?key1=will_not_mask1&qparam2=xyz123`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-advanced"]);
    });

    it("does not expose advanced header for multiple values", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?key1=will_not_mask1&key1=xyz123`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-advanced"]);
    });

    it("does not expose advanced header for password mask", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?password=abcdefghijk12345`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-advanced"]);
    });

    it("does not expose advanced header for long alphanumeric mask", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?epqparam2=ab1234efgh`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-advanced"]);
    });

    it("does not expose advanced header for hex string mask", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?epqp1=12345abcdef12345abcdef&epqparam2=abcdefg`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-advanced"]);
    });

    it("does not expose advanced header when configured params are absent", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?notAppendKey1=will_not_mask1&notAppendKey2=xyz123`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-advanced"]);
    });

    it("does not expose advanced header when query params are over 100", async function () {
      const url = new URL(`${BASE_URL}/mask-advanced`);
      url.searchParams.append("epqp1", "12345abcdef12345abcdef");
      url.searchParams.append("epqparam2", "abcdefg");

      for (let i = 0; i < 120; i += 1) {
        url.searchParams.append(`qpk-${i}`, `qpv-${i}`);
      }

      const { response } = await getJson(url.toString(), {
        apikey: APIKEY_C1,
        Accept: "application/json",
      });

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-advanced"]);
    });
  });

  it("does not add response header when route config disables it", async function () {
    const { response } = await getJson(
      `${BASE_URL}/mask-no-header?token=abcDEF123456&user=cognizant`,
      { apikey: APIKEY_C1, Accept: "application/json" }
    );

    assert.strictEqual(response.status, 200);
    assertNoHeaders(response, ["x-kong-qp-log"]);
  });

  it("does nothing when plugin enabled flag is false", async function () {
    const { response } = await getJson(
      `${BASE_URL}/mask-plugin-disabled?token=abcDEF123456&user=cognizant`,
      { apikey: APIKEY_C1, Accept: "application/json" }
    );

    assert.strictEqual(response.status, 200);
    assertNoHeaders(response, ["x-kong-qp-log-disabled"]);
  });

  describe("edge cases", function () {
    it("does not expose header for legacy config keys", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-legacy?token=abcDEF123456&user=cognizant`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-legacy"]);
    });

    it("does not expose header for invalid regex config", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-invalid-pattern?token=abcDEF123456`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-invalid-pattern"]);
    });

    it("does not expose header when mask value is omitted", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-empty-mask?token=abcxyz123def`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-empty-mask"]);
    });

    it("does not expose custom response header name", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-custom-format?token=abcDEF123456&user=cognizant`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-custom"]);
    });

    it("does nothing when query_params_to_log is empty", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-empty-list?token=abcDEF123456&user=cognizant`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assertNoHeaders(response, ["x-kong-qp-log-empty-list"]);
    });
  });

  it("is enabled in Kong admin plugin list", async function () {
    const response = await fetch(`${ADMIN_URL}/plugins/enabled`);
    assert.strictEqual(response.status, 200);
    const body = await response.json();
    assert.ok(Array.isArray(body.enabled_plugins));
    assert.ok(body.enabled_plugins.includes("qp-log-mask"));
  });
});
