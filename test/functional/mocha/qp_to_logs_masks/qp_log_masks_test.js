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

describe("qp-to-logs-masks functional suite (mocha)", function () {
  this.timeout(30000);

  it("requires api key on protected route", async function () {
    const response = await fetch(`${BASE_URL}/mask?token=abcDEF123456`);
    assert.strictEqual(response.status, 401);
  });

  it("adds masked response header for configured query params", async function () {
    const { response } = await getJson(
      `${BASE_URL}/mask?token=abcDEF123456&user=cognizant`,
      { apikey: APIKEY_C1, Accept: "application/json" }
    );

    assert.strictEqual(response.status, 200);
    const header = response.headers.get("x-kong-qp-log");
    assert.ok(header);
    assert.ok(header.includes("QP-token:abcD***56"));
    assert.ok(header.includes("QP-user:cogn***nt"));
  });

  it("handles multi-value query params", async function () {
    const { response } = await getJson(
      `${BASE_URL}/mask?token=abcDEF123456&token=ZZZZYYYYXXXX12&user=bob`,
      { apikey: APIKEY_C1, Accept: "application/json" }
    );

    assert.strictEqual(response.status, 200);
    const header = response.headers.get("x-kong-qp-log");
    assert.ok(header);
    assert.ok(header.includes("QP-token:abcD***56,ZZZZ***12"));
    assert.ok(header.includes("|QP-user:bob"));
  });

  it("does not add response header when configured params are absent", async function () {
    const { response } = await getJson(
      `${BASE_URL}/mask?other=1`,
      { apikey: APIKEY_C1, Accept: "application/json" }
    );

    assert.strictEqual(response.status, 200);
    assert.strictEqual(response.headers.get("x-kong-qp-log"), null);
  });

  it("does not add response header when route config disables it", async function () {
    const { response } = await getJson(
      `${BASE_URL}/mask-no-header?token=abcDEF123456&user=cognizant`,
      { apikey: APIKEY_C1, Accept: "application/json" }
    );

    assert.strictEqual(response.status, 200);
    assert.strictEqual(response.headers.get("x-kong-qp-log"), null);
  });

  describe("advanced scenarios based on shared test images", function () {
    it("appends configured values with no masking when pattern does not match", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?key1=will_not_mask1&qparam2=will_not_mask2`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP-key1:will_not_mask1"));
      assert.ok(header.includes("QP-qparam2:will_not_mask2"));
    });

    it("applies mask for matching value", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?key1=will_not_mask1&qparam2=xyz123`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP-qparam2:mask_value"));
      assert.ok(header.includes("QP-key1:will_not_mask1"));
    });

    it("does not append anything if no configured query params are present", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?notAppendKey1=will_not_mask1&notAppendKey2=xyz123`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      assert.strictEqual(response.headers.get("x-kong-qp-log-advanced"), null);
    });

    it("handles multi-value params with one masked value", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?key1=will_not_mask1&key1=xyz123`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP-key1:will_not_mask1,mask_value"));
    });

    it("handles multi-value params with no masked values", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?key1=will_not_mask1&key1=will_not_mask2`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP-key1:will_not_mask1,will_not_mask2"));
    });

    it("applies regex-style masking for password value", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?password=abcdefghijk12345`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP-password:(masked)"));
    });

    it("applies regex-style masking for hex value", async function () {
      const { response } = await getJson(
        `${BASE_URL}/mask-advanced?epqp1=12345abcdef12345abcdef&epqparam2=abcdefg`,
        { apikey: APIKEY_C1, Accept: "application/json" }
      );

      assert.strictEqual(response.status, 200);
      const header = response.headers.get("x-kong-qp-log-advanced");
      assert.ok(header);
      assert.ok(header.includes("QP-epqp1:mask_secret"));
      assert.ok(header.includes("QP-epqparam2:abcdefg"));
    });

    it("still masks target values when request has over 100 query params", async function () {
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
      assert.ok(header.includes("QP-epqp1:mask_secret"));
      assert.ok(header.includes("QP-epqparam2:abcdefg"));
    });
  });

  it("is enabled in Kong admin plugin list", async function () {
    const response = await fetch(`${ADMIN_URL}/plugins/enabled`);
    assert.strictEqual(response.status, 200);
    const body = await response.json();
    assert.ok(Array.isArray(body.enabled_plugins));
    assert.ok(body.enabled_plugins.includes("qp-to-logs-masks"));
  });
});
