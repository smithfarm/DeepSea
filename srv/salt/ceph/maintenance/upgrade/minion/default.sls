
mines:
  salt.state:
    - tgt: '*'
    - sls: ceph.mines

sync:
  salt.state:
    - tgt: '*'
    - sls: ceph.sync

repo:
  salt.state:
    - tgt: '*'
    - sls: ceph.repo

common packages:
  salt.state:
    - tgt: '*'
    - sls: ceph.packages.common

{% if salt['saltutil.runner']('cephprocesses.mon') == True %}

#warning_before:
#  salt.state:
#    - tgt: {{ salt['pillar.get']('master_minion') }}
#    - sls: ceph.warning.noout
#    - failhard: True

{% for host in salt.saltutil.runner('orderednodes.unique', cluster='ceph') %}

wait until the cluster has recovered before processing {{ host }}:
  salt.state:
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - sls: ceph.wait
    - failhard: True

check if all processes are still running after processing {{ host }}:
  salt.state:
    - tgt: '*'
    - sls: ceph.processes
    - failhard: True

unset noout after processing {{ host }}:
  salt.state:
    - sls: ceph.noout.unset
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - failhard: True

updating {{ host }}:
  salt.state:
    - tgt: {{ host }}
    - tgt_type: compound
    - sls: ceph.updates
    - failhard: True

unset noout {{ host }}: 
  salt.state:
    - sls: ceph.noout.unset
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - failhard: True

restart {{ host }} if updates require:
  salt.state:
    - tgt: {{ host }}
    - tgt_type: compound
    - sls: ceph.updates.restart
    - failhard: True

{% endfor %}

unset noout after final iteration: 
  salt.state:
    - sls: ceph.noout.unset
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - failhard: True

#warning_after:
#  salt.state:
#    - tgt: {{ salt['pillar.get']('master_minion') }}
#    - sls: ceph.warning.noout
#    - failhard: True

{% else %}

updates:
  salt.state:
    - tgt: '*'
    - sls: ceph.updates

{% endif %}

restart:
  salt.state:
    - tgt: '*'
    - sls: ceph.updates.restart