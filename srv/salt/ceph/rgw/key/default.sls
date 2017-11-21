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

{% for role in salt['pillar.get']('rgw_configurations', [ 'rgw' ]) %}
check {{ role }}:
  file.exists:
    - name: /srv/salt/ceph/rgw/files/{{ role }}.j2
    - failhard: True

{% for host in salt.saltutil.runner('select.minions', cluster='ceph', roles=role, host=True) %}
{% set client = "client." + role + "." + host %}
{% set keyring_file = salt['keyring.file']('rgw', client)  %}


{{ keyring_file}}:
  file.managed:
    - source:
      - salt://ceph/rgw/files/{{ role }}.j2
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
{% endfor %}


