IMAGE_NAME=websrv
CONTAINER_NAME=websrv

build:
	docker build -t $(IMAGE_NAME) .

run:
	docker run --rm --name $(CONTAINER_NAME) \
	    --network ddos-test-net --ip 10.10.10.10 -p 8080:80 \
	    -v $(PWD)/html:/usr/share/nginx/html:ro \
	    $(IMAGE_NAME)
