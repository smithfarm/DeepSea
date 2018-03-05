{% set os = salt['grains.get']('os') %}

{% if os == 'SUSE' %}

stage prep dependencies suse:
  pkg.installed:
    - pkgs:
      - lsscsi
      - pciutils
      - gptfdisk
      - python3-boto
      - python3-rados
      - iperf
      - lsof
    - fire_event: True
    - refresh: True

{% elif os == 'Ubuntu' %}

stage prep dependencies ubuntu:
  pkg.installed:
    - pkgs:
      - lsscsi
      - pciutils
      - gdisk
      - python3-boto
      - python3-rados
      - iperf
    - fire_event: True
    - refresh: True

{% elif os == 'CentOS' %}

hwinfo repo for CentOS:
  pkgrepo.managed:
    - name: centos-nux-dextop-repo
    - humanname: CentoOS-$releasever - Nux Dextop
    - baseurl: http://li.nux.ro/download/nux/dextop/el$releasever/$basearch/
    - gpgcheck: False
    - enabled: True
    - fire_event: True

stage prep dependencies CentOS:
  pkg.installed:
    - pkgs:
      - lsscsi
      - pciutils
      - gdisk
      - python3-boto
      - python3-rados
      - iperf3
      - lshw
      - hwinfo
      - python-netaddr
    - fire_event: True
    - refresh: True

{% else %}

nop:
  test.nop

{% endif %}
