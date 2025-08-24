
# dperson-openvpn-client-longpass

Drop-in replacement for [`dperson/openvpn-client`](https://github.com/dperson/openvpn-client) that accepts **username/passwords >128 chars**.  
Built from either Debian’s or Alpine’s OpenVPN sources with a tiny patch that bumps `USER_PASS_LEN`, packaged as `.deb` or direct Alpine build, and run with the original `openvpn.sh` UX.

### Why would I need this?

You might need passwords longer than 128 characters if you’re using a VPN provider or identity system that relies on **JWT tokens** (from SAML or OIDC logins) instead of static credentials.  
Well-known cases include:

- **AWS Client VPN** – SAML/OIDC identity federation returns long JWTs  
- **Microsoft Azure VPN (OpenVPN protocol)** – Azure AD tokens often exceed 127 chars  
- **Google Cloud integrations** with OpenVPN through OIDC/IAP  
- [**1NCE IoT VPN service**](https://help.1nce.com/dev-hub/docs/vpn-service-features-limitations#vpn-client-password-length) – issues JWTs as client credentials  
- **Okta, Auth0, Keycloak, ADFS, PingIdentity, etc.** when hooked into OpenVPN  
- **OpenVPN Access Server** configured with SAML/OIDC (e.g. Google Workspace, Azure AD)  
- **Enterprise VPNs** that integrate with external IdPs

If your provider is giving you an `AUTH_FAILED` and your credentials look like a long block of base64 or JWT (`eyJhbGciOi...`), you’re very likely hitting the stock OpenVPN 127-char limit.

### Nightly build if there's an upgrade from upstream

Every night, a Github action (based on [`utkuozdemir/dperson-openvpn-client`](https://github.com/utkuozdemir/dperson-openvpn-client)) **checks if there's a new version of `openvpn` or the base image**, if so, it builds a new image with the latest versions. This ensures that we're always up to date and **avoid any known security vulnerabilities** without any manual intervention.

---

## Available Variants

We now publish **two flavors** of this image:

- **Alpine-based (~19MB)**  
  `ghcr.io/gfk/dperson-openvpn-client-longpass-alpine:latest`  
  Built from [Alpine’s OpenVPN package sources](https://pkgs.alpinelinux.org/package/v3.22/main/x86_64/openvpn).  
  Best choice if you want a **smaller footprint** and faster startup, with a minimal busybox environment.

- **Debian-based (~139MB)**  
  `ghcr.io/gfk/dperson-openvpn-client-longpass-debian:latest`  
  Built from the [Debian OpenVPN source package](https://tracker.debian.org/pkg/openvpn).  
  Best choice if you prefer Debian’s packaging, stability, and security updates, or want to modify the setup.

Both versions behave identically from the user’s perspective — the only difference is the underlying base distribution and package source.

---

## Pulling from GitHub Container Registry (GHCR)

Both images are compiled for **`amd64`** and **`arm64`**.

Alpine:
```bash
docker pull ghcr.io/gfk/dperson-openvpn-client-longpass-alpine:latest
```

Debian:
```bash
docker pull ghcr.io/gfk/dperson-openvpn-client-longpass-debian:latest
```

Use in `docker-compose.yml` (example with Debian):
```yaml
services:
  openvpn:
    image: ghcr.io/gfk/dperson-openvpn-client-longpass-debian:latest
    cap_add: [NET_ADMIN]
    devices: ["/dev/net/tun"]
    environment:
      - TZ=America/Toronto
    volumes:
      - ./us-west-1-client.conf:/vpn/vpn.conf:ro
      - ./credentials-us-west.txt:/vpn/credentials-us-west.txt:ro
    restart: unless-stopped
```

Switch `...-debian:latest` to `...-alpine:latest` if you want the Alpine variant.

---

## What’s patched

- **USER_PASS_LEN** limit increased from 128 to ~128KB.
- OpenVPN includes version suffix: `longpass1` for identification.
- No behavior changes except allowing long credentials.

---

## Local build (if you need it on a platform other than amd64 or arm64)

```yaml
services:
  openvpn:
    build:
      dockerfile: Dockerfile.alpine
    image: local/dperson-openvpn-client-longpass:latest
    cap_add: [NET_ADMIN]
    devices: ["/dev/net/tun"]
    environment:
      - TZ=America/Toronto
    volumes:
      - ./us-west-1-client.conf:/vpn/vpn.conf:ro
      - ./credentials-us-west.txt:/vpn/credentials-us-west.txt:ro
    restart: unless-stopped
```

For Alpine, specify `Dockerfile.alpine`. For Debian, use `Dockerfile.debian`.

---

## Verifying the patch

Check package version (Debian only):
```bash
docker run --rm ghcr.io/gfk/dperson-openvpn-client-longpass-debian:latest   bash -lc 'dpkg -s openvpn | grep ^Version'
```

Check OpenVPN version (both):
```bash
docker run --rm ghcr.io/gfk/dperson-openvpn-client-longpass-alpine:latest /usr/sbin/openvpn --version
docker run --rm ghcr.io/gfk/dperson-openvpn-client-longpass-debian:latest /usr/sbin/openvpn --version
```

---

## Using the dperson flags (unchanged)

See the [`dperson/openvpn-client`](https://github.com/dperson/openvpn-client) README for the full instructions.

```bash
docker run --rm --cap-add=NET_ADMIN --device /dev/net/tun   -v $PWD/ovpn:/vpn   ghcr.io/gfk/dperson-openvpn-client-longpass-debian:latest   -v 'vpn.server.example;USERNAME;A_very_long_password'   -r 192.168.1.0/24 -f ""
```

---

## Security notes

- Requires `NET_ADMIN` + `/dev/net/tun`.
- Runs via `sg vpn` group drop.
- Mount only what you need into `/vpn` (use `:ro`).

---

## Credits

- [`dperson/openvpn-client`](https://github.com/dperson/openvpn-client) for base UX
- [`utkuozdemir/dperson-openvpn-client`](https://github.com/utkuozdemir/dperson-openvpn-client) for the inspiration about the automated build with the latest versions 
- OpenVPN & Debian/Alpine maintainers
- Motivation: connecting to **1NCE VPN** service with JWT credentials >128 chars

---

## License

[AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.en.html)
