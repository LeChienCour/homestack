# Config horneada en la imagen: la VM de Podman (applehv) no tiene montado
# /Volumes/Dock, así que el bind mount ./traefik/... no es visible dentro
# de la VM. El build-context sí llega (se manda por la API), así que
# horneamos la config acá en vez de bind-montearla.
FROM traefik:v3.2

COPY traefik.yml /etc/traefik/traefik.yml
COPY dynamic/ /etc/traefik/dynamic/
