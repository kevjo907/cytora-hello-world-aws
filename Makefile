.DEFAULT_GOAL := help
TF := terraform -chdir=terraform

.PHONY: help install lint test fmt validate plan apply destroy outputs smoke clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

install: ## Install Python dev dependencies
	python3 -m pip install --upgrade pytest ruff

lint: ## Lint the application code
	ruff check .
	ruff format --check .

test: ## Run unit tests
	pytest

fmt: ## Format Terraform and Python
	terraform fmt -recursive
	ruff format .

validate: ## Validate Terraform without touching AWS
	terraform fmt -check -recursive
	$(TF) init -backend=false
	$(TF) validate

plan: ## Show the planned changes
	$(TF) plan

apply: ## Deploy to AWS
	$(TF) apply

destroy: ## Tear everything down
	$(TF) destroy

outputs: ## Print the stack outputs
	$(TF) output

smoke: ## curl the deployed /hello endpoint
	@curl -sS "$$($(TF) output -raw hello_url)" | jq .

clean: ## Remove local build and cache artifacts
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	find . -type d -name .pytest_cache -prune -exec rm -rf {} +
	find . -type d -name .ruff_cache -prune -exec rm -rf {} +
	find . -type d -name .terraform-build -prune -exec rm -rf {} +
