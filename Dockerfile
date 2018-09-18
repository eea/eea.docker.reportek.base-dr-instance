FROM eeacms/zope:2.13.28
MAINTAINER "EEA: IDM2 C-TEAM" <eea-edw-c-team-alerts@googlegroups.com>

ENV LOCAL_CONVERTERS_HOST=converter

USER root
COPY src/*                      $ZOPE_HOME/
COPY zope-setup.sh              \
     docker-initialize.py       /

RUN buildDeps="gcc" \
 && runDeps="gosu libjpeg62 libopenjp2-7 libtiff5 libxml2 libxslt1.1 lynx netcat poppler-utils rsync wv git-core libsasl2-dev python-dev libldap2-dev libssl-dev" \
 && apt-get update \
 && apt-get install -y --no-install-recommends $buildDeps \
 && apt-get install -y --no-install-recommends $runDeps \
 && pip install python-ldap==2.4.38 \
 && cd $ZOPE_HOME && ./install.sh \
 && chown -R 500:500 $ZOPE_HOME \
 && apt-get purge -y --auto-remove $buildDeps \
 && rm -rf /var/lib/apt/lists/*

USER zope-www
