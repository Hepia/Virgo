IMAGE_NAME=streamsrv
CONTAINER_NAME=streamsrv

build:
	docker build -t $(IMAGE_NAME) .

run:
	docker run --rm --name $(CONTAINER_NAME) --network ddos-test-net --ip 10.10.10.10 -p 8554:8554 -v $(PWD)/videos:/videos $(IMAGE_NAME)
