{% if grains.get('os_family', '') == "Suse" %}
  {% set user = "salt" %}
  {% set group = "salt" %}
{% else %}
  {% set user = "root" %}
  {% set group = "root" %}
{% endif %}

removing minion cache:
  file.absent:
    - name: /var/cache/salt/minion/files/base/ceph/configuration

/srv/salt/ceph/configuration/cache/ceph.conf:
  file.managed:
    - source: salt://ceph/configuration/files/ceph.conf.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ group }}
    - mode: 644
    - makedirs: True
    - fire_event: True




