#!/bin/bash
set -eu -o pipefail

APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))
source $APP_ROOT/config/config.sh

MODULE_NAME="log"
MODULE_DESCRIPTION="Tail all cluster logs"

$APP_ROOT/lib/modules/cluster-run.sh tail -f /tmp/spark-work/*/*/std* /opt/spark/logs/*