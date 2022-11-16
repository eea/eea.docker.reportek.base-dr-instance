#!/bin/bash
set -e

COMMANDS="debug help logtail show stop adduser fg kill quit run wait console foreground logreopen reload shell status"
CRONJOB="cronjob"
COVERAGE="coverage"
START="start restart"
CMD="bin/instance"
SETUPCMD="/zope-setup.sh"

$SETUPCMD

if [ -z "$HEALTH_CHECK_TIMEOUT" ]; then
  HEALTH_CHECK_TIMEOUT=1
fi

if [ -z "$HEALTH_CHECK_INTERVAL" ]; then
  HEALTH_CHECK_INTERVAL=1
fi

if [[ $START == *"$1"* ]]; then
  if [ ! -z $DEBUG ]; then
    if [[ $DEBUG == *on* ]]; then
      exec $CMD fg
    fi
  else
    _stop() {
      $CMD stop
      kill -TERM $child 2>/dev/null
    }

    trap _stop SIGTERM SIGINT
    $CMD start

    child=$!
    pid=`$CMD status | sed 's/[^0-9]*//g'`
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
    exec $CMD "$@"
  elif [[ $CRONJOB == *"$1"* && ! -z $CRONTAB ]]; then
    /usr/bin/printenv > /tmp/crontab
    echo "$CRONTAB" >> /tmp/crontab
    # start netcat to keep the healthchecker happy
    nc -lkp 8080 &>/dev/null &
    crontab /tmp/crontab
    sudo /etc/init.d/cron start
    tail -f /dev/null
  else
    exec "$@"
  fi
fi
