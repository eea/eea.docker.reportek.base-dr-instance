#FROM eeacms/reportek-base-dr
FROM basedr
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -vrf /var/lib/apt/lists/* \
 && cd $ZOPE_HOME \
 && gosu zope-www buildout -c devel.cfg \
 && gosu zope-www python /docker-initialize.py
