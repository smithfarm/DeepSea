# Monitoring
By default DeepSea deploys a monitoring stack on the salt master. This consists
of prometheus and Grafana, as well as the ceph_exporter of the salt master and
the node_exporter on all salt minions.
The prometheus configuration and scrape targets are setup automatically by
DeepSea.

## Alerting
With version 0.8.6 DeepSea also deploys a list of
[default alerts](files/ses_default_alerts.yml).

### alertmanager configuration
The alertmanager configuration file (also see [the upstream
documentation](https://prometheus.io/docs/alerting/configuration/) sets, among
other things, routes, receivers, inhibit rules and authentication for various
notification channels (smtp, slack a.o.). Since these options are heavily
dependent on a deployment, DeepSea doesn't ship any defaults here. For
functioning alerting users have to provide their own alertmanager.yml
configuration file.
The alertmanager package by default installs a configuration file under
`/etc/prometheus/alertmanager.yml` and this can serve as an example
configuration, illustrating the concepts.
If you prefer to have your alertmanager config managed by DeepSea, add the
following key to you pillar (e.g. to
`/srv/pillar/ceph/cluster/<your-salt-master-minion-id.sls`):
```
monitoring:
  alertmanager_config:
    /path/to/your/alertmanager/config.yml
```

The following sections go into some detail about some of the configuration
sections and how they interact with the configuration files and alerts shipped by
DeepSea. This however does not replace the upstream documentation of this
configuration file.

#### receivers [upstream doc](https://prometheus.io/docs/alerting/configuration/#%3Creceiver%3E)
Receivers are channels were alerts are send after they are processed by the
alertmanager. Most notably receivers get alerts through routes, offering a
mechanism separate alerts, for example by severity.

#### routes [upstream doc](https://prometheus.io/docs/alerting/configuration/#%3Croute%3E)
`route` nodes form a routing tree along which alerts are routed. An alert enters
this tree at a root node (which must match all alerts through the `match_re`
field). An alert is matched against all child nodes (unless `continue` is false,
in which case the alert continues with only the first match) and only if no
child nodes match, the alert is send to the node's `receiver`.

DeepSea's default alerts supply two labels on which `route` definitions can
match. `severity` can take the values `warning` or `critical` providing the
ability to feed different receivers according to severity. The `type` label has
the static value of `ses_default` in order to be able to separate default alerts
from other custom alerts.

### Custom alerts
To add custom alerts either

* place your yaml file(s) containing the custom alerts in
  `/etc/prometheus/alerts` on the salt-master
* or provide a list of paths to your custom alert files in the pillar under the
  `monitoring:custom_alerts` key. Stage 2 or `salt <salt-master> state.apply
  ceph.monitoring.prometheus` will add your alert files in the right place. For
  example:

  A file with custom alerts is in `/root/my_alerts/my_alerts.yml` on your
  salt-master. When you add the
  following to `/srv/pillar/ceph/cluster/<your-salt-master-minion-id.sls`:
  ```
  monitoring:
    custom_alerts:
      - /root/my_alerts/my_alerts.yml
  ```
  DeepSea will create the file `/etc/prometheus/alerts/my_alerts.yml` and
  prometheus will be restarted.
