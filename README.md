# dperson-openvpn-client-longpass (Debian)

Drop-in replacement for [`dperson/openvpn-client`](https://github.com/dperson/openvpn-client) that accepts **username/passwords >128 chars**.  
Built from [Debian’s OpenVPN source](https://tracker.debian.org/pkg/openvpn) with a tiny patch that bumps `USER_PASS_LEN`, packaged as a `.deb`, and run with the original `openvpn.sh` UX. 

> **Why the long password patch?** Some providers (like [**1NCE**](https://help.1nce.com/dev-hub/docs/vpn-service-features-limitations#vpn-client-password-length)) issue JWT-based client passwords that exceed OpenVPN’s stock 127-char limit, which causes `AUTH_FAILED`. This image removes that client-side limit while keeping the familiar dperson workflow.

Every week, a Github action (based on [`utkuozdemir/dperson-openvpn-client`](https://github.com/utkuozdemir/dperson-openvpn-client)) **checks if there's a new version of `openvpn` or the `debian:stable-slim`** image, if so, it builds a new image with the latest versions. This ensures that we're always up to date and **avoid any known security vulnerabilities** without any manual intervention.

---

## Pulling from GitHub Container Registry (GHCR)

Public pull:
```bash
docker pull ghcr.io/gfk/dperson-openvpn-client-longpass:latest
```

Use in `docker-compose.yml`:
```yaml
services:
  openvpn:
    image: ghcr.io/gfk/dperson-openvpn-client-longpass:latest
    cap_add: [NET_ADMIN]
    devices: ["/dev/net/tun"]
    environment:
      - TZ=America/Toronto
    volumes:
      - ./us-west-1-client.conf:/vpn/vpn.conf:ro
      - ./credentials-us-west.txt:/vpn/credentials-us-west.txt:ro
    restart: unless-stopped
```

---

## What’s patched

- **USER_PASS_LEN** limit increased from 128 to ~128KB.
- Debian package version suffix: `2.6.14-1+longpass1` for identification.
- No behavior changes except allowing long credentials.

---

## Local build (if you need it on a platform other than amd64 or arm64)

```yaml
services:
  openvpn:
    build:
      dockerfile: Dockerfile
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

---

## Verifying the patch

Check package version:
```bash
docker run --rm ghcr.io/gfk/dperson-openvpn-client-longpass:latest   bash -lc 'dpkg -s openvpn | grep ^Version'
```

Check OpenVPN version:
```bash
docker run --rm ghcr.io/gfk/dperson-openvpn-client-longpass:latest /usr/sbin/openvpn --version
```

---

## Using the dperson flags (unchanged)

See the [`dperson/openvpn-client`](https://github.com/dperson/openvpn-client) README for the full instructions.

```bash
docker run --rm --cap-add=NET_ADMIN --device /dev/net/tun   -v $PWD/ovpn:/vpn   ghcr.io/gfk/dperson-openvpn-client-longpass:latest   -v 'vpn.server.example;USERNAME;A_very_long_password'   -r 192.168.1.0/24 -f ""
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
- OpenVPN & Debian maintainers
- Motivation: connecting to **1NCE VPN** service with JWT credentials >128 chars

---

## License

[AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.en.html)
