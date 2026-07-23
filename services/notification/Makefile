include .env

.PHONY: run db-init reset-db db-reset sqlc migrate-up migrate-down

# --------------------------------- variables -------------------------------------


DOCKER_POSTGRES_SERVICE_NAME=postgres
DB_URL := postgres://$(DB_USER):$(DB_PASSWORD)@$(DOCKER_POSTGRES_SERVICE_NAME):$(DB_PORT)/$(DB_NAME)?sslmode=$(SSL_MODE)
SQLC_FILE := internal/db/sqlc.yaml
SQLC := $(shell command -v sqlc 2>/dev/null)
MAIN = cmd/server/main.go


# We mount our local internal/db/migrations folder.
# We attach to the 'orchestrix' network so we can resolve the 'shared_postgres' container by name.
MIGRATE_CMD := docker run --rm -v $(shell pwd)/internal/db/migrations:/migrations --network notify_network migrate/migrate:v4.19.0

run:
	@echo "Starting scheduler server..."
	@go run ${MAIN}



# ------------------- docker --------------------------


# ------------------- Database ------------------------

# Database initialization - run only consolidated baseline migration
db-init:
	@echo "Initializing database (via migrate up)..."
	$(MAKE) migrate-up
	@echo "Database initialization complete!"

# Full database reset (drops DB)
reset-db:
	@echo "Resetting entire database (all schemas)..."
	@echo "Terminating active connections..."
	docker compose -f ../../infra/docker-compose.infra.yaml --env-file ../../infra/.env.infra exec -T ${DOCKER_POSTGRES_SERVICE_NAME} psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();"
	docker compose -f ../../infra/docker-compose.infra.yaml --env-file ../../infra/.env.infra exec -T ${DOCKER_POSTGRES_SERVICE_NAME} psql -U postgres -c "DROP DATABASE IF EXISTS \"${DB_NAME}\";"
	docker compose -f ../../infra/docker-compose.infra.yaml --env-file ../../infra/.env.infra exec -T ${DOCKER_POSTGRES_SERVICE_NAME} psql -U postgres -c "CREATE DATABASE \"${DB_NAME}\";"
	$(MAKE) db-init
	@echo "Full database reset complete."

# backword compatibility alias
db-reset: reset-db

# migration
migrate-up:
	@echo "Applying Notification Service migrations..."
	@$(MIGRATE_CMD) -path=/migrations -database "$(DB_URL)" up
	@echo "Notification Service migrations applied successfully!"

migrate-down:
	@echo "Rolling back Notification Service migrations..."
	@$(MIGRATE_CMD) -path=/migrations -database "$(DB_URL)" down 1
	@echo "Notification Service migrations rolled back successfully!"

sqlc:
	@echo "Generating sqlc queries..."
	@if [ -n "$(SQLC)" ]; then \
		$(SQLC) generate -f ${SQLC_FILE}; \
	else \
		go run github.com/sqlc-dev/sqlc/cmd/sqlc@v1.30.0 generate -f ${SQLC_FILE}; \
	fi
	@echo "SQLC queries generated!"
