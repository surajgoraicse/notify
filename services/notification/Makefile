include .env

.PHONY: run db-init reset-db db-reset sqlc migrate-up migrate-down

DOCKER_POSTGRES_SERVICE_NAME=postgres
DB_URL := postgres://$(DB_USER):$(DB_PASSWORD)@$(DOCKER_POSTGRES_SERVICE_NAME):$(DB_PORT)/$(DB_NAME)?sslmode=$(SSL_MODE)
SQLC_FILE := internal/db/sqlc.yaml
SQLC := $(shell command -v sqlc 2>/dev/null)
MAIN = cmd/server/main.go




# database

sqlc:
	@echo "Generating sqlc queries..."
	@if [ -n "$(SQLC)" ]; then \
		$(SQLC) generate -f ${SQLC_FILE}; \
	else \
		go run github.com/sqlc-dev/sqlc/cmd/sqlc@v1.30.0 generate -f ${SQLC_FILE}; \
	fi
	@echo "SQLC queries generated!"