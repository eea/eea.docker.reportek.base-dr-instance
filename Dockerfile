FROM eeacms/zope:2.13.22
MAINTAINER "Olimpiu Rob" <olimpiu.rob@eaudeweb.ro>

ENV EVENT_LOG_LEVEL=INFO \
    Z2_LOG_LEVEL=INFO \
    ZEO_CLIENT=true \
    ZEO_ADDRESS=zeoserver:8100 \
    BLOB_CACHE_SIZE=500000000 \
    LOCAL_CONVERTERS_HOST=converter

COPY src/versions.cfg           $ZOPE_HOME/
COPY src/sources.cfg            $ZOPE_HOME/
COPY src/dr-instance.cfg        $ZOPE_HOME/
COPY src/base.cfg               $ZOPE_HOME/

USER root
RUN ./install.sh && chown -R 500:500 $ZOPE_HOME
USER zope-www
