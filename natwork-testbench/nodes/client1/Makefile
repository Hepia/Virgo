IMAGE_NAME=client1
CONTAINER_NAME=client1

build:
	docker build -t $(IMAGE_NAME) .

run:
	docker run --rm --name $(CONTAINER_NAME) --network ddos-test-net --ip 10.10.10.10 $(IMAGE_NAME)
