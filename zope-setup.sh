#!/bin/bash
set -e

LAST_CFG=`python /last-built-cfg.py`
PID1_STDOUT=/proc/1/fd/1

python /docker-initialize.py

# Avoid running buildout on docker start
if [[ "$LAST_CFG" == *base.cfg ]]; then
  if ! test -e $ZOPE_HOME/buildout.cfg; then
    python /configure.py
  fi

  if test -e $ZOPE_HOME/buildout.cfg; then
    ./bin/buildout -c buildout.cfg
    python /docker-initialize.py
  fi
fi

# If the HTTP_SERVER is wsgi remove the <http-server></http-server> block
if [[ $HTTP_SERVER == *wsgi* ]]; then
  sed -i '/<http-server/,/<\/http-server/d' parts/instance/etc/zope.conf
else
  if [[ $(sed -n '/<http-server/,/<\/http-server/p' parts/instance/etc/zope.conf | wc -c) -eq 0 ]]; then
    HTTP_ADDRESS=`grep http-address .installed.cfg | cut -d'=' -f2`
    echo "
      <http-server>
        address ${HTTP_ADDRESS}
      </http-server>
    " >> parts/instance/etc/zope.conf
  fi
fi

for i in $(sed -n '/<logfile/,/<\/logfile/p' parts/instance/etc/zope.conf | sed -n '/.path /{s/.*path //;p;}');
    do ln -sf $PID1_STDOUT $i;
done
