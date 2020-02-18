# HA con pacemaker y corosync. IP Failover + Apache2 + RDBD

    apt install drbd-utils
  
  
    /etc/drbd.d# cat wwwdata.res 
  
    resource wwwdata {
     protocol C;
     meta-disk internal;
     device /dev/drbd1;
     syncer {
      verify-alg sha1;
     }
     net {
      allow-two-primaries;
     }
     on nodo1 {
      disk   /dev/sdb;
      address  10.1.1.101:7789;
     }
     on nodo2 {
      disk   /dev/sdb;
      address  10.1.1.102:7789;
     }
    }
  
  
    apt install xfsprogs
  
    mkfs.xfs /dev/drbd1
  
    root@nodo1:/etc/drbd.d# mount /dev/drbd1 /mnt
    root@nodo1:/etc/drbd.d# cd /mnt/
    root@nodo1:/mnt# nano index.html
  
    pcs cluster cib drbd_cfg
    pcs -f drbd_cfg resource create WebData ocf:linbit:drbd drbd_resource=wwwdata op monitor interval=60s
    pcs -f drbd_cfg resource promotable WebData promoted-max=1 promoted-node-max=1 clone-max=2  clone-node-max=1 notify=true
    pcs cluster cib-push drbd_cfg --config
  
  
    pcs cluster cib fs_cfg
    pcs -f fs_cfg resource create WebFS Filesystem device="/dev/drbd1" directory="/var/www/html" fstype="xfs"
    pcs -f fs_cfg constraint colocation add WebFS with WebData-clone INFINITY with-rsc-role=Master
    pcs -f fs_cfg constraint order promote WebData-clone then start WebFS
    pcs -f fs_cfg constraint colocation add WebSite with WebFS INFINITY
    pcs -f fs_cfg constraint order WebFS then WebSite
    pcs cluster cib-push fs_cfg --config
  
  
  
  