#!/bin/bash
set -e
python /docker-initialize.py
exec /zope-entrypoint.sh "$@"
