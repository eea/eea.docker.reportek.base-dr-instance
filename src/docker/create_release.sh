#!/bin/bash
# Creates the GitHub release for a commit that is already pushed. GitHub creates the tag with it,
# and the tag is what makes Jenkins build and publish the image.
#
# usage: create_release.sh <repository> <version> <commit> [<previous version>]
# GITHUB_TOKEN has to be in the environment, GITHUB_API can override the API url (for tests).
set -euo pipefail

repo="${1:?repository}"
version="${2:?version}"
commit="${3:?commit}"
previous="${4:-}"
api="${GITHUB_API:-https://api.github.com}"

body="Release $version"
if [ -n "$previous" ]; then
    body="$body\\nChanges since the last release: https://github.com/eea/$repo/compare/$previous...$version"
fi
data=$(printf '{"tag_name": "%s", "target_commitish": "%s", "name": "%s", "body": "%s", "draft": false, "prerelease": false}' \
    "$version" "$commit" "$version" "$body")

response=$(mktemp)
trap 'rm -f "$response"' EXIT

# the token goes through stdin, so it is not in the process list
code=$(curl -s -o "$response" -w '%{http_code}' -K - -X POST -d "$data" "$api/repos/eea/$repo/releases" <<EOF
header = "Authorization: Bearer $GITHUB_TOKEN"
header = "Accept: application/vnd.github+json"
EOF
)

if [ "$code" != "201" ]; then
    echo "Could not create the release $version for eea/$repo (HTTP $code)" >&2
    cat "$response" >&2
    exit 1
fi
echo "Created the release $version for eea/$repo at $commit"
