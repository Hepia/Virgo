FROM debian:12-slim

# Installer ffmpeg (ffplay inclus), et nettoyer après installation
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copier le script client
COPY stream.sh /stream.sh
RUN chmod +x /stream.sh

# Lancer le script
CMD ["/bin/bash", "/stream.sh"]
