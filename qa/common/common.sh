#
# This file is part of the DeepSea integration test suite
#

BASEDIR=$(pwd)
source $BASEDIR/common/json.sh

SALT_MASTER=$(cat /srv/pillar/ceph/master_minion.sls | \
             sed 's/.*master_minion:[[:blank:]]*\(\w\+\)[[:blank:]]*/\1/' | \
             grep -v '^$')


MINIONS_LIST=$(salt-key -L -l acc | grep -v '^Accepted Keys')

export DEV_ENV='true'

#
# stages
#

function _run_stage {
  local stage_num=$1

  echo ""
  echo "*********************************************"
  echo "********** Running DeepSea Stage $stage_num **********"
  echo "*********************************************"
  echo ""

  salt-run --no-color state.orch ceph.stage.${stage_num} | tee /tmp/stage.${stage_num}.log
  STAGE_FINISHED=$(grep -F 'Total states run' /tmp/stage.${stage_num}.log)

  if [[ ! -z $STAGE_FINISHED ]]; then
    FAILED=$(grep -F 'Failed: ' /tmp/stage.${stage_num}.log | sed 's/.*Failed:\s*//g' | head -1)
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

function run_stage_0 {
  _run_stage 0 "$@"
}

function run_stage_1 {
  _run_stage 1 "$@"
}

function run_stage_2 {
  _run_stage 2 "$@"
}

function run_stage_3 {
  _run_stage 3 "$@"
}

function run_stage_4 {
  _run_stage 4 "$@"
}

function run_stage_5 {
  _run_stage 5 "$@"
}

#
# custom configuration (ceph.conf)
# see https://github.com/SUSE/DeepSea/tree/master/srv/salt/ceph/configuration/files/ceph.conf.d
#

function ceph_conf {
  local STORAGENODES=$(json_storage_nodes)
  test ! -z "$STORAGENODES"
  if [ "x$STORAGENODES" = "x1" ] ; then
    # 1 node, 2 OSDs
    echo "Adjusting ceph.conf for operation with 1 storage node"
    cat <<EOF >> /srv/salt/ceph/configuration/files/ceph.conf.d/global.conf
mon pg warn min per osd = 16
osd pool default size = 2
osd crush chooseleaf type = 0 # failure domain == osd
EOF
  elif [ "x$STORAGENODES" = "x2" ] ; then
    # 2 nodes, 4 OSDs
    echo "Adjusting ceph.conf for operation with 2 storage nodes"
    cat <<EOF >> /srv/salt/ceph/configuration/files/ceph.conf.d/global.conf
mon pg warn min per osd = 8
osd pool default size = 2
EOF
  else
    echo "Three or more storage nodes; not adjusting ceph.conf"
    # TODO: look up default value of "mon pg warn min per osd"
  fi
}

#
# policy.cfg
#

function policy_cfg_base {
  cat <<EOF > /srv/pillar/ceph/proposals/policy.cfg
# Cluster assignment
cluster-ceph/cluster/*.sls
# Common configuration
config/stack/default/global.yml
config/stack/default/ceph/cluster.yml
# Role assignment - master
role-master/cluster/${SALT_MASTER}*.sls
# Role assignment - admin
role-admin/cluster/*.sls
# Role assignment - mon
role-mon/cluster/*.sls slice=[:1]
role-mon/stack/default/ceph/minions/*.yml slice=[:1]
EOF
}

function policy_cfg_no_client {
  cat <<EOF >> /srv/pillar/ceph/proposals/policy.cfg
# Hardware Profile
profile-*-1/cluster/*.sls
profile-*-1/stack/default/ceph/minions/*yml
EOF
}

function policy_cfg_client {
  cat <<EOF >> /srv/pillar/ceph/proposals/policy.cfg
# Hardware Profile
profile-*-1/cluster/*.sls slice=[:-1]
profile-*-1/stack/default/ceph/minions/*yml slice=[:-1]
EOF
}

function policy_cfg_mds {
  cat <<EOF >> /srv/pillar/ceph/proposals/policy.cfg
# Role assignment - mds
role-mds/cluster/*.sls slice=[:-1]
EOF
}

function policy_cfg_nfs_ganesha {
  cat <<EOF >> /srv/pillar/ceph/proposals/policy.cfg
# Role assignment - NFS-Ganesha (first node)
role-ganesha/cluster/*.sls slice=[:1]
EOF
}

function cat_policy_cfg {
  cat /srv/pillar/ceph/proposals/policy.cfg
}

#
# validation tests
#

function ceph_health_test {
  local LOGFILE=/tmp/ceph_health_test.log
  cat /etc/ceph/ceph.conf
  ceph osd tree
  ceph osd lspools
  ceph -s
  echo "Waiting for HEALTH_OK..."
  salt -C 'I@roles:master' wait.until status=HEALTH_OK | tee $LOGFILE
  grep -q 'Timeout expired' $LOGFILE && exit 1
  ceph -s | tee /dev/stderr | grep -q HEALTH_OK
}

function _client_node {
  #
  # FIXME: migrate this to "salt --static --out json ... | jq ..."
  #
  salt --no-color -C 'not I@roles:storage' test.ping | grep -o -P '^\S+(?=:)' | head -1
}

function _first_x_node {
  local ROLE=$1
  salt --no-color -C "I@roles:$ROLE" test.ping | grep -o -P '^\S+(?=:)' | head -1
}

function _run_test_script_on_node {
  local TESTSCRIPT=$1
  local TESTNODE=$2
  local ASUSER=$3
  salt-cp $TESTNODE $TESTSCRIPT $TESTSCRIPT
  local LOGFILE=/tmp/test_script.log
  if [ -z "$ASUSER" -o "x$ASUSER" = "xroot" ] ; then
    salt $TESTNODE cmd.run "sh $TESTSCRIPT" | tee $LOGFILE
  else
    salt $TESTNODE cmd.run "sudo su $ASUSER -c \"sh $TESTSCRIPT\"" | tee $LOGFILE
  fi
  local RESULT=$(grep -o -P '(?<=Result: )(OK|NOT_OK)$' $LOGFILE | head -1)
  test "x$RESULT" = "xOK"
}

function cephfs_mount_and_sanity_test {
  #
  # run cephfs mount test script on the client node
  # mounts cephfs in /mnt, touches a file, asserts that it exists
  #
  local TESTSCRIPT=/tmp/cephfs_test.sh
  local CLIENTNODE=$(_client_node)
  cat << 'EOF' > $TESTSCRIPT
set -ex
trap 'echo "Result: NOT_OK"' ERR
echo "cephfs mount test script running as $(whoami) on $(hostname --fqdn)"
TESTMONS=$(ceph-conf --lookup 'mon_initial_members' | tr -d '[:space:]')
TESTSECR=$(grep 'key =' /etc/ceph/ceph.client.admin.keyring | awk '{print $NF}')
echo "MONs: $TESTMONS"
echo "admin secret: $TESTSECR"
test -d /mnt
mount -t ceph ${TESTMONS}:/ /mnt -o name=admin,secret="$TESTSECR"
touch /mnt/bubba
test -f /mnt/bubba
umount /mnt
echo "Result: OK"
EOF
  # FIXME: assert no MDS running on $CLIENTNODE
  _run_test_script_on_node $TESTSCRIPT $CLIENTNODE
}

