FROM eeacms/zope:2.13.26-1.0
MAINTAINER "EEA: IDM2 C-TEAM" <eea-edw-c-team-alerts@googlegroups.com>

ENV SETUPTOOLS=28.6.0 \
    ZCBUILDOUT=2.5.3 \
    LOCAL_CONVERTERS_HOST=converter

USER root
COPY src/*                      $ZOPE_HOME/
COPY zope-setup.sh              \
     docker-entrypoint.sh       \
     docker-initialize.py       /

RUN ./install.sh              \
    chown -R 500:500 $ZOPE_HOME

USER zope-www
