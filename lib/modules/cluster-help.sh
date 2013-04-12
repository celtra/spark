#!/bin/bash

APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))
MODULE_ROOT=$APP_ROOT/lib/modules

cat <<EOF
Usage: cluster <command>

Commands:
EOF

for f in $MODULE_ROOT/cluster-*.sh
do
    if [ "$f" != "$MODULE_ROOT/cluster-help.sh" ]
    then
        NAME=$(cat $f | sed -ne 's/^MODULE_NAME="\(.*\)"/\1/p')
        DESCRIPTION=$(cat $f | sed -ne 's/^MODULE_DESCRIPTION="\(.*\)"/\1/p')
        PARAMETERS=$(cat $f | sed -ne 's/^MODULE_PARAMETERS="\(.*\)"/\1/p')
        if [ ${#NAME} -gt 8 ]
        then
            echo -e "\t${NAME}\t${DESCRIPTION} ${PARAMETERS}"
        else
            echo -e "\t${NAME}\t\t${DESCRIPTION} ${PARAMETERS}"
        fi
    fi
done
