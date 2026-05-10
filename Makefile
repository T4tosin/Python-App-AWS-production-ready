.PHONY: help build test run stop clean tf-init tf-plan tf-apply tf-destroy logs

# ── Config ────────────────────────────────────────────────────────────────────
PROJECT     := devops-challenge
IMAGE       := $(PROJECT)-app
TAG         := local
TF_DIR      := terraform
TF_VARS     := -var-file="environments/prod/terraform.tfvars"

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Application ───────────────────────────────────────────────────────────────
build: ## Build the Docker image
	docker build -t $(IMAGE):$(TAG) ./app

test: ## Run unit tests (inside Docker)
	docker run --rm \
		-w /app \
		$(IMAGE):$(TAG) \
		python -m pytest test_main.py -v

test-local: ## Run unit tests locally (requires Python + deps installed)
	cd app && python -m pytest test_main.py -v

run: ## Start the full stack with docker-compose
	docker compose up --build -d
	@echo "App:       http://localhost:5000"
	@echo "Kibana:    http://localhost:5601"
	@echo "ES:        http://localhost:9200"

run-app: ## Start only the app (no ELK)
	docker compose up --build -d app

stop: ## Stop all containers
	docker compose down

logs: ## Tail application logs
	docker compose logs -f app

clean: ## Remove containers, images, volumes
	docker compose down -v --rmi local
	docker image prune -f

# ── Terraform ─────────────────────────────────────────────────────────────────
tf-bootstrap: ## Create S3 backend + DynamoDB lock table (run once)
	bash ci-cd/bootstrap-tfstate.sh

tf-init: ## Terraform init
	cd $(TF_DIR) && terraform init

tf-fmt: ## Format Terraform files
	cd $(TF_DIR) && terraform fmt -recursive

tf-validate: ## Validate Terraform config
	cd $(TF_DIR) && terraform validate

tf-plan: ## Terraform plan (prod)
	cd $(TF_DIR) && terraform plan $(TF_VARS)

tf-apply: ## Terraform apply (prod)
	cd $(TF_DIR) && terraform apply $(TF_VARS)

tf-destroy: ## Destroy all infrastructure
	cd $(TF_DIR) && terraform destroy $(TF_VARS)

tf-output: ## Show Terraform outputs
	cd $(TF_DIR) && terraform output
