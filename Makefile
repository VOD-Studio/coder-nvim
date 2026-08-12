IMAGE_NAME ?= rocky-dev
TAG ?= latest

.PHONY: all docker

all: docker

docker:
	docker build -t $(IMAGE_NAME):$(TAG) .

# ====== 持久化开发容器（compose + SSH 登录）======
COMPOSE := docker compose
SSHD_PORT ?= 29888

.PHONY: up down restart logs shell ssh

up:        ## 启动持久化开发容器（后台）
	$(COMPOSE) up -d

down:      ## 停止并移除容器（卷保留）
	$(COMPOSE) down

restart:   ## 重启容器（应用 entrypoint 改动）
	$(COMPOSE) restart

logs:      ## 跟随容器日志
	$(COMPOSE) logs -f

shell:     ## docker exec 进 fish（不依赖 SSH/网络）
	docker exec -it rocky-dev fish

ssh:       ## SSH 登录
	ssh -p $(SSHD_PORT) coder@localhost
