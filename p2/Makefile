NAME = p2
VAGRANT = vagrant

BLUE = \033[0;34m
GREEN = \033[0;32m
RESET = \033[0m

.PHONY: all up halt status clean fclean rebuild help

all: up

help:
	@echo "$(BLUE)Available commands for $(NAME):$(RESET)"
	@echo "  make up      - Start and provision the VMs"
	@echo "  make halt    - Gracefully shut down the VMs"
	@echo "  make status  - Check the status of the VMs"
	@echo "  make clean   - Suspend and delete the VMs"
	@echo "  make fclean  - Full cleanup: delete VMs and remove .vagrant directory"
	@echo "  make rebuild - Rebuild the cluster (fclean + up)"

up:
	@echo "$(GREEN)Starting VMs for $(NAME)...$(RESET)"
	$(VAGRANT) up

halt:
	@echo "$(BLUE)Shutting down VMs for $(NAME)...$(RESET)"
	$(VAGRANT) halt

status:
	@$(VAGRANT) status

clean:
	@echo "$(BLUE)Cleaning up VMs for $(NAME)...$(RESET)"
	$(VAGRANT) destroy -f

fclean: clean
	@echo "$(BLUE)Removing .vagrant directory...$(RESET)"
	rm -rf .vagrant

rebuild: fclean all
