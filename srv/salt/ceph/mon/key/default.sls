{% if grains.get('os_family', '') == "Suse" %}
  {% set user = "salt" %}
  {% set group = "salt" %}
{% else %}
  {% set user = "root" %}
  {% set group = "root" %}
{% endif %}

{% set keyring_file = "/srv/salt/ceph/mon/cache/mon.keyring" %}
{{ keyring_file }}:
  file.managed:
    - source:
      - salt://ceph/mon/files/keyring.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ group }}
    - mode: 600
    - makedirs: True
    - context:
      mon_secret: {{ salt['keyring.secret'](keyring_file) }}
    - fire_event: True

{{ keyring_file }} append admin keyring:
  file.append:
    - name: {{ keyring_file }}
    - source: salt://ceph/admin/cache/ceph.client.admin.keyring
