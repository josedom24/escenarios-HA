#!/bin/bash
pcs cluster destroy 
pcs host auth nodo1 nodo2 -u hacluster -p hacluster
pcs cluster setup mycluster nodo1 nodo2 --start --enable --force
pcs property set stonith-enabled=false
pcs resource create VirtualIP ocf:heartbeat:IPaddr2 ip=10.1.1.100 cidr_netmask=32 nic=eth1 op monitor interval=30s
pcs resource create WebSite ocf:heartbeat:apache  \
      configfile=/etc/apache2/apache2.conf \
      statusurl="http://localhost/server-status" \
      op monitor interval=1min
pcs constraint colocation add WebSite with VirtualIP INFINITY
pcs constraint order VirtualIP then WebSite

