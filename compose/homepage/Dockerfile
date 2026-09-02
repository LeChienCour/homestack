# Config horneada en la imagen: ver compose/traefik/Dockerfile para el porqué.
# logs/ queda fuera (ver .dockerignore) — se monta como volumen aparte,
# writable, en vez de hornearse.
FROM ghcr.io/gethomepage/homepage:latest

COPY . /app/config
