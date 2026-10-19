# 1) Récupère le binaire depuis l'image officielle (corrigée pour ton arch)
ARG MTX_TAG=1.14.0
FROM bluenviron/mediamtx:${MTX_TAG} AS mtx

# 2) Image runtime Alpine avec ffmpeg
FROM alpine:3.20

RUN apk add --no-cache ffmpeg bash netcat-openbsd ca-certificates && \
    update-ca-certificates

# Copie le binaire MediaMTX depuis l'image officielle
COPY --from=mtx /mediamtx /usr/local/bin/mediamtx

# Ta config (présente à la racine du projet)
COPY mediamtx.json /etc/mediamtx.json

# Script de démarrage
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/mediamtx

VOLUME ["/videos"]
EXPOSE 8554
ENTRYPOINT ["/entrypoint.sh"]
