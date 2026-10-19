FROM python:3.12-alpine

WORKDIR /app

# Copy client scripts and configuration
COPY client_udp.py /app/
COPY entrypoint.sh /app/
COPY config.json /app/

ENTRYPOINT ["/app/entrypoint.sh"]
