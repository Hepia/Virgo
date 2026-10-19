IMAGE_NAME=udpcli
CONTAINER_NAME=udpcli

build:
	docker build -t $(IMAGE_NAME) .

run:
	docker run --rm --name $(CONTAINER_NAME) --network host $(IMAGE_NAME)
