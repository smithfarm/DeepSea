#!/bin/bash
#
# DeepSea integration test "suites/basic/health-openattic.sh"
#
# This script runs DeepSea stages 0-4 to deploy a Ceph cluster with RGW and
# openATTIC.  After stage 4 completes, it sends a GET request to the RGW node
# using curl, and tests that: (a) the response contains the string "anonymous"
# and (b) the response is legal XML.
#
# This script makes the following assumption beyond those listed in qa/README:
# - minimum of 2 nodes in cluster
#
# On success, the script returns 0. On failure, for whatever reason, the script
# returns non-zero.
#
# The script produces verbose output on stdout, which can be captured for later
# forensic analysis.
#

set -ex
BASEDIR=$(pwd)
source $BASEDIR/common/common.sh

function usage {
    set +x
    echo "${0} - script for testing HEALTH_OK deployment"
    echo "for use in SUSE Enterprise Storage testing"
    echo
    echo "Usage:"
    echo "  ${0} [-h,--help] [--cli]"
    echo
    echo "Options:"
    echo "    --cli      Use DeepSea CLI"
    echo "    --help     Display this usage message"
    exit 1
}

TEMP=$(getopt -o h --long "cli" \
     -n 'health-ok.sh' -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around TEMP': they are essential!
eval set -- "$TEMP"

# process options
CLI=""
while true ; do
    case "$1" in
        --cli) CLI="cli" ; shift ;;
        -h|--help) usage ;;    # does not return
        --) shift ; break ;;
        *) echo "Internal error" ; exit 1 ;;
    esac
done

assert_enhanced_getopt
install_deps
cat_salt_config
run_stage_0
run_stage_1
policy_cfg_base
policy_cfg_no_client
policy_cfg_openattic_with_rgw
cat_policy_cfg
run_stage_2
ceph_conf_small_cluster
run_stage_3
ceph_cluster_status
run_stage_4
ceph_cluster_status
ceph_health_test
rgw_curl_test

echo "OK"
