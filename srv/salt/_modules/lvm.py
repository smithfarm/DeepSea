# -*- coding: utf-8 -*-

"""
lvm management
"""

import logging
import random
import subprocess
import string

log = logging.getLogger(__name__)


def configured(**kwargs):
    """
    Return the osds from the ceph namespace or original namespace, optionally
    filtered by attributes.
    """
    _devices = []
    if ('ceph' in __pillar__ and 'storage' in __pillar__['ceph']
        and 'osds' in __pillar__['ceph']['storage']):
        _devices = __pillar__['ceph']['storage']['osds']
    log.debug("devices: {}".format(_devices))

    return _devices


def create(**kwargs):
    for device in configured():
        pv = _create_pv(device)
        vg = _create_vg(pv)
        _create_lv(vg)
    return "success"


def _create_lv(vg):
    __salt__['lvm.lvcreate']('data', vg, extents="100%FREE")


def _create_vg(pv):
    vg_tmp_name = ''.join(random.choices(string.ascii_uppercase +
                                          string.digits, k=8))
    __salt__['lvm.vgcreate'](vg_tmp_name, pv)
    return vg_tmp_name


def _create_pv(device):
    _rc, _out, _err = __salt__['helper.run'](['sgdisk', '-og', device])
    _rc, start, err = __salt__['helper.run'](['sgdisk', '-F', device])
    _rc, end, err = __salt__['helper.run'](['sgdisk', '-E', device])
    _rc, _out, _err = __salt__['helper.run'](['sgdisk',
                                              '-n',
                                              '1:{}:{}'.format(start, end),
                                              device])
    __salt__['lvm.pvcreate']('{}1'.format(device))
    return '{}1'.format(device)
