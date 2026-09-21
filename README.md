
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
A nightly rebuild can only ship what the distribution has already published, though — the [July 2026 case study](#case-study-debian-vs-alpine-security-response-july-2026) shows what that looks like when a distribution is slow.

---

## Available Variants

We now publish **two flavors** of this image:

- **Alpine-based (~19MB)**  
  `ghcr.io/gfk/dperson-openvpn-client-longpass-alpine:latest`  
  Built from [Alpine’s OpenVPN package sources](https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/openvpn).  
  Best choice if you want a **smaller footprint** and faster startup, a more recent openvpn version, with a minimal busybox environment.  
  Be aware that Alpine security fixes can take noticeably longer to land than Debian’s — see the [July 2026 case study](#case-study-debian-vs-alpine-security-response-july-2026).

- **Debian-based (~119MB)**  
  `ghcr.io/gfk/dperson-openvpn-client-longpass-debian:latest`  
  Built from the [Debian OpenVPN source package](https://tracker.debian.org/pkg/openvpn).  
  Best choice if you prefer Debian’s packaging, stability, [more frequent and systematic security updates](#case-study-debian-vs-alpine-security-response-july-2026), or want to modify the setup.

Both versions behave identically from the user’s perspective — the only difference is the underlying base distribution and package source.

---

## Case study: Debian vs Alpine security response (July 2026)

### The vulnerabilities

On **1 July 2026** the OpenVPN project announced
[2.6.21](https://github.com/OpenVPN/openvpn/releases/tag/v2.6.21) and
[2.7.5](https://github.com/OpenVPN/openvpn/releases/tag/v2.7.5)
(see the [release history](https://community.openvpn.net/ReleaseHistory#openvpn-2621-released-1-july-2026);
the GitHub tags were published on 2 July). Between them they fix **six CVEs**:

| CVE | Issue |
|---|---|
| [CVE-2026-12996](https://security-tracker.debian.org/tracker/CVE-2026-12996) | Use-after-free in `ack_write_buf()`, reachable from control-channel and authentication packets |
| [CVE-2026-13117](https://security-tracker.debian.org/tracker/CVE-2026-13117) | Use-after-free in `tls_wrap_reneg()`, reachable from dynamic `tls-crypt` control-channel packets |
| [CVE-2026-13122](https://security-tracker.debian.org/tracker/CVE-2026-13122) | Crash on a malformed `auth-token` when `external-auth` is enabled |
| [CVE-2026-12932](https://security-tracker.debian.org/tracker/CVE-2026-12932) | Memory leak in `tls-crypt-v2` client key handling, leading to OOM |
| [CVE-2026-11771](https://security-tracker.debian.org/tracker/CVE-2026-11771) | 1-byte buffer overrun on NTLMv2 proxy responses |
| [CVE-2026-13698](https://security-tracker.debian.org/tracker/CVE-2026-13698) | Memory leak on reception of `tls-crypt-v2` packets, causing OOM and crashes |

To be fair to Alpine: several of these are primarily *server*-side denial of
service, so a client-only image like this one is less exposed than an OpenVPN
server would be. The point of the case study is not the severity — it is **how
long each distribution took to ship a fix at all**.

### The timeline

| Date (July 2026) | Debian | Alpine |
|---|---|---|
| **1st** | [OpenVPN 2.6.21](https://github.com/OpenVPN/openvpn/releases/tag/v2.6.21) released, fixing six CVEs | [OpenVPN 2.7.5](https://github.com/OpenVPN/openvpn/releases/tag/v2.7.5) released, fixing the same six CVEs |
| **3rd** | [DSA-6376-1](https://lists.debian.org/debian-security-announce/2026/msg00287.html) — `openvpn 2.6.14-1+deb13u3`, all six CVEs backported into *trixie*. **2 days after release.** | [aports issue #18308](https://gitlab.alpinelinux.org/alpine/aports/-/work_items/18308) opened, asking someone to upgrade the package to 2.7.5 |
| **4th** | nightly rebuild → patched image available on `docker pull` | |
| **5th–12th** | | |
| **13th** | | aports commit [`f84ec99`](https://github.com/alpinelinux/aports/commit/f84ec990) — `pkgver` bumped to 2.7.5 on `3.24-stable`. **12 days after release.** |
| **14th** | | nightly rebuild → patched image available on `docker pull` |
| **Total, upstream → your machine** | **~3 days** | **~13 days** |

The empty cells are the point. After 4 July Debian had nothing left to do, while
Alpine users waited another nine days. For those ten days the Alpine variant of
this image shipped a known-vulnerable OpenVPN and the Debian variant did not.
Our pipeline behaved identically in both cases — it rebuilt the night the
package changed — so the whole difference happened upstream of us.

### Why the two distributions behave so differently

- **Debian backports fixes into the frozen version.** A Debian stable release
  pins an upstream version for its whole life and the security team applies
  individual patches on top of it. That is why *trixie* still calls its package
  `2.6.14` while carrying fixes released in July 2026. A dedicated security
  team, a published advisory feed (DSA), and a `-security` suite that every
  Debian install already has enabled make the process **systematic**: the
  advisory and the fixed package land together, for every supported release.
- **Alpine ships version bumps.** An Alpine fix is usually a `pkgver` bump in
  `aports`, done by whoever maintains the package, and it moves at the speed of
  that one person. There is no dedicated security team and no per-package
  advisory stream comparable to DSA to hold the process to a schedule.

### Two lessons worth taking away

1. **A nightly rebuild only helps if the distribution has published a fix.**
   Our pipeline did its job in both cases — it rebuilt the night the package
   changed, and the image was pullable the next morning. Rebuilding nightly
   shortens *your* half of the delay; it cannot shorten the distribution’s.
   “Latest image” is not the same as “patched”.
2. **A higher version number is not a proxy for patch level.** Between 3 and 13
   July, Alpine 3.24 carried `openvpn 2.7.3` and Debian *trixie* carried
   `2.6.14-1+deb13u3`. The lower-looking number was the patched one. On Debian,
   the `+deb13uN` suffix is the part that tells you about security backports —
   check it, not the upstream version:

   ```bash
   docker run --rm ghcr.io/gfk/dperson-openvpn-client-longpass-debian:latest \
     bash -lc 'dpkg -s openvpn | grep ^Version'
   ```

   Current state of both sources is public:
   [Debian security tracker](https://security-tracker.debian.org/tracker/source-package/openvpn)
   ·
   [Alpine package](https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/openvpn)

None of this makes Alpine a bad base image — it is smaller, and its current
stable branch tracks the 2.7 series that upstream now develops on. But if
predictable, documented security maintenance is what you are optimizing for,
**use the Debian variant**.

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
