
include:
  - .keyring

create lvs:
  module.run:
    - name: lvm.create


deploy OSDs:
  module.run:
    - name: osd.deploy_lvm

