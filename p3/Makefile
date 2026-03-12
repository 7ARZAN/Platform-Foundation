NAME = p3
CLUSTER_NAME = iot
BLUE = \033[0;34m
GREEN = \033[0;32m
RED = \033[0;31m
RESET = \033[0m

.PHONY: all up down clean rebuild help status provision

all: up

help:
	@echo "$(BLUE)Available commands for $(NAME):$(RESET)"
	@echo "  make provision - Install requirements (Docker, k3d, kubectl, argocd)"
	@echo "  make up        - Create and provision the k3d cluster"
	@echo "  make down      - Stop the cluster"
	@echo "  make clean     - Delete the cluster and namespaces"
	@echo "  make status    - Show cluster status"
	@echo "  make rebuild   - Rebuild everything"

provision:
	@echo "$(GREEN)Installing requirements for $(NAME)...$(RESET)"
	bash scripts/provision.sh

up: provision
	@echo "$(GREEN)Initializing K3d cluster for $(NAME)...$(RESET)"
	bash scripts/cluster.sh
	bash scripts/argocd.sh
	bash scripts/setup_app.sh
	bash scripts/verify.sh

down:
	@echo "$(BLUE)Stopping K3d cluster...$(RESET)"
	k3d cluster stop $(CLUSTER_NAME) || true

status:
	@k3d cluster list $(CLUSTER_NAME)
	@kubectl get nodes -o wide

clean:
	@echo "$(RED)Deleting K3d cluster...$(RESET)"
	k3d cluster delete $(CLUSTER_NAME) || true

rebuild: clean all
