# Additional deployment and utility scripts

# Makefile for common operations
.PHONY: build test deploy clean help

# Variables
IMAGE_NAME := healthcare-prediction-api
IMAGE_TAG := latest
REGISTRY := 123456789012.dkr.ecr.us-west-2.amazonaws.com
NAMESPACE := healthcare-api

help:
	@echo "Available commands:"
	@echo "  build     - Build Docker image"
	@echo "  test      - Run tests"
	@echo "  deploy    - Deploy to Kubernetes"
	@echo "  clean     - Clean up resources"
	@echo "  lint      - Run code linting"
	@echo "  security  - Run security scans"

build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

test:
	python -m pytest test_app.py -v --cov=app --cov-report=html

lint:
	flake8 app.py test_app.py --max-line-length=88
	black --check app.py test_app.py
	isort --check-only app.py test_app.py

security:
	bandit -r . -f json
	docker run --rm -v $(PWD):/src aquasec/trivy fs /src

deploy:
	kubectl apply -f k8s/ --recursive
	kubectl rollout status deployment/healthcare-prediction-api -n $(NAMESPACE)

clean:
	kubectl delete -f k8s/ --recursive --ignore-not-found
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true

dev-setup:
	pip install -r requirements.txt
	pip install flake8 black isort pytest-cov bandit

local-run:
	python app.py

docker-run:
	docker run -p 8000:8000 --name healthcare-api-local $(IMAGE_NAME):$(IMAGE_TAG)

docker-stop:
	docker stop healthcare-api-local || true
	docker rm healthcare-api-local || true