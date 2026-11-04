# caddy-infomaniak

[![Release](https://github.com/vecluu/caddy-infomaniak/actions/workflows/release.yml/badge.svg)](https://github.com/vecluu/caddy-infomaniak/actions/workflows/release.yml)
[![Caddy](https://img.shields.io/github/v/release/vecluu/caddy-infomaniak?sort=semver&label=caddy)](https://github.com/vecluu/caddy-infomaniak/releases/latest)
[![Image](https://img.shields.io/badge/image-ghcr.io-blue?logo=github)](https://github.com/vecluu/caddy-infomaniak/pkgs/container/caddy-infomaniak)
![Platforms](https://img.shields.io/badge/platforms-amd64%20%7C%20arm64-blue)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

A distroless [Caddy](https://caddyserver.com) image with the [Infomaniak DNS plugin](https://github.com/caddy-dns/infomaniak), for issuing certificates through ACME DNS challenges. This covers wildcard certificates and hosts that aren't reachable from the internet.

New Caddy releases are picked up, built, tested and published automatically after a 24-hour cooldown.

- **Platforms:** `linux/amd64`, `linux/arm64`
- **Tags:** `latest`, `<major>`, `<major>.<minor>`, `<major>.<minor>.<patch>` (for example `2`, `2.11`, `2.11.8`)
- **Runs as:** `nonroot` (UID 65532) by default, with no shell or package manager

## Usage

The image needs an Infomaniak API token, created in the [Infomaniak manager](https://manager.infomaniak.com/v3/infomaniak-api), with the scopes `domain:read`, `dns:read` and `dns:write`.

`Caddyfile`:

```caddyfile
{
	email admin@example.com
	acme_dns infomaniak {env.INFOMANIAK_API_TOKEN}
}

example.com, *.example.com {
	respond "hello"
}
```

`compose.yaml`:

```yaml
services:
  caddy:
    image: ghcr.io/vecluu/caddy-infomaniak:2
    restart: unless-stopped
    read_only: true
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
    environment:
      INFOMANIAK_API_TOKEN: ${INFOMANIAK_API_TOKEN}
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
```

`/data` must be on a persistent volume, because it holds the certificates and the ACME account.

### Notes

- **Running as another user:** set `user: "1000:1000"` in Compose, or pass `--user 1000:1000` to `docker run`. Any UID and GID work, and new named volumes need no setup. A volume already used by another UID must be chowned to the new one first. `PUID`/`PGID` variables aren't supported, because the image has no shell or root entrypoint to apply them.
- **Volume permissions:** `/config` and `/data` are mode `1777` in the image so that any UID can use a new named volume. Caddy keeps everything inside them private to its own UID (directories `0700`, files `0600`).
- **Bind mounts:** a host directory used for `/data` or `/config` must be writable by the UID the container runs as (`chown -R 65532:65532 ./data` for the default user).
- **Ports 80 and 443:** the binary has no file capabilities, so it can run with `cap_drop: ALL`. Docker allows low ports by default. Podman needs `--sysctl net.ipv4.ip_unprivileged_port_start=0`. With `network_mode: host`, the host's own setting applies, so either listen above port 1023 or change that sysctl on the host.
- **Debugging:** the image has no shell, so `docker exec -it caddy sh` doesn't work. Caddy's own commands do, such as `docker exec caddy caddy list-modules`.
- **Wildcard CNAME records:** a wildcard CNAME that matches `_acme-challenge` names makes Caddy's propagation check follow it and time out. Either remove the record or add `propagation_delay 2m` and `propagation_timeout -1` to the `tls` block, next to the `dns` line.

## How releases work

[`.github/workflows/release.yml`](.github/workflows/release.yml) runs every 6 hours:

1. Compares the latest stable Caddy release with `CADDY_VERSION` in the [`Dockerfile`](Dockerfile).
2. If there's a newer version, checks that the official `caddy:<version>-builder` image has been on Docker Hub for at least 24 hours. Until then, nothing is built and a later run checks again. A re-pushed image restarts the 24 hours.
3. Builds the image and smoke tests it with [`test/smoke.sh`](test/smoke.sh): exact Caddy and plugin versions, and a DNS challenge config that passes `caddy validate`.
4. Pushes both architectures to GHCR, with an SBOM and provenance.
5. Commits the version bump and creates a GitHub release.

## How plugin updates work

The plugin version is pinned by `INFOMANIAK_VERSION` in the `Dockerfile`, so a new plugin version never ships without review.

[`.github/workflows/plugin-update.yml`](.github/workflows/plugin-update.yml) runs daily. When the plugin has a new tag, it builds and smoke tests the image, then opens a pull request linking to the upstream changes.

Merging the pull request triggers a rebuild of the current Caddy version, which replaces the existing image tags.

## License

The files in this repository are licensed under the [Apache License 2.0](LICENSE). The software inside the image, including Caddy, the plugin and the base image, keeps its own licenses.

Not affiliated with or endorsed by the Caddy project. Caddy is a registered trademark of Stack Holdings GmbH.
