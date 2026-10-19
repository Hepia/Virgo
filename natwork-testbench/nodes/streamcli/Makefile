IMAGE_NAME=streamcli
CONTAINER_NAME=streamcli
NETWORK=ddos-test-net
BASE_IP=10.10.10.

build:
	docker build -t $(IMAGE_NAME) .

# Lancer un seul client avec l'IP 10.10.10.10
run:
	docker run --rm --name $(CONTAINER_NAME) \
	    --network $(NETWORK) --ip $(BASE_IP)10 \
	    $(IMAGE_NAME)

# Lancer N clients en parallèle avec des IPs internes croissantes
# Exemple: make clients N=5
clients:
	@if [ -z "$(N)" ]; then \
	  echo "Utilisation: make clients N=<nombre>"; \
	  exit 1; \
	fi; \
	for i in $$(seq 1 $(N)); do \
	  IP="$(BASE_IP)$$(expr 10 + $$i)"; \
	  NAME="$(CONTAINER_NAME)$$i"; \
	  echo "Lancement du client $$i sur IP $$IP..."; \
	  docker run -d --rm --name "$$NAME" \
	    --network $(NETWORK) --ip "$$IP" \
	    $(IMAGE_NAME); \
	done

# Arrêter tous les clients liés à cette image
stop:
	@docker ps -q --filter "ancestor=$(IMAGE_NAME)" | xargs -r docker stop
