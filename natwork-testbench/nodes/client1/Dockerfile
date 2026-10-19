FROM debian:12-slim
RUN apt update && apt install -y curl
COPY client.sh /client.sh
CMD ["/bin/bash", "/client.sh"]