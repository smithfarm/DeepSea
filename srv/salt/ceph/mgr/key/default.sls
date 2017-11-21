{% if grains.get('os_family', '') == "Suse" %}
  {% set user = "salt" %}
  {% set group = "salt" %}
{% else %}
  {% set user = "root" %}
  {% set group = "root" %}
{% endif %}

prevent empty rendering:
  test.nop:
    - name: skip

{% for host in salt.saltutil.runner('select.minions', cluster='ceph', roles='mgr', host=True) %}
{% set client = "mgr." + host %}
{% set keyring_file = salt['keyring.file']('mgr', host)  %}
{{ keyring_file}}:
  file.managed:
    - source:
      - salt://ceph/mgr/files/keyring.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ group }}
    - mode: 600
    - makedirs: True
    - context:
      client: {{ client }}
      secret: {{ salt['keyring.secret'](keyring_file) }}
    - fire_event: True

{% endfor %}


