ARG DEBIAN_SUITE=trixie
ARG OPENVPN_VERSION=2.6.14-1

# ---------- build (Debian packaging on trixie) ----------
FROM debian:${DEBIAN_SUITE}-slim AS build
ARG DEBIAN_SUITE
ARG OPENVPN_VERSION
ENV DEBIAN_FRONTEND=noninteractive DEB_BUILD_OPTIONS="nodoc nocheck"

# tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    devscripts dpkg-dev quilt ca-certificates wget gnupg build-essential

# enable deb-src (classic format is simplest)
RUN set -eux; cat >/etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian ${DEBIAN_SUITE} main
deb-src http://deb.debian.org/debian ${DEBIAN_SUITE} main
deb http://security.debian.org/debian-security ${DEBIAN_SUITE}-security main
deb-src http://security.debian.org/debian-security ${DEBIAN_SUITE}-security main
deb http://deb.debian.org/debian ${DEBIAN_SUITE}-updates main
deb-src http://deb.debian.org/debian ${DEBIAN_SUITE}-updates main
EOF
    apt-get update; \
    apt-get -y build-dep openvpn

WORKDIR /src
RUN dget -u https://deb.debian.org/debian/pool/main/o/openvpn/openvpn_${OPENVPN_VERSION}.dsc
WORKDIR /src/openvpn-${OPENVPN_VERSION}

# Patch: bump USER_PASS_LEN for very long creds
RUN export QUILT_PATCHES=debian/patches && \
    quilt new long-passlen.patch && \
    quilt add src/openvpn/misc.h && \
    sed -i 's/#define USER_PASS_LEN 128/#define USER_PASS_LEN (1 << 17)/' src/openvpn/misc.h && \
    quilt refresh

# set maintainer info for dch
ENV DEBFULLNAME="Guillaume Filion" \
    DEBEMAIL="guillaume@filion.org" \
    DEBCHANGE_EDITOR="/bin/true"

# bump version: 2.6.14-1 → 2.6.14-1+longpass1
RUN dch -l +longpass1 -D ${DEBIAN_SUITE} -u low \
  "Increase USER_PASS_LEN to support >128-char passwords." \
 && dpkg-parsechangelog -S Version | grep -q '+longpass1'

# Build unsigned binaries (binary packages only)
RUN dpkg-buildpackage -us -uc -b

# ---------- runtime (trixie, dperson UX) ----------
FROM debian:${DEBIAN_SUITE}-slim
ARG DEBIAN_SUITE
MAINTAINER Guillaume Filion <guillaume@filion.org>
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash curl ca-certificates iproute2 iptables tzdata tini \
      libssl3 liblz4-1 liblzo2-2 libpkcs11-helper1 procps psmisc && \
    rm -rf /var/lib/apt/lists/*

# dperson script expects a 'vpn' group; also silence FIB-table noise
RUN groupadd -r vpn \
  && useradd -r -g vpn -s /usr/sbin/nologin vpn \
  && install -d -m 0750 -o root -g vpn /vpn \
  && mkdir -p /etc/iproute2 \
  && { [ -f /etc/iproute2/rt_tables ] || :; } \
  && grep -Eq '^[[:space:]]*200[[:space:]]+vpn$' /etc/iproute2/rt_tables 2>/dev/null \
     || printf '200 vpn\n' >> /etc/iproute2/rt_tables

COPY --from=build /src/openvpn_*_*.deb /tmp/
RUN apt-get update && apt-get install -y /tmp/openvpn_*_*.deb && rm -rf /var/lib/apt/lists/*
# dperson entry script (keep in ./ovpn)
COPY openvpn.sh /openvpn.sh
RUN chmod +x /openvpn.sh
WORKDIR /vpn
ENTRYPOINT ["/usr/bin/tini","--","/openvpn.sh"]
