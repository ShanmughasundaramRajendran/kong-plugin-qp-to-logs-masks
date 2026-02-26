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

describe("qp-log-mask functional suite (mocha)", function () {
  this.timeout(30000);

  it("requires api key on protected route", async function () {
    const response = await fetch(`${BASE_URL}/mask?token=abcDEF123456`);
    assert.strictEqual(response.status, 401);
  });

  describe("using global config", function () {
    it("should append to log with value masked", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask?token=abcDEF123456&user=cognizant`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log");
      assert.ok(header);
      assert.ok(header.includes("QP_token:abcD***56"));
      assert.ok(header.includes("QP_user:cogn***nt"));
    });

    it("should not append to log if no configured query params are present", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask?other=1`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assert.strictEqual(response.headers.get("x-kong-qp-log"), null);
    });

    it("should not append empty values", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask?token=&user=cognizant`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log");
      assert.strictEqual(header, "QP_user:cogn***nt");
    });

    it("should append for multiple values with masking", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask?token=abcDEF123456&token=ZZZZYYYYXXXX12&user=bob`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log");
      assert.ok(header);
      assert.ok(header.includes("QP_token:abcD***56,ZZZZ***12"));
      assert.ok(header.includes("|QP_user:bob"));
    });
  });

  describe("using endpoint config", function () {
    it("should append to log with no value masked when pattern does not match", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?key1=will_not_mask1&qparam2=will_not_mask2`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP_key1:will_not_mask1"));
      assert.ok(header.includes("QP_qparam2:will_not_mask2"));
    });

    it("should append to log with a value masked", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?key1=will_not_mask1&qparam2=xyz123`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP_qparam2:mask_value"));
      assert.ok(header.includes("QP_key1:will_not_mask1"));
    });

    it("should append to log for multiple values and one masked value", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?key1=will_not_mask1&key1=xyz123`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP_key1:will_not_mask1,mask_value"));
    });

    it("should append to log for multiple values and no values masked", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?key1=will_not_mask1&key1=will_not_mask2`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP_key1:will_not_mask1,will_not_mask2"));
    });

    it("should append to log with regex for password", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?password=abcdefghijk12345`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP_password:(masked)"));
    });

    it("should append to log with regex for 10+ length alphanumeric value", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?epqparam2=ab1234efgh`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP_epqparam2:(masked)"));
    });

    it("should append to log with regex for hex string", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?epqp1=12345abcdef12345abcdef&epqparam2=abcdefg`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP_epqp1:mask_secret"));
      assert.ok(header.includes("QP_epqparam2:abcdefg"));
    });

    it("should not append if none of endpoint configured params are present", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?notAppendKey1=will_not_mask1&notAppendKey2=xyz123`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assert.strictEqual(response.headers.get("x-kong-qp-log-advanced"), null);
    });

    it("should still mask target values when query params are over 100", async function () {
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
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP_epqp1:mask_secret"));
      assert.ok(header.includes("QP_epqparam2:abcdefg"));
    });
  });

  it("does not add response header when route config disables it", async function () {
    const { response } = await getJson(
      `${BASE_URL}/mask-no-header?token=abcDEF123456&user=cognizant`,
      { apikey: APIKEY_C1, Accept: "application/json" }
    );

    assert.strictEqual(response.status, 200);
    assert.strictEqual(response.headers.get("x-kong-qp-log"), null);
  });

  it("does nothing when plugin enabled flag is false", async function () {
    const { response } = await getJson(
      `${BASE_URL}/mask-plugin-disabled?token=abcDEF123456&user=cognizant`,
      { apikey: APIKEY_C1, Accept: "application/json" }
    );

    assert.strictEqual(response.status, 200);
    assert.strictEqual(response.headers.get("x-kong-qp-log-disabled"), null);
  });

  describe("edge cases", function () {
    it("supports legacy config keys query_params and masks", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-legacy?token=abcDEF123456&user=cognizant`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-legacy");
      assert.ok(header);
      assert.ok(header.includes("QP_token:abcD***56"));
      assert.ok(header.includes("QP_user:cogn***nt"));
    });

    it("ignores invalid regex patterns and keeps value unchanged", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-invalid-pattern?token=abcDEF123456`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-invalid-pattern");
      assert.strictEqual(header, "QP_token:abcDEF123456");
    });

    it("uses empty replacement when mask value is omitted", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-empty-mask?token=abcxyz123def`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-empty-mask");
      assert.strictEqual(header, "QP_token:abcdef");
    });

    it("supports custom separator and custom response header name", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-custom-format?token=abcDEF123456&user=cognizant`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-custom");
      assert.ok(header);
      assert.ok(header.includes("QP_token:abcD***56||QP_user:cogn***nt"));
    });

    it("does nothing when query_params_to_log is empty", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-empty-list?token=abcDEF123456&user=cognizant`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assert.strictEqual(response.headers.get("x-kong-qp-log-empty-list"), null);
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
