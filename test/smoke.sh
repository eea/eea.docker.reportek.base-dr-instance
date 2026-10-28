#!/bin/bash
# Smoke test for a Reportek image: start it and check that it really serves.
#
# usage: test/smoke.sh image:tag [requirements.txt ...]
#
# - the container has to start and keep running
# - GET / answers (Zope is serving, so the ZCML and the ZODB setup are fine)
# - Products.Reportek can be imported
# - every name==version pin in the given requirements files is what is installed in the image
set -euo pipefail

image="${1:?usage: $0 image:tag [requirements.txt ...]}"
shift

TRIES="${SMOKE_TRIES:-40}"
SLEEP="${SMOKE_SLEEP:-3}"
PYTHON=/opt/zope/bin/python
name="smoke-$$-$RANDOM"
platform=()
[ -n "${SMOKE_PLATFORM:-}" ] && platform=(--platform "$SMOKE_PLATFORM")

cleanup() {
  docker rm -vf "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

fail() {
  echo "FAILED: $*" >&2
  echo "--- container logs ---" >&2
  docker logs --tail 60 "$name" >&2 || true
  exit 1
}

# prints the HTTP status of a GET to the container, 0 when nothing answers
status() {
  docker exec "$name" "$PYTHON" -c "
import sys, urllib.error, urllib.request
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None
try:
    print(urllib.request.build_opener(NoRedirect).open('http://127.0.0.1:8080$1', timeout=10).status)
except urllib.error.HTTPError as e:
    print(e.code)
except Exception:
    print(0)
" 2>/dev/null || echo 0
}

docker run -d ${platform[@]+"${platform[@]}"} --name "$name" "$image" >/dev/null

echo "waiting for $image to answer on 8080"
code=0
for _ in $(seq "$TRIES"); do
  [ "$(docker inspect -f '{{.State.Running}}' "$name")" = "true" ] || fail "the container stopped"
  code=$(status /)
  [ "$code" != "0" ] && break
  sleep "$SLEEP"
done
[ "$code" != "0" ] || fail "no answer on port 8080 after $((TRIES * SLEEP))s"

[ "$code" -lt 400 ] || fail "GET / answered $code"
echo "ok: GET / answered $code"

version=$(docker exec "$name" "$PYTHON" -c "import importlib.metadata as m, Products.Reportek; print(m.version('Products.Reportek'))") \
  || fail "Products.Reportek cannot be imported"
echo "ok: Products.Reportek $version imports"

for reqs in "$@"; do
  docker exec -i "$name" "$PYTHON" -c "
import re, sys
from importlib import metadata
bad = []
n = 0
for line in sys.stdin:
    m = re.match(r'([A-Za-z0-9][A-Za-z0-9_.-]*)==([^\s;#]+)', line)
    if not m:
        continue
    n += 1
    try:
        have = metadata.version(m.group(1))
    except metadata.PackageNotFoundError:
        have = None
    if have != m.group(2):
        bad.append('%s: want %s, have %s' % (m.group(1), m.group(2), have))
if bad:
    print('\n'.join(bad))
sys.exit(1 if bad else 0)
" < "$reqs" || fail "installed versions differ from $reqs"
  echo "ok: installed versions match $reqs"
done

[ "$(docker inspect -f '{{.State.Running}}' "$name")" = "true" ] || fail "the container stopped while testing"
echo "smoke test passed for $image"
