FROM eeacms/zope:2.13.22
MAINTAINER "Olimpiu Rob" <olimpiu.rob@eaudeweb.ro>

#ENV EVENT_LOG_LEVEL=INFO \
#    Z2_LOG_LEVEL=INFO \
#    ZEO_CLIENT=true \
#    ZEO_ADDRESS=zeoserver:8100 \
#    ZSERVER_THREADS=4 \
#    BLOB_CACHE_SIZE=500000000 \
ENV SETUPTOOLS=28.6.0 \
    ZCBUILDOUT=2.5.3 \
    LOCAL_CONVERTERS_HOST=converter

USER root
COPY src/*    $ZOPE_HOME/
RUN mv /docker-entrypoint.sh    /zope-entrypoint.sh
COPY docker-entrypoint.sh       \
     docker-initialize.py       /

RUN ./install.sh              \
    chown -R 500:500 $ZOPE_HOME

USER zope-www
