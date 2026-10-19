IMAGE_NAME=udpsrv
CONTAINER_NAME=udpsrv

# UDP port exposed to host
HOST_UDP_PORT=9999
CONTAINER_UDP_PORT=9999

build:
	docker build -t $(IMAGE_NAME) .

run:
	docker run --rm --name $(CONTAINER_NAME) --network host $(IMAGE_NAME)
