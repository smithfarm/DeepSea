#!/bin/bash -ex
#
# DeepSea integration test workunit "basic-health-ok"
#
# This integration test script makes the following assumptions:
# 1. there are four machines that are running the same OS (e.g. Leap 42.3) and
#    can see eachother over the network:
#    - Salt Master/admin node
#    - mon.a
#    - mon.b
#    - mon.c
# 2. Salt Master/admin node need have no external drives
# 3. nodes mon.{a,b,c} need at least one external drive (>= 20GB) for OSD
# 4. the integration test script is running on Salt Master/admin node
# 5. the Salt Master/admin node has:
#    - salt-master package installed
#    - salt-master.service enabled and started
# 6. the mon.{a,b,c} nodes have:
#    - salt-minion package installed
#    - salt-minion.service enabled and started
# 7. the Salt Master/admin node has accepted all the minion keys and test.ping
#    has succeeded against all three nodes mon.{a,b,c}
# 8. the ceph RPMs under test have already been installed on nodes mon.{a,b,c}
# 9. the DeepSea code under test has already been installed on Salt
#    Master/admin node
#
# This script deploys a Ceph cluster on nodes mon.{a,b,c} and checks for
# HEALTH_OK.
#
# On success (HEALTH_OK is reached), the script returns 0.
#
# On failure, for whatever reason, the script returns non-zero.
#
# The script produces verbose output on stdout for capture and later forensic
# analysis.

SALT_MASTER=`cat /srv/pillar/ceph/master_minion.sls | \
             sed 's/.*master_minion:[[:blank:]]*\(\w\+\)[[:blank:]]*/\1/' | \
             grep -v '^$'`

MINIONS_LIST=`salt-key -L -l acc | grep -v '^Accepted Keys' | grep -v $SALT_MASTER`

export DEV_ENV='true'

function run_stage {
  local stage_num=$1

  echo ""
  echo "*********************************************"
  echo "********** Running DeepSea Stage $stage_num **********"
  echo "*********************************************"
  echo ""
  
  salt-run --no-color state.orch ceph.stage.${stage_num} | tee /tmp/stage.${stage_num}.log
  STAGE_FINISHED=`fgrep 'Total states run' /tmp/stage.${stage_num}.log`
  
  if [[ ! -z $STAGE_FINISHED ]]; then
    FAILED=`fgrep 'Failed: ' /tmp/stage.${stage_num}.log | sed 's/.*Failed:\s*//g' | head -1`
    if [[ "$FAILED" -gt "0" ]]; then
      echo "********** Stage $stage_num failed with $FAILED failures **********"
      echo "Check /tmp/stage.${stage_num}.log for details"
      exit 1
    fi
    echo "********** Stage $stage_num completed successefully **********"
  else
    echo "********** Stage $stage_num failed with $FAILED failures **********"
    echo "Check /tmp/stage.${stage_num}.log for details"
    exit 1
  fi
}

function gen_policy_cfg {

  cat <<EOF > /srv/pillar/ceph/proposals/policy.cfg
# Cluster assignment
cluster-ceph/cluster/*.sls
# Hardware Profile
profile-*-1/cluster/*.sls
profile-*-1/stack/default/ceph/minions/*yml
# Common configuration
config/stack/default/global.yml
config/stack/default/ceph/cluster.yml
# Role assignment
role-master/cluster/${SALT_MASTER}*.sls
EOF

  for minion in $MINIONS_LIST; do
    cat <<EOF >> /srv/pillar/ceph/proposals/policy.cfg
role-mon/cluster/${minion}*.sls
role-mon/stack/default/ceph/minions/${minion}*.yml
EOF
  done

}

run_stage 0
run_stage 1
gen_policy_cfg
run_stage 2
run_stage 3

ceph -s | grep -q 'HEALTH_OK\|HEALTH_WARN'
if [[ ! $? == 0 ]]; then
  echo "Ceph cluster is not healthy!"
  ceph -s
fi  

echo "OK"

