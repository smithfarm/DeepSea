
begin:
  salt.state:
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - sls: ceph.events.begin_prep

sync:
  salt.state:
    - tgt: {{ salt['pillar.get']('ceph_tgt', '\'*\'') }}
    - tgt_type: compound
    - sls: ceph.sync

repo:
  salt.state:
    - tgt: {{ salt['pillar.get']('ceph_tgt', '\'*\'') }}
    - tgt_type: compound
    - sls: ceph.repo

common packages:
  salt.state:
    - tgt: {{ salt['pillar.get']('ceph_tgt', '\'*\'') }}
    - tgt_type: compound
    - sls: ceph.packages.common

updates:
  salt.state:
    - tgt: {{ salt['pillar.get']('ceph_tgt', '\'*\'') }}
    - tgt_type: compound
    - sls: ceph.updates

restart:
  salt.state:
    - tgt: {{ salt['pillar.get']('ceph_tgt', '\'*\'') }}
    - tgt_type: compound
    - sls: ceph.updates.restart

mines:
  salt.state:
    - tgt: {{ salt['pillar.get']('ceph_tgt', '\'*\'') }}
    - tgt_type: compound
    - sls: ceph.mines

complete:
  salt.state:
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - sls: ceph.events.complete_prep

