APP_NAME              := kong-qp-to-logs-masks
COMPOSE               := docker compose
DOCKER                := docker
PONGO                 := pongo
NPM                   := npm
KONG_ADMIN_URL        := http://localhost:8001
KONG_MANAGER_URL      := http://localhost:8002
BASE_PROXY_URL        := http://localhost:8000
APIKEY_C1             := demo-consumer-apikey

.DEFAULT_GOAL := help

## help: Show available commands
help:
	@echo ""
	@echo "Available targets:"
	@echo "------------------------------------------------------------"
	@awk 'BEGIN {FS = ": "} /^## / {sub(/^## /, "", $$0); printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo "------------------------------------------------------------"
	@echo ""

## build: Build Docker image
build:
	$(COMPOSE) build

## up: Start Kong + httpbin stack
up:
	$(COMPOSE) up -d

## down: Stop Kong + httpbin stack
down:
	$(COMPOSE) down

## restart: Restart services
restart:
	$(COMPOSE) restart

## rebuild: Full rebuild without cache
rebuild:
	$(COMPOSE) down -v
	$(COMPOSE) build --no-cache
	$(COMPOSE) up -d

## logs: Follow stack logs
logs:
	$(COMPOSE) logs -f

## health: Check Kong status endpoint
health:
	@curl -s $(KONG_ADMIN_URL)/status | jq . || true

## enabled-plugins: List enabled plugins from Admin API
enabled-plugins:
	@curl -s $(KONG_ADMIN_URL)/plugins/enabled | jq . || true

## config: Dump active Kong config from Admin API
config:
	@curl -s $(KONG_ADMIN_URL)/config | jq . || true

## validate-config: Validate declarative config inside Kong container
validate-config:
	$(COMPOSE) exec kong kong config parse /etc/kong/kong.yml

## shell: Open shell in Kong container
shell:
	$(COMPOSE) exec kong sh

## lint: Run luacheck through pongo
lint:
	$(PONGO) lint

## test-smoke: Run local smoke checks against /mask route
test-smoke:
	@curl -s -H "apikey: $(APIKEY_C1)" "$(BASE_PROXY_URL)/mask?token=abcDEF123456&user=cognizant" -D /tmp/qp-mask-headers.txt -o /tmp/qp-mask-body.json
	@grep -i "^X-Kong-QP-Log:" /tmp/qp-mask-headers.txt >/dev/null
	@echo "Smoke test passed"

## pongo-up: Start pongo environment
pongo-up:
	$(PONGO) up

## pongo-test: Run unit tests with pongo (busted)
pongo-test:
	$(PONGO) run

## pongo-down: Stop pongo environment
pongo-down:
	$(PONGO) down

## test: Alias for pongo-test
test: pongo-test

## npm-install: Install Node.js dependencies for mocha tests
npm-install:
	$(NPM) install

## test-functional: Run mocha functional suite (requires local stack up)
test-functional:
	$(NPM) run test:functional

## test-mocha: Alias for test-functional
test-mocha: test-functional

## bruno: Show Bruno collection path
bruno:
	@echo "Open Bruno collection at: bruno/qp-to-logs-masks"

## manager: Print Kong Manager URL
manager:
	@echo "Kong Manager: $(KONG_MANAGER_URL)"

## clean: Remove local node modules and bring stack down with volumes
clean:
	rm -rf node_modules
	$(COMPOSE) down -v

## prune: Docker system prune
prune:
	$(DOCKER) system prune -f
