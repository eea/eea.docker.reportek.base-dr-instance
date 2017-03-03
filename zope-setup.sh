#!/bin/bash
set -e
exec /zope-config.sh
python /docker-initialize.py
