

.PHONY: docker-up docker-down docker-infra-up docker-infra-down

docker-up:
	@echo "Starting docker..."
	docker compose up -d

docker-down:
	@echo "Stopping docker..."
	docker compose down

docker-infra-up:
	@echo "Starting infra..."
	docker compose --env-file ./infra/.env.infra -f ./infra/docker-compose.infra.yaml up -d


docker-infra-down:
	@echo "Stopping infra..."
	docker compose --env-file ./infra/.env.infra -f ./infra/docker-compose.infra.yaml down
