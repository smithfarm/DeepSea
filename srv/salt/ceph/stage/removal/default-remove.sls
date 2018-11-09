
{% set master = salt['master.minion']() %}

update mines:
  salt.function:
    - name: mine.update
    - tgt: 'I@cluster:ceph'
    - tgt_type: compound


remove mon:
  salt.state:
    - tgt: {{ master }}
    - tgt_type: compound
    - sls: ceph.remove.mon

remove mgr:
  salt.state:
    - tgt: {{ master }}
    - tgt_type: compound
    - sls: ceph.remove.mgr

drain osds:
  salt.state:
    - tgt: {{ master }}
    - tgt_type: compound
    - sls: ceph.remove.storage.drain

terminate ceph osds:
  salt.state:
    - tgt: 'I@cluster:ceph'
    - tgt_type: compound
    - sls: ceph.rescind.storage.terminate

cleanup osds:
  salt.state:
    - tgt: {{ master }}
    - tgt_type: compound
    - sls: ceph.remove.storage

remove ganesha:
  salt.state:
    - tgt: {{ master }}
    - tgt_type: compound
    - sls: ceph.remove.ganesha

rescind roles:
  salt.state:
    - tgt: 'I@cluster:ceph'
    - tgt_type: compound
    - sls: ceph.rescind

remove cephfs:
  salt.state:
    - tgt: {{ master }}
    - tgt_type: compound
    - sls: ceph.remove.mds

remove rgw:
  salt.state:
    - tgt: {{ master }}
    - tgt_type: compound
    - sls: ceph.remove.rgw

{% if (salt.saltutil.runner('select.minions', cluster='ceph', roles='rgw') == []) and
      (salt.saltutil.runner('select.minions', cluster='ceph', roles='rgw_configurations') == []) %}

# Remove the Prometheus RGW exporter if no 'rgw' node is configured.
remove prometheus rgw exporter:
  salt.state:
    - tgt: {{ master }}
    - tgt_type: compound
    - sls: ceph.rescind.rgw.monitoring

{% endif %}
