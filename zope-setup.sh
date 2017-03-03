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

for i in $(sed -n '/<logfile/,/<\/logfile/p' parts/instance/etc/zope.conf | sed -n '/.path /{s/.*path //;p;}');
    do ln -sf $PID1_STDOUT $i;
done
