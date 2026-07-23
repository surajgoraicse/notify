.PHONY: docker-up docker-down docker-infra-up docker-infra-down terraform-fmt terraform-init terraform-plan terraform-apply terraform-destroy

# --------------------------------- variables -------------------------------------
ENV_FILE=./infra/.env.infra
DOCKER_COMPOSE_INFRA_FILE=./infra/docker-compose.infra.yaml
TERRAFORM_DIR=./infra/terraform


# --------------------------------- docker -------------------------------------


docker-up:
	@echo "Starting docker..."
	docker compose up -d

docker-down:
	@echo "Stopping docker..."
	docker compose down

docker-infra-up:
	@echo "Starting infra..."
	docker compose --env-file $(ENV_FILE) -f $(DOCKER_COMPOSE_INFRA_FILE) up -d


docker-infra-down:
	@echo "Stopping infra..."
	docker compose --env-file $(ENV_FILE) -f $(DOCKER_COMPOSE_INFRA_FILE) down



# --------------------------------- terraform -------------------------------------

terraform-fmt:
	@echo "Formatting terraform..."
	terraform -chdir=$(TERRAFORM_DIR) fmt

terraform-init:
	@echo "Initializing terraform..."
	terraform -chdir=$(TERRAFORM_DIR) init

terraform-plan:
	@echo "Planning terraform..."
	cp ./infra/.env.infra ./infra/terraform/.env.tfvars
	terraform -chdir=$(TERRAFORM_DIR) plan

terraform-apply:
	@echo "Applying terraform..."
	terraform -chdir=$(TERRAFORM_DIR) apply

terraform-destroy:
	@echo "Destroying terraform..."
	terraform -chdir=$(TERRAFORM_DIR) destroy
