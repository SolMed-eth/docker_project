NAME		= inception
COMPOSE		= docker compose -f srcs/docker-compose.yml --env-file srcs/.env
DATA_DIR	= /home/mchafiki/data

all: up

up:
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

clean: down
	docker system prune -af

fclean: clean
	$(COMPOSE) down -v
	sudo rm -rf $(DATA_DIR)

re: fclean all

.PHONY: all up down stop start restart logs ps clean fclean re
