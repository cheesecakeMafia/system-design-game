.PHONY: help setup

help: ## Show available targets
	@echo "Usage:"
	@echo "  make setup    Clone external dependencies (System Design Primer + Server Survival)"
	@echo "  make help     Show this help message"

setup: ## Clone external dependencies
	./setup.sh
