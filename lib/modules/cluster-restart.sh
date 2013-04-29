#!/bin/bash
set -eu -o pipefail

APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))
source $APP_ROOT/config/config.sh

MODULE_NAME="restart"
MODULE_DESCRIPTION="Restart all Spark daemons"

$APP_ROOT/lib/modules/cluster-run.sh -r Master /etc/init.d/spark restart
sleep 15
$APP_ROOT/lib/modules/cluster-run.sh -r Slave /etc/init.d/spark restart