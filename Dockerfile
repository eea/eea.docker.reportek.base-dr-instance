FROM eeacms/zope:2.13.22
MAINTAINER "Olimpiu Rob" <olimpiu.rob@eaudeweb.ro>

ENV SETUPTOOLS=28.6.0 \
    ZCBUILDOUT=2.5.3 \
    LOCAL_CONVERTERS_HOST=converter

USER root
COPY src/*                      $ZOPE_HOME/
COPY zope-setup.sh              \
     docker-initialize.py       /

RUN ./install.sh              \
    chown -R 500:500 $ZOPE_HOME

USER zope-www
