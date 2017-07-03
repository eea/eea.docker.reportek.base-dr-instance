#!/bin/bash
set -e

COMMANDS="debug help logtail show stop adduser fg kill quit run wait console foreground logreopen reload shell status"
START="start restart"
CMD="bin/instance"
WSGI_CMD="bin/paster serve etc/zope.wsgi"
SETUPCMD="/zope-setup.sh"

if [ -z "$HTTP_SERVER" ]; then
  HTTP_SERVER="zserver"
fi

if [ -z "$HEALTH_CHECK_TIMEOUT" ]; then
  HEALTH_CHECK_TIMEOUT=1
fi

if [ -z "$HEALTH_CHECK_INTERVAL" ]; then
  HEALTH_CHECK_INTERVAL=1
fi

$SETUPCMD

if [[ $START == *"$1"* ]]; then
  if [ ! -z $DEBUG ]; then
    if [[ $DEBUG == *on* ]]; then
      export HTTP_SERVER="zserver"
      . $SETUPCMD
      exec $CMD fg
    fi
  else
    _stop() {
      if [[ $HTTP_SERVER == *wsgi* ]]; then
        $WSGI_CMD stop
      else
        $CMD stop
      fi
      kill -TERM $child 2>/dev/null
    }

    trap _stop SIGTERM SIGINT
    if [[ $HTTP_SERVER == *wsgi* ]]; then
      $WSGI_CMD start
    else
      $CMD start
    fi

    child=$!

    if [[ $HTTP_SERVER == *wsgi* ]]; then
      for i in {1..5}; do
        sleep 1
        printf "."
        pid=`cat paster.pid`
        if [ -n "$pid" ]; then
          break
        fi
      done
    else
      pid=`$CMD status | sed 's/[^0-9]*//g'`
    fi
    
    if [ ! -z "$pid" ]; then
      echo "Application running on pid=$pid"
      sleep "$HEALTH_CHECK_TIMEOUT"
      while kill -0 "$pid" 2> /dev/null; do
        sleep "$HEALTH_CHECK_INTERVAL"
      done
    else
      echo "Application didn't start normally. Shutting down!"
      _stop
    fi
  fi
else
  if [[ $COMMANDS == *"$1"* ]]; then
    export HTTP_SERVER="zserver"
    . $SETUPCMD
    exec $CMD "$@"
  fi
  exec "$@"
fi
