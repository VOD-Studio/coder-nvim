IMAGE_NAME ?= rocky-dev
TAG ?= latest

.PHONY: all docker

all: docker

docker:
	docker build -t $(IMAGE_NAME):$(TAG) .
