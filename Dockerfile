# syntax=docker/dockerfile:1

# Bumped automatically by .github/workflows/release.yml.
ARG CADDY_VERSION=2.11.9
# Bumped by pull request from .github/workflows/plugin-update.yml.
ARG INFOMANIAK_VERSION=1.0.2

# Runs on the build host and cross-compiles, so arm64 needs no emulation.
FROM --platform=$BUILDPLATFORM caddy:${CADDY_VERSION}-builder AS build
ARG CADDY_VERSION
ARG INFOMANIAK_VERSION
ARG TARGETOS
ARG TARGETARCH

# XCADDY_SETCAP=0: file capabilities make exec fail under `cap_drop: ALL` and
# `no-new-privileges`. Docker lets unprivileged processes bind low ports anyway.
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH XCADDY_SETCAP=0 \
    xcaddy build "v${CADDY_VERSION}" \
      --with "github.com/caddy-dns/infomaniak@v${INFOMANIAK_VERSION}" \
      --output /rootfs/usr/bin/caddy

# Distroless has no shell, so everything the image needs is prepared here.
# /config and /data are 1777 so `user:` works with any UID on a new named volume,
# which inherits this mode. Caddy keeps everything inside them private (0700/0600).
RUN apk add --no-cache mailcap \
    && install -D -m 0644 /etc/mime.types /rootfs/etc/mime.types \
    && install -d -o 65532 -g 65532 -m 1777 /rootfs/config /rootfs/data \
    && install -d -o 65532 -g 65532 /rootfs/srv

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build /rootfs/ /
COPY Caddyfile /etc/caddy/Caddyfile

ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data

WORKDIR /srv
VOLUME /config /data
EXPOSE 80 443 443/udp 2019

ENTRYPOINT ["/usr/bin/caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
