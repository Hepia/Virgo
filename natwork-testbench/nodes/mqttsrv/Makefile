IMAGE_NAME=mqttsrv
CONTAINER_NAME=mqttsrv

build:
	docker build -t $(IMAGE_NAME) .

run:
	docker run --rm --name $(CONTAINER_NAME) --network ddos-test-net --ip 10.10.10.10 -p 1883:1883 -v $(PWD)/config:/mosquitto/config $(IMAGE_NAME)
