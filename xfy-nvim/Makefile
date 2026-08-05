IMAGE_NAME ?= xfy-nvim
TAG ?= latest
DESTDIR ?=

.PHONY: all build install

all: build

build:
	docker build -t $(IMAGE_NAME):$(TAG) .

install:
	install -m 755 xv $(DESTDIR)/usr/local/bin/xv
