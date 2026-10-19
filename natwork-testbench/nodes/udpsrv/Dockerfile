FROM python:3.12-alpine

WORKDIR /app

COPY server_udp.py /app/
COPY entrypoint.sh /app/
COPY config.json /app/

ENTRYPOINT ["/app/entrypoint.sh"]
