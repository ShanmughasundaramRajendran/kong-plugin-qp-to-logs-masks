# Kong Plugin: QP To Logs Masks

`qp-log-mask` is a Kong plugin that:
- reads selected query params from incoming requests,
- masks sensitive values using ordered regex rules,
- writes the final string into Kong log serializer,
- optionally adds the same value to a response header.

## Why this plugin
Use this when you want query param visibility in logs without exposing raw secrets like tokens/passwords.

## How it works
For each request:
1. Read configured query params from `config.query_params_to_log` (array of keys).
2. For each matching non-empty param, build `QP_<param>:<value>`.
3. Apply masks in order (`config.query_params_log_mask` using `ngx.re.gsub`).
4. Join all entries with `config.separator`.
5. Write result to serializer field `config.output_field`.
6. If `config.add_response_header=true`, set `config.response_header_name`.

Example output:
`QP_token:abcD***56|QP_user:cogn***nt`

## Key config fields
- `enabled`: Boolean switch for plugin execution (default `true`)
- `error_format`: String option kept for Janus compatibility (default `default`)
- `query_params_to_log`: Array of query keys to capture (example: `["token","user"]`)
- `query_params_log_mask`: Ordered list of `{ pattern, mask }`
- `separator`: Join separator between query entries (default `|`)
- `output_field`: Serializer field name for logs (example `qp_log`)
- `add_response_header`: Whether to include masked value in response header
- `response_header_name`: Header name when enabled (example `X-Kong-QP-Log`)

## Local setup
This repo uses the same structure style as `kong-plugin-oauth-client-context`:
- [Dockerfile](/Users/shanmughasundaramrajendran/kong-plugin-qp-to-logs-masks/Dockerfile)
- [docker-compose.yaml](/Users/shanmughasundaramrajendran/kong-plugin-qp-to-logs-masks/docker-compose.yaml)
- [config/kong.yml](/Users/shanmughasundaramrajendran/kong-plugin-qp-to-logs-masks/config/kong.yml)
- [.pongo/pongo.yml](/Users/shanmughasundaramrajendran/kong-plugin-qp-to-logs-masks/.pongo/pongo.yml)
- [spec/qp_to_logs_masks_spec.lua](/Users/shanmughasundaramrajendran/kong-plugin-qp-to-logs-masks/spec/qp_to_logs_masks_spec.lua)
- [test/functional/mocha/qp_to_logs_masks/qp_log_masks_test.js](/Users/shanmughasundaramrajendran/kong-plugin-qp-to-logs-masks/test/functional/mocha/qp_to_logs_masks/qp_log_masks_test.js)

## Routes in local config
From [config/kong.yml](/Users/shanmughasundaramrajendran/kong-plugin-qp-to-logs-masks/config/kong.yml):
- `/mask`: header enabled (`X-Kong-QP-Log`)
- `/mask-no-header`: header disabled
- `/mask-advanced`: advanced masks, header `X-Kong-QP-Log-Advanced`

All routes are protected with `key-auth`.

## Quick start (with comments)
```bash
make build            # build local Kong image with plugin
make up               # start Kong + httpbin
make health           # check admin API health
make enabled-plugins  # verify qp-log-mask is enabled
```

## Smoke test (with comments)
```bash
curl -i \
  -H "apikey: demo-consumer-apikey" \
  "http://localhost:8000/mask?token=abcDEF123456&user=cognizant"
# Expect header:
# X-Kong-QP-Log: QP_token:abcD***56|QP_user:cogn***nt
```

## Where masked data appears
- Response header (if enabled):
  - `/mask` -> `X-Kong-QP-Log`
  - `/mask-advanced` -> `X-Kong-QP-Log-Advanced`
- Kong logs serializer field (`output_field`) in proxy logs.

Check logs:
```bash
docker compose logs -f kong
```

## Tests
### Unit tests (Pongo)
```bash
make pongo-up     # start pongo dependencies
make pongo-test   # run busted specs
make pongo-down   # stop pongo dependencies
```

Shortcut:
```bash
make test
```

### Functional tests (Mocha)
```bash
make npm-install      # install mocha deps
make test-functional  # run functional suite
```

Environment overrides:
- `BASE_URL` (default `http://localhost:8000`)
- `ADMIN_URL` (default `http://localhost:8001`)
- `APIKEY_C1` (default `demo-consumer-apikey`)

## Bruno
Import collection folder:
- [bruno/qp-log-mask](/Users/shanmughasundaramrajendran/kong-plugin-qp-to-logs-masks/bruno/qp-log-mask)

Use environment:
- [bruno/qp-log-mask/environments/Local.bru](/Users/shanmughasundaramrajendran/kong-plugin-qp-to-logs-masks/bruno/qp-log-mask/environments/Local.bru)

## Troubleshooting
- Header not visible on `/mask`:
  - ensure query keys match configured `query_params_to_log`
  - use `curl -i` (some clients hide headers)
- No header on `/mask-no-header`:
  - expected (`add_response_header=false`)
- Kong not starting:
  - run `docker compose logs kong` and check schema/config errors

## Useful commands
```bash
make help
make build
make up
make logs
make down
make validate-config
make test-smoke
make pongo-test
make test-functional
```
