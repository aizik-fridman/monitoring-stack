# =============================================================================
# Prometheus-Grafana-Kit — Makefile
# =============================================================================

COMPOSE  := docker compose
CONFIG   := prometheus/prometheus.yml

.DEFAULT_GOAL := help

.PHONY: help up down restart logs status validate clean

## ─── Core Commands ──────────────────────────────────────────────────────────

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

up: validate ## Start the full observability stack (detached)
	$(COMPOSE) up -d
	@echo ""
	@echo "  Prometheus  ->  http://localhost:9090"
	@echo "  Grafana     ->  http://localhost:3000  (credentials from .env)"
	@echo "  Thanos      ->  http://localhost:9091"
	@echo "  VictoriaMetrics -> http://localhost:8428"
	@echo ""

down: ## Stop and remove all containers
	$(COMPOSE) down

restart: down up ## Restart the entire stack

logs: ## Tail logs from all services
	$(COMPOSE) logs -f --tail=100

status: ## Show status of all services
	$(COMPOSE) ps

## ─── Validation ─────────────────────────────────────────────────────────────

validate: ## Validate Prometheus configuration via promtool
	@docker run --rm \
		-v $(PWD)/$(CONFIG):/etc/prometheus/prometheus.yml:ro \
		prom/prometheus:v3.4.2 \
		promtool check config /etc/prometheus/prometheus.yml \
	&& echo "\n  ✓ Prometheus config is valid.\n" \
	|| (echo "\n  ✗ Prometheus config has errors.\n" && exit 1)

## ─── Cleanup ────────────────────────────────────────────────────────────────

clean: down ## Stop stack and destroy persistent volumes
	$(COMPOSE) down -v
	@echo "  Volumes removed."
