#!/bin/bash
#
# DeepSea integration test "suites/basic/stage-5.sh"
#
# This script runs DeepSea stages 2 and 5 to remove a storage-only node from
# an existing Ceph cluster.
#
# In addition to the assumptions contained in qa/README, this script assumes
# that (1) DeepSea has already been used to deploy a cluster, (2) the
# cluster has at least one "storage-only" node (i.e. a node with role "storage"
# and no other roles (except possibly "admin")), and (3) the cluster will
# be able to reach HEALTH_OK without one storage-only node.
#
# On success (HEALTH_OK is reached), the script returns 0. On failure, for
# whatever reason, the script returns non-zero.
#
# The script produces verbose output on stdout, which can be captured for later
# forensic analysis.
#

set -e
set +x

SCRIPTNAME=$(basename ${0})
BASEDIR=$(readlink -f "$(dirname ${0})/../..")
test -d $BASEDIR
[[ $BASEDIR =~ \/qa$ ]]

source $BASEDIR/common/common.sh

function usage {
    set +x
    echo "$SCRIPTNAME - script for testing HEALTH_OK deployment"
    echo "for use in SUSE Enterprise Storage testing"
    echo
    echo "Usage:"
    echo "  $SCRIPTNAME [-h,--help] [--cli]"
    echo
    echo "Options:"
    echo "    --cli           Use DeepSea CLI"
    echo "    --help          Display this usage message"
    exit 1
}

assert_enhanced_getopt

TEMP=$(getopt -o h \
--long "cli,help" \
-n 'health-ok.sh' -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around TEMP': they are essential!
eval set -- "$TEMP"

# process command-line options
CLI=""
while true ; do
    case "$1" in
        --cli) CLI="$1" ; shift ;;
        -h|--help) usage ;;    # does not return
        --) shift ; break ;;
        *) echo "Internal error" ; exit 1 ;;
    esac
done
echo "WWWW"
echo "stage-5.sh running with the following configuration:"
test -n "$CLI" && echo "- CLI"
set -x

# modify storage profile
STORAGE_PROFILE=$(storage_profile_from_policy_cfg)
policy_remove_storage_node $(_first_storage_only_node)

# run stages 2 and 5
run_stage_2 "$CLI"
ceph_cluster_status
run_stage_5 "$CLI"
ceph_cluster_status

# verification phase
ceph_health_test
salt -I roles:storage osd.report

echo "YYYY"
echo "stage-5 test result: PASS"
