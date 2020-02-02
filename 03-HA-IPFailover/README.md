# HA Ip Failover

apt install pacemaker pcs

passwd hacluster

pcs host auth nodo1 nodo2 -u hacluster
pcs cluster setup cluster_name nodo1 nodo2 --start --enable --force


pcs property set stonith-enabled=false


https://gist.github.com/beekhof/5589599

crmsh # crm resource move WebSite pcmk-1
pcs   # pcs constraint location WebSite prefers pcmk-1=INFINITY

crmsh # crm resource unmove WebSite
pcs   # pcs constraint rm location-WebSite-pcmk-1-INFINITY
