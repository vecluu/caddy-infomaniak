#!/usr/bin/env bash
# Checks an image against the versions in the Dockerfile: smoke.sh <image>
set -euo pipefail
cd "$(dirname "$0")/.."

image=$1
caddy_version=$(sed -n 's/^ARG CADDY_VERSION=//p' Dockerfile)
plugin_version=$(sed -n 's/^ARG INFOMANIAK_VERSION=//p' Dockerfile)

docker run --rm "$image" version | grep "^v$caddy_version "
docker run --rm "$image" list-modules --versions | grep -Fx "dns.providers.infomaniak v$plugin_version"
docker run --rm -e INFOMANIAK_API_TOKEN=dummy \
  -v "$PWD/test/Caddyfile:/etc/caddy/Caddyfile:ro,z" \
  "$image" validate --config /etc/caddy/Caddyfile --adapter caddyfile

# Any UID must be able to write to a new volume without a chown.
container=$(docker run -d --user 12345:12345 "$image")
trap 'docker rm -f -v "$container" > /dev/null' EXIT
sleep 3
docker logs "$container" 2>&1 | grep -F "autosaved config"
