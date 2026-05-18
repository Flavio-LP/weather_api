.PHONY: dev-up dev-down dev-build dev-logs dev-restart \
        prod-up prod-down prod-build prod-logs prod-restart \
        ps clean rebuild

DEV  := docker compose -f docker-compose.dev.yml
PROD := docker compose -f docker-compose.prod.yml

# ── Desenvolvimento ───────────────────────────────────────────

dev-up:
	$(DEV) up -d

dev-down:
	$(DEV) down

dev-build:
	$(DEV) build

dev-logs:
	$(DEV) logs -f

dev-restart:
	$(DEV) restart

# ── Produção ──────────────────────────────────────────────────

prod-up:
	$(PROD) up -d

prod-down:
	$(PROD) down

prod-build:
	$(PROD) build

prod-logs:
	$(PROD) logs -f

prod-restart:
	$(PROD) restart

# ── Utilitários ───────────────────────────────────────────────

ps:
	docker compose ps

clean:
	docker system prune -f

console:
	docker compose exec web bundle exec rails console

rebuild:
	docker compose down -v --remove-orphans
	docker compose build --no-cache
	docker compose up -d