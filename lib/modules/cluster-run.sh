#!/bin/bash
##
# Run command on stack
#
set -eu -o pipefail

APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))
source $APP_ROOT/config/config.sh
source $APP_ROOT/lib/common.sh

MODULE_NAME="run"
MODULE_DESCRIPTION="Run command on all cluster nodes"

usage() {
    cat <<EOF
Usage: $(basename $0) [-r role] <cmd>

EOF
    exit 1
}

[ $# -lt 1 ] && usage

PARAMS=
ROLE=
while getopts "hr:" OPTION
do
     case $OPTION in
         h)  usage
             exit 1
             ;;
         r)  ROLE=$OPTARG
             ;;
         *)  usage
             exit 1
             ;;
     esac
done

shift `expr $OPTIND - 1`

COMMAND=$@

if INSTANCES=$(aws_get_instances | awk '{ print $2; }')
then
    # lib/prefix somewhat broken atm
    echo $INSTANCES
    parallel -j 99 -i $APP_ROOT/lib/prefix "{}: " ssh -o StrictHostKeyChecking=no -l root {} "$COMMAND" --  $INSTANCES
else
    error "No instances found."
fi
