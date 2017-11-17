{% if grains.get('os_family', '') == "Suse" %}
  {% set user = "salt" %}
  {% set group = "salt" %}
{% else %}
  {% set user = "root" %}
  {% set group = "root" %}
{% endif %}


{% set shared_secret = salt['cmd.run']('cat /proc/sys/kernel/random/uuid') %}
/etc/salt/master.d/sharedsecret.conf:
  file.managed:
    - source:
      - salt://ceph/salt-api/files/sharedsecret.conf.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ group }}
    - mode: 600
    - replace: False
    - context:
      shared_secret: {{ shared_secret }}
