FROM debian:12-slim
RUN apt update && apt install -y mosquitto-clients
COPY iot.sh /iot.sh
CMD ["/bin/bash", "/iot.sh"]