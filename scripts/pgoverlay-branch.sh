#!/usr/bin/env bash
# Prints the name of the pgoverlay branch that pgoverlay-github (the webhook
# service) creates for a pull request:
#
#   scripts/pgoverlay-branch.sh OWNER/NAME REF [PR]
#
#   git-branch naming: REF is the PR's head branch (e.g. feat/order-tags,
#                      not refs/heads/...) -> gh-<repo-key>-feat-order-tags
#   pr-number naming:  REF empty ("")      -> gh-<repo-key>-pr-<PR>
#
# <repo-key> is the first 6 hex chars of sha256(lowercased OWNER/NAME), so PRs
# of different repositories never share a branch. A REF with no letters or
# digits falls back to PR, as the service does; so do PRs from forks, which
# the service always names by number.
#
# This is the same rule as pgoverlayconnect (Go) and pgoverlay-connect (npm),
# pinned by pgoverlay's pgoverlayconnect/testdata/branch_names.json; the
# vectors in scripts/pgoverlay-branch.test.sh come from that table.
set -euo pipefail
export LC_ALL=C # byte-wise: only ASCII letters and digits survive, like the Go and JS code

usage="usage: pgoverlay-branch.sh OWNER/NAME REF [PR]"
repo=${1:?$usage}
ref=${2-}
pr=${3-}

sha6() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | cut -c1-6
}

prefix="gh-$(printf '%s' "$repo" | tr 'A-Z' 'a-z' | sha6)-"
frag=$(printf '%s' "$ref" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')

if [ -n "$frag" ]; then
  budget=$((41 - ${#prefix}))
  if [ "${#frag}" -gt "$budget" ]; then
    # cut, drop a trailing dash, and add a hash of the full ref so two long
    # refs with a common start stay distinct
    frag="$(printf '%s' "${frag:0:$((budget - 7))}" | sed -E 's/-+$//')-$(printf '%s' "$ref" | sha6)"
  fi
  echo "$prefix$frag"
elif [ -n "$pr" ]; then
  case "$pr" in
    *[!0-9]* | 0) echo "pgoverlay-branch.sh: PR must be a pull request number, got '$pr'" >&2; exit 2 ;;
  esac
  echo "${prefix}pr-$((10#$pr))"
else
  echo "pgoverlay-branch.sh: REF '$ref' has no letters or digits to name a branch after; pass the PR number" >&2
  exit 2
fi
