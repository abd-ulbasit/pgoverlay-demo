#!/usr/bin/env bash
# Checks scripts/pgoverlay-branch.sh against vectors copied from pgoverlay's
# pgoverlayconnect/testdata/branch_names.json (the table the service and the
# Go and JS connect helpers are tested against). Run: scripts/pgoverlay-branch.test.sh
set -uo pipefail
cd "$(dirname "$0")"

fail=0
check() { # repo ref pr want
  local got
  got=$(./pgoverlay-branch.sh "$1" "$2" "$3" 2>&1)
  if [ "$got" != "$4" ]; then
    echo "FAIL repo=$1 ref=$2 pr=$3: got '$got', want '$4'"
    fail=1
  fi
}

check acme/widgets "" 7 gh-d782c8-pr-7
check Acme/Widgets "" 7 gh-d782c8-pr-7
check acme/gadgets "" 7 gh-9c2435-pr-7
check acme/widgets "" 123456 gh-d782c8-pr-123456
check acme/widgets feat/Login 7 gh-d782c8-feat-login
check acme/widgets feat/Health_Endpoint 7 gh-d782c8-feat-health-endpoint
check acme/widgets 'FIX--weird///chars!!' 7 gh-d782c8-fix-weird-chars
check acme/widgets release/v1.2.3 7 gh-d782c8-release-v1-2-3
check acme/widgets main 7 gh-d782c8-main
check acme/widgets -/- 9 gh-d782c8-pr-9
check acme/widgets $'feat/\xc3\xbcmlaut-\xc3\x84rger' 7 gh-d782c8-feat-mlaut-rger
check acme/widgets $'\xc4\xb0x' 7 gh-d782c8-x
check acme/widgets $'\xe2\x84\xaaelvin' 7 gh-d782c8-elvin
check acme/widgets aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 7 gh-d782c8-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
check acme/widgets aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 7 gh-d782c8-aaaaaaaaaaaaaaaaaaaaaaaa-3ba3f5
check acme/widgets aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/b 7 gh-d782c8-aaaaaaaaaaaaaaaaaaaaaaaa-82a379
check acme/widgets aaaaaaaaaaaaaaaaaaaaaaa/bbbbbbbbbb 7 gh-d782c8-aaaaaaaaaaaaaaaaaaaaaaa-56228d
check acme/widgets dependabot/npm_and_yarn/lodash-4.17.21 7 gh-d782c8-dependabot-npm-and-yarn-b7180b
check acme/widgets dependabot/npm_and_yarn/lodash-4.17.20 8 gh-d782c8-dependabot-npm-and-yarn-c24859
check acme/gadgets dependabot/npm_and_yarn/lodash-4.17.21 7 gh-9c2435-dependabot-npm-and-yarn-b7180b

# no usable ref and no PR number is an error, not a guess
if ./pgoverlay-branch.sh acme/widgets -/- "" >/dev/null 2>&1; then
  echo "FAIL: ref without letters or digits and no PR should fail"
  fail=1
fi

[ "$fail" = 0 ] && echo "pgoverlay-branch.sh: all vectors pass"
exit "$fail"
