FROM ubuntu:24.04

ARG DEBIAN_FRONTEND="noninteractive"
ARG GE_PROTON_VERSION="11-11"

ENV WINEDLLPATH=/opt/ge-proton/files/lib/vkd3d:/opt/ge-proton/files/lib/wine

RUN userdel ubuntu && useradd -m -u 1000 steam && \
    echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note '' | debconf-set-selections && \
    dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends wget ca-certificates steamcmd libfreetype6 libgssapi-krb5-2 && \
    cd /tmp && \
    wget https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${GE_PROTON_VERSION}/GE-Proton${GE_PROTON_VERSION}-x86_64.tar.gz \
         https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${GE_PROTON_VERSION}/GE-Proton${GE_PROTON_VERSION}-x86_64.sha512sum && \
    sha512sum -c GE-Proton${GE_PROTON_VERSION}-x86_64.sha512sum && \
    mkdir /opt/ge-proton && \
    tar -xzf GE-Proton${GE_PROTON_VERSION}-x86_64.tar.gz -C /opt/ge-proton --strip-components=1 \
        --exclude=files/share/wine/mono --exclude=files/share/wine/gecko && \
    ln -s /opt/ge-proton/files/bin/wine /opt/ge-proton/files/bin/wineserver /usr/local/bin/ && \
    mkdir /wineprefix-template && chown steam:steam /wineprefix-template && \
    runuser -l steam -c "export WINEPREFIX=/wineprefix-template WINEARCH=wow64 WINEDLLPATH=$WINEDLLPATH; wine wineboot --init && wineserver -w" && \
    test -s /wineprefix-template/system.reg && test -s /wineprefix-template/user.reg && \
    find /wineprefix-template -type f | while read -r f; do \
        for d in /opt/ge-proton/files/lib/wine/x86_64-windows /opt/ge-proton/files/lib/wine/i386-windows \
                 /opt/ge-proton/files/lib/vkd3d/x86_64-windows /opt/ge-proton/files/lib/vkd3d/i386-windows \
                 /opt/ge-proton/files/share/wine/nls /opt/ge-proton/files/share/wine; do \
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

ENV WINEFSYNC=1
ENV PROTON_DISABLE_LSTEAMCLIENT=1

VOLUME /server
VOLUME /wineprefix-volume

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
