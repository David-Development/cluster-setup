#!/bin/sh

echo "Adapting configuration file.."
sed -i "/Server \"127.0.0.1\" \"25826\"/c\Server \"${INFLUX_DB_IP}\" \"25826\"" /etc/collectd.conf

#cat /etc/collectd.conf

echo "Starting collectd"
collectd -C /etc/collectd.conf -f
