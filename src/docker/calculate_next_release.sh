#!/bin/bash
# Next release version: <Zope minor>-<N>, ex: 5.14-3
# The Zope minor is read from requirements.txt, N is the next free number for it.
set -e

zope=$(sed -nE 's/^Zope==([0-9]+\.[0-9]+).*/\1/p' requirements.txt | head -n 1)
if [ -z "$zope" ]; then
    echo "Could not find a Zope==X.Y pin in requirements.txt" >&2
    exit 1
fi

last=$(git tag | awk -F- -v z="$zope" '($1 "") == (z "") && $2 ~ /^[0-9]+$/ {print $2}' | sort -n | tail -n 1)
echo "${zope}-$(( ${last:-0} + 1 ))"
