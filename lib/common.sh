#!/bin/bash
set -eu -o pipefail
for param in "${!CFN_PARAMS[@]}"
do
    p=$(echo $param | sed -e 's/\([A-Z]\)/_\1/g' -e 's/\(.*\)/\U\1/')
    export CFN_$p="${CFN_PARAMS[$param]}"
done

##
# Silly
error() {
    echo "Error: $1" >&2
    exit 1
}

sudo_cmd() {
    sudo env PATH=$PATH AWS_CONFIG_FILE=$AWS_CONFIG_FILE "$@"
}

aws_generate_parameters_json() {
    PARAMS="["
    for param in ${!CFN_PARAMS[@]}
    do
        PARAMS+="{ \"ParameterKey\":   \"$param\","
        PARAMS+="  \"ParameterValue\": \"${CFN_PARAMS[$param]}\" },"
    done
    PARAMS=${PARAMS%,}"]"
    echo $PARAMS
}

aws_cfn_wait_for_quit_status() {
    OK_STATUS=${1:-CREATE_COMPLETE}
    FAIL_STATUS=${2:-ROLLBACK_COMPLETE}
    die=false
    OLD_STATUS=
    while ! $die
    do
        STATUS=$(aws_get_stack_status)
        if [ "$STATUS"  == "$OK_STATUS" ]
        then
            echo $STATUS
            die=true
            exit
        fi
        if [ "$STATUS"  == "$FAIL_STATUS" ]
        then
            echo -e "\nSomething went wrong with cluster creation"
            exit 1
        fi
        if [ "$STATUS" != "$OLD_STATUS" ]
        then
            OLD_STATUS=$STATUS
            echo -n $STATUS
        else
            echo -n .
        fi
        sleep 15
    done
}
##
# Return a list of AWS instance IDs and PublicDNSNames
aws_get_instances() {
    ROLE=${1:-}
    FILTERS="[ { \"Name\": \"tag:aws:cloudformation:stack-name\", \"Values\": [ \"$CFN_CLUSTER_NAME\" ] },"
    FILTERS+="{ \"Name\": \"instance-state-name\", \"Values\": [ \"running\" ] }"
    [ "$ROLE" != "" ] && FILTERS+=",{ \"Name\": \"tag:aws:cloudformation:logical-id\", \"Values\": [ \"${ROLE}*\" ] } ]" || FILTERS+="]"

    FILTERS=$(tr -d '\n' <<< $FILTERS)
    aws ec2 describe-instances \
        --filters "$FILTERS" | \
        tr -d '\n' | \
        sed -ne 's/^\(.*}]*\)[^}]*$/\1/p' | \
        $APP_ROOT/lib/jsawk -n 'for (var i = 0; i < this.Reservations.length; i++) { for (j = 0; j < this.Reservations[i].Instances.length; j++) { out(this.Reservations[i].Instances[j].InstanceId + " " + this.Reservations[i].Instances[j].PublicDnsName); } }'
}

aws_get_instance_by_id() {
    INSTANCE_IDS=${1:-}
    FILTER="[${INSTANCE_IDS/ /,}]"
    aws ec2 describe-instances --instance-ids "$FILTER"
}

aws_get_stack_status() {
    aws cloudformation describe-stacks --stack-name $CFN_CLUSTER_NAME | \
    tr -d '\n' | \
    sed -ne 's/^\(.*}]*\)[^}]*$/\1/p' | \
    $APP_ROOT/lib/jsawk -n 'if (typeof this.ErrorResponse != "undefined" ) { out(this.ErrorResponse.Error.Message); } else { out(this.StackStatus); }'
}
