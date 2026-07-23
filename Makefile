

.PHONY: docker-up docker-down docker-infra-up docker-infra-down

# --------------------------------- docker -------------------------------------


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



# --------------------------------- terraform -------------------------------------

terraform-fmt:
	@echo "Formatting terraform..."
	terraform -chdir=./infra/terraform fmt

terraform-init:
	@echo "Initializing terraform..."
	terraform -chdir=./infra/terraform init

terraform-plan:
	@echo "Planning terraform..."
	cp ./infra/.env.infra ./infra/terraform/.env.tfvars
	terraform -chdir=./infra/terraform plan

terraform-apply:
	@echo "Applying terraform..."
	terraform -chdir=./infra/terraform apply

terraform-destroy:
	@echo "Destroying terraform..."
	terraform -chdir=./infra/terraform destroy
