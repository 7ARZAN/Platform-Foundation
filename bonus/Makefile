NAME         = bonus
CLUSTER_NAME = iot

BLUE  = \033[0;34m
GREEN = \033[0;32m
RED   = \033[0;31m
RESET = \033[0m

P3      = ../p3/scripts
SCRIPTS = scripts

.PHONY: all up down clean rebuild status logs help

all: up

help:
	@echo "$(BLUE)$(NAME)$(RESET)"
	@echo "  make up       — full stack: cluster + Gitea + ArgoCD + app"
	@echo "  make down     — stop the cluster"
	@echo "  make clean    — delete cluster + wipe state"
	@echo "  make rebuild  — clean + up"
	@echo "  make status   — pods / nodes overview"
	@echo "  make logs     — tail all pod logs"

.provision-done:
	@bash $(P3)/provision.sh
	@touch .provision-done

provision: .provision-done

up: provision
	@echo "$(GREEN)[1/4] Cluster$(RESET)"
	@bash $(P3)/cluster.sh
	@echo "$(GREEN)[2/4] ArgoCD$(RESET)"
	@bash $(P3)/argocd.sh
	@echo "$(GREEN)[3/4] Gitea$(RESET)"
	@bash $(SCRIPTS)/setup_gitea.sh
	@echo "$(GREEN)[4/4] App$(RESET)"
	@bash $(SCRIPTS)/setup_app.sh

down:
	@k3d cluster stop $(CLUSTER_NAME) || true

clean:
	@echo "$(RED)Deleting $(CLUSTER_NAME)...$(RESET)"
	@k3d cluster delete $(CLUSTER_NAME) || true
	@rm -f .provision-done
	@docker system prune -a

rebuild: clean up

status:
	@k3d cluster list $(CLUSTER_NAME) || true
	@kubectl get nodes -o wide || true
	@kubectl get pods -A || true

logs:
	@kubectl logs -n dev -l app=wil42-playground --tail=50 -f || true
