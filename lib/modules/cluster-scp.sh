#!/bin/bash
##
# Copy file to stack
#
set -eu -o pipefail

APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))
source $APP_ROOT/config/config.sh
source $APP_ROOT/lib/common.sh

MODULE_NAME="scp"
MODULE_DESCRIPTION="Copy files to all cluster nodes"

usage() {
    cat <<EOF
Copy file to all AWS stack instances in parallel. If stack, accessKey and secretKey
are not specified, they are read from config.php.
Usage: $(basename $0) "source" "destination"

EOF
    exit 1
}

[ $# -lt 1 ] && usage

PARAMS=
while getopts "h" OPTION
do
     case $OPTION in
         h)  usage
             exit 1
             ;;
         *)  usage
             exit 1
             ;;
     esac
done

shift `expr $OPTIND - 1`

SOURCE=${1:-}
DESTINATION=${2:-}

if [ "x$SOURCE" = "x" ] || [ "x$DESTINATION" = "x" ]
then
    usage
fi

if INSTANCES=$(aws_get_instances | awk '{print $2}')
then
    # lib/prefix somewhat broken atm
    parallel -j 99 -i scp ${SOURCE} root@{}:${DESTINATION} --  $INSTANCES
else
    error "No instances found."
fi
