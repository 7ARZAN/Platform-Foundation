NAME = bonus
CLUSTER_NAME = iot
BLUE = \033[0;34m
GREEN = \033[0;32m
RED = \033[0;31m
RESET = \033[0m
KUBECONFIG = $(shell pwd)/kubeconfig.yml

.PHONY: all up down clean status logs credentials wait

all: up

up:
	@echo "$(GREEN)Starting Vagrant VM (No Docker Platform)...$(RESET)"
	vagrant up
	@echo "$(GREEN)Retrieving Kubeconfig...$(RESET)"
	@vagrant ssh -c "sudo cat /etc/rancher/k3s/k3s.yaml" > kubeconfig.yml
	@# Replace default localhost/127.0.0.1 with the private IP for reliable connection from host
	@sed -i '' 's/127.0.0.1/192.168.56.120/g' kubeconfig.yml	
	@echo "$(GREEN)Deploying GitLab for $(NAME)...$(RESET)"
	export KUBECONFIG=$(KUBECONFIG); kubectl apply -f manifests/gitlab/namespace.yml
	@echo "$(GREEN)Deploying GitLab Resources...$(RESET)"
	@export KUBECONFIG=$(KUBECONFIG); \
	if ! kubectl get secret gitlab-credentials -n gitlab >/dev/null 2>&1; then \
		PASS=$$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24); \
		kubectl create secret generic gitlab-credentials -n gitlab --from-literal=root-password="$$PASS"; \
	fi
	export KUBECONFIG=$(KUBECONFIG); kubectl apply -f manifests/gitlab/
	@echo "$(BLUE)Waiting for GitLab to be ready... (Take a coffee, this pulls a large image)$(RESET)"
	@# Wait for pod creation to be acknowledged
	@sleep 5
	export KUBECONFIG=$(KUBECONFIG); kubectl wait --for=condition=ready pod -l app=gitlab -n gitlab --timeout=900s
	@echo "$(GREEN)Running Setup Script (Project Setup, Token Gen, Git Push)...$(RESET)"
	export KUBECONFIG=$(KUBECONFIG); bash scripts/setup_bonus.sh

down:
	@echo "$(RED)Destroying Bonus Infrastructure...$(RESET)"
	vagrant destroy -f
	rm -f kubeconfig.yml

status:
	@echo "$(BLUE)GitLab Pods:$(RESET)"
	export KUBECONFIG=$(KUBECONFIG); kubectl get pods -n gitlab
	@echo "$(BLUE)ArgoCD Pods:$(RESET)"
	export KUBECONFIG=$(KUBECONFIG); kubectl get pods -n argocd

logs:
	export KUBECONFIG=$(KUBECONFIG); kubectl logs -n gitlab -l app=gitlab -f

credentials:
	@echo "$(GREEN)GitLab Root User: root$(RESET)"
	@echo "$(GREEN)GitLab Root Password:$(RESET)"
	@export KUBECONFIG=$(KUBECONFIG); kubectl get secret gitlab-credentials -n gitlab -o jsonpath='{.data.root-password}' | base64 -d && echo ""
	@echo "$(GREEN)ArgoCD Admin Password:$(RESET)"
	@export KUBECONFIG=$(KUBECONFIG); kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo ""
