FROM ubuntu:24.04

ARG DEBIAN_FRONTEND="noninteractive"

RUN userdel ubuntu && useradd -m -u 1000 steam && \
    echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note '' | debconf-set-selections && \
    apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends wget ca-certificates && \
    dpkg --add-architecture i386 && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends steamcmd wine-devel-amd64 && \
    cd /tmp && \
    apt-get download wine-devel=$(dpkg-query -Wf '${Version}' wine-devel-amd64) winehq-devel=$(dpkg-query -Wf '${Version}' wine-devel-amd64) && \
    dpkg-deb -x wine-devel_*.deb / && dpkg-deb -x winehq-devel_*.deb / && \
    mkdir /wineprefix-template && chown steam:steam /wineprefix-template && \
    runuser -l steam -c "export WINEPREFIX=/wineprefix-template; wineboot --init && wineserver -w" && \
    test -s /wineprefix-template/system.reg && test -s /wineprefix-template/user.reg && \
    find /wineprefix-template -type f | while read -r f; do \
        for d in /opt/wine-devel/lib/wine/x86_64-windows /opt/wine-devel/share/wine/nls /opt/wine-devel/share/wine; do \
            t="$d/$(basename "$f")"; \
            if [ -f "$t" ] && cmp -s "$f" "$t"; then ln -f "$t" "$f"; break; fi; \
        done; \
    done && \
    apt-get remove -y --purge wget && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /home/steam/.cache

RUN date -u +%Y%m%dT%H%M%SZ > /wineprefix-template/.timestamp

RUN ln -s /usr/games/steamcmd /usr/bin/steamcmd

VOLUME /server
VOLUME /wineprefix-volume

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
