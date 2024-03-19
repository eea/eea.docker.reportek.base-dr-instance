FROM eeacms/zope:2.13.30
MAINTAINER "EEA: IDM2 C-TEAM" <eea-edw-c-team-alerts@googlegroups.com>

ENV LOCAL_CONVERTERS_HOST=converter

USER root
COPY src/*                      $ZOPE_HOME/
COPY zope-setup.sh              \
     docker-entrypoint.sh       \
     docker-initialize.py       /

RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list \
 && buildDeps="gcc g++" \
 && runDeps="gosu libjpeg62 libopenjp2-7 libtiff5 libxml2 libxslt1.1 libssl1.1="1.1.0l-1~deb9u1" lynx netcat poppler-utils rsync wv git-core libsasl2-dev python-dev libldap2-dev libssl-dev curl iputils-ping iproute2 vim cron netcat-openbsd sudo procps openssh-client" \
 && apt-get update \
 && apt-get install -y --no-install-recommends $buildDeps \
 && apt-get install -y --no-install-recommends --allow-downgrades $runDeps \
 && apt-get install -y --no-install-recommends build-essential \
 && echo "zope-www ALL = NOPASSWD: /etc/init.d/cron"  > /etc/sudoers \
 && pip install python-ldap==2.4.38 PasteDeploy==2.1.1 pathlib==1.0.1 python-dateutil \
 && cd $ZOPE_HOME && ./install.sh \
 && chown -R 500:500 $ZOPE_HOME \
 && cd $ZOPE_HOME \
 && gosu zope-www buildout -c devel.cfg \
 && apt-get purge -y --auto-remove $buildDeps \
 && rm -rf /var/lib/apt/lists/* \
 && gosu zope-www python /docker-initialize.py




