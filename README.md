# openvpn-client-longpass (Debian)

Drop-in replacement for [`dperson/openvpn-client`](https://github.com/dperson/openvpn-client) that accepts **username/passwords >128 chars**.  
Built from **Debian’s OpenVPN source** (`2.6.14-1`) with a tiny patch that bumps `USER_PASS_LEN`, packaged as a `.deb`, and run with the original `openvpn.sh` UX.

> **Why?** Some providers (like [**1NCE**](https://help.1nce.com/dev-hub/docs/vpn-service-features-limitations#vpn-client-password-length)) issue JWT-based client passwords that exceed OpenVPN’s stock 127-char limit, which causes `AUTH_FAILED`. This image removes that client-side limit while keeping the familiar dperson workflow.

---

## Pulling from GitHub Container Registry (GHCR)

Public pull:
```bash
docker pull ghcr.io/gfk/openvpn-client-longpass:latest
```

Use in `docker-compose.yml`:
```yaml
services:
  openvpn:
    image: ghcr.io/gfk/openvpn-client-longpass:latest
    cap_add: [NET_ADMIN]
    devices: ["/dev/net/tun"]
    environment:
      - TZ=America/Toronto
    volumes:
      - ./ovpn/us-west-1-client.conf:/vpn/vpn.conf:ro
      - ./ovpn/credentials-us-west.txt:/vpn/credentials-us-west.txt:ro
    restart: unless-stopped
```

---

## What’s patched

- **USER_PASS_LEN** limit increased from 128 to ~128KB.
- Debian package version suffix: `2.6.14-1+longpass1` for identification.
- No behavior changes except allowing long credentials.

---

## Image at a glance

- Base: `debian:trixie-slim`
- OpenVPN: `2.6.14-1+longpass1` (Debian packaged, patched)
- Entrypoint: original `openvpn.sh` from `dperson/openvpn-client`
- Extras:
  - `procps` (`ps`)
  - `psmisc` (`killall`)
  - `vpn` group for `sg vpn -c`
  - `rt_tables` entry `200 vpn` to silence FIB warnings

Requires: `--cap-add=NET_ADMIN` and `/dev/net/tun`.

---

## Quick start (local build)

```yaml
services:
  openvpn:
    build:
      context: ./ovpn
      dockerfile: Dockerfile
    image: local/openvpn-client-longpass:latest
    cap_add: [NET_ADMIN]
    devices: ["/dev/net/tun"]
    environment:
      - TZ=America/Toronto
    volumes:
      - ./ovpn/us-west-1-client.conf:/vpn/vpn.conf:ro
      - ./ovpn/credentials-us-west.txt:/vpn/credentials-us-west.txt:ro
    restart: unless-stopped
```

---

## Verifying the patch

Check package version:
```bash
docker run --rm ghcr.io/gfk/openvpn-client-longpass:latest   bash -lc 'dpkg -s openvpn | grep ^Version'
```

Check OpenVPN version:
```bash
docker run --rm ghcr.io/gfk/openvpn-client-longpass:latest /usr/sbin/openvpn --version
```

---

## Using the dperson flags (unchanged)

```bash
docker run --rm --cap-add=NET_ADMIN --device /dev/net/tun   -v $PWD/ovpn:/vpn   ghcr.io/gfk/openvpn-client-longpass:latest   -v 'vpn.server.example;USERNAME;A_very_long_password'   -r 192.168.1.0/24 -f ""
```

---

## Security notes

- Requires `NET_ADMIN` + `/dev/net/tun`.
- Runs via `sg vpn` group drop.
- Mount only what you need into `/vpn` (use `:ro`).

---

## Credits

- [`dperson/openvpn-client`](https://github.com/dperson/openvpn-client) for base UX
- OpenVPN & Debian maintainers
- Motivation: connecting to **1NCE VPN** service with JWT credentials >128 chars

---

## License

[AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.en.html)
