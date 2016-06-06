#!/bin/bash
SCRIPTNAME=$(readlink -f $0)
SCRIPTPATH=$(dirname $SCRIPTNAME)

set -eo pipefail
[[ "$TRACE" ]] && set -x || :

$@