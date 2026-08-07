FROM eeacms/zope:2.13.30

ENV LOCAL_CONVERTERS_HOST=converter

ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

USER root
COPY src/*                      $ZOPE_HOME/
COPY zope-setup.sh              \
    debug.sh                   \
    docker-entrypoint.sh       \
    docker-initialize.py       /

RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list \
    && buildDeps="gcc g++" \
    && runDeps="gosu libjpeg62 libopenjp2-7 libtiff5 libxml2 libxslt1.1 libssl1.1="1.1.0l-1~deb9u1" lynx netcat poppler-utils rsync wv git-core libsasl2-dev python-dev libldap2-dev libssl-dev curl iputils-ping iproute2 vim cron netcat-openbsd sudo procps openssh-client" \
    && apt-get update \
    && apt-get install -y --no-install-recommends $buildDeps \
    && apt-get install -y --no-install-recommends --allow-downgrades $runDeps \
    && CA_DEB=ca-certificates_20260601_all.deb \
    && curl -fsSLo /tmp/$CA_DEB "http://snapshot.debian.org/archive/debian/20260601T202527Z/pool/main/c/ca-certificates/$CA_DEB" \
    && echo "3269df8178f5402093a57c754810f8ce59e1a0cf9361aa72252bf3186cfc32d7  /tmp/$CA_DEB" | sha256sum -c - \
    && dpkg-deb -x /tmp/$CA_DEB /tmp/ca-new \
    && rm -rf /usr/share/ca-certificates/mozilla \
    && cp -r /tmp/ca-new/usr/share/ca-certificates/mozilla /usr/share/ca-certificates/ \
    && (cd /usr/share/ca-certificates && find . -name '*.crt' | sed 's|^\./||' | sort) > /etc/ca-certificates.conf \
    && update-ca-certificates --fresh \
    && rm -rf /tmp/$CA_DEB /tmp/ca-new \
    && echo "zope-www ALL = NOPASSWD: /etc/init.d/cron"  > /etc/sudoers \
    && pip install python-ldap==2.4.38 PasteDeploy==2.1.1 pathlib==1.0.1 python-dateutil Paste==3.6.1 \
    && cd $ZOPE_HOME && ./install.sh \
    && chown -R 500:500 $ZOPE_HOME \
    && apt-get purge -y --auto-remove $buildDeps \
    && rm -rf /var/lib/apt/lists/*

USER zope-www
