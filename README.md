# Kong Plugin: QP Log Mask (`qp-log-mask`)

`qp-log-mask` captures selected query parameters, applies ordered masking rules, and writes the final masked value into Kong's structured log serializer.

## Scope of the Plugin

What this plugin does:
- Reads configured query parameters from incoming HTTP requests.
- Masks parameter values using ordered regex rules.
- Produces a compact formatted token list such as `QP_token:abc***def|QP_user:bob`.
- Stores the final value in `kong.log.set_serialize_value(config.output_field, value)`.

What this plugin does not do:
- It does not emit query-mask data in response headers.
- It does not modify upstream request payloads.

## How It Works (End-to-End)

1. `access` phase:
- Read request query params.
- For each configured key, collect value(s), normalize empty/nil, apply masks in order.
- Build entries in format `QP_<key>:<masked_values>`.
- Join entries with `config.separator` (default `|`) and cache in `kong.ctx.plugin.qp_log_masks_value`.

Failure behavior:
- The plugin is strict. Invalid runtime masking operations (for example malformed regex patterns) are not swallowed and will fail request processing.

2. `log` phase:
- Read cached value from `kong.ctx.plugin`.
- Write value to serializer field `config.output_field` (default `qp_log`).

## Key Config Fields

- `enabled` (bool, default `true`): global on/off switch.
- `query_params_to_log` (array[string]): list of query keys to capture.
- `query_params_log_mask` (array[{ pattern, mask? }]): ordered mask rules.
- `separator` (string, default `|`): delimiter between per-key tokens.
- `output_field` (string, default `qp_log`): serializer field name.

## Local Stack

Main files:
- `Dockerfile`
- `docker-compose.yaml`
- `config/kong.yml`
- `kong/plugins/qp-log-mask/handler.lua`
- `kong/plugins/qp-log-mask/schema.lua`

Start stack:
```bash
make build
make up
make health
make enabled-plugins
```

Smoke check:
```bash
curl -i -H "apikey: demo-consumer-apikey" \
  "http://localhost:8000/mask?token=abcDEF123456&user=cognizant"
# Expected: no X-Kong-QP-Log response header
```

## Tests

### Unit/Integration (Pongo)
```bash
make pongo-test
```

### Functional (Pytest)
Install dependencies:
```bash
make install-pytest
```

Run functional suite:
```bash
make test-functional
```

Run all suites:
```bash
make test-all
```

Environment overrides used by functional tests:
- `BASE_URL` (default from Makefile: `http://localhost:8000`)
- `ADMIN_URL` (default from Makefile: `http://localhost:8001`)
- `APIKEY_C1` (default from Makefile: `demo-consumer-apikey`)

Functional test files:
- `tests/functional/pytest/conftest.py`
- `tests/functional/pytest/test_qp_log_mask.py`

## Bruno Collection

- `bruno/qp-log-mask`
- `bruno/qp-log-mask/environments/Local.bru`

## Useful Commands

```bash
make help
make build
make up
make logs
make down
make validate-config
make test-smoke
make pongo-test
make install-pytest
make test-functional
make test-all
```
