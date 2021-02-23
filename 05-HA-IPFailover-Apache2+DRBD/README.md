# HA con pacemaker y corosync. IP Failover + Apache2 + DRBD

Partiendo del ejercicio de IP Failover + Apache2,  vamos a agregar un sistema de replicación de dispositivos de bloques conocido como DRBD, que nos permitirá añadir posteriormente un recurso más al clúster de pacemaker, en este caso el directorio de datos del sitio web, que se mantendrá replicado y operativo en modo maestro/esclavo gracias a DRBD.

* `nodo1`: `10.1.1.101` <- Servidor web
* `nodo2`: `10.1.1.102` <- Servidor web
* `dns`: `10.1.1.103` <- Servidor DNS
* `www.example.com`: `10.1.1.100`

## Levantar el escenario

Simplemente ejecutamos la instrucción:

    $ vagrant up
    $ cd ansible
    $ ansible-playbook -b site.yaml

**Nota: Si utilizas vagrant con libvirt** tienes que utilizar el inventario `host_libvirt`, para ello, modifica el fichero `ansible.cfg` y modifica la línea:

    inventory = hosts_libvirt


## Configuración de DRBD

Con la ejecución de la receta ansible hemos creado un cluster entre los dos nodos con dos recursos: 

    $ pcs status
    ...
    Online: [ nodo1 nodo2 ]

    Full list of resources:

     VirtualIP	(ocf::heartbeat:IPaddr2):	Started nodo1
     WebSite	(ocf::heartbeat:apache):	Started nodo1
    ...

Podemos comprobar que en el fichero `Vagrantfile` hemos añadido un disco al nodo1 y nodo2, estos discos los vamos a utilizar para crear nuestro dispositivo de bloque DRBD (**Nota: Si estás usando libvirt los dispositivo de bloque se llaman `vdb`**), para ello lo primero que hacemos es instalar los paquetes necesarios en los dos nodos:

    # apt install drbd-utils

A continuación vamos a crear un recurso DRBD, creando el fichero `wwwdata.res` en el directorio `/etc/drbd.d` de ambos nodos:
  
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
  
A continuación vamos a crear el recurso drbd y lo vamos a activar en ambos nodos:

    # drbdadm create-md wwwdata
    # drbdadm up wwwdata

Asignamos el nodo1 como primario y el nodo2 como secundario, por lo tanto ejecutamos en el nodo1:

    # drbdadm primary --force wwwdata

Y comprobamos que en pieza la sincronización de discos:

    # drbdadm status wwwdata
    wwwdata role:Primary
      disk:UpToDate
      peer role:Secondary
        replication:SyncSource peer-disk:Inconsistent done:1.86

Trascurrido un tiempo comprobamos que los discos ya están sincronizados:

    # drbdadm status wwwdata
    wwwdata role:Primary
      disk:UpToDate
      peer role:Secondary
        replication:Established peer-disk:UpToDate

Podemos ver la característica de nuestros recursos DRBD:

    # cat /proc/drbd
    version: 8.4.10 (api:1/proto:86-101)
    srcversion: 9B4D87C5E865DF526864868 

     1: cs:Connected ro:Primary/Secondary ds:UpToDate/UpToDate C r-----
        ns:530108 nr:0 dw:5872 dr:526461 al:14 bm:0 lo:0 pe:0 ua:0 ap:0 ep:1 wo:f oos:0

Y finalmente podemos formatear el dispositivo de bloque, montarlo y crear un fichero `index.html` en el (todo esto se ejecuta en el nodo primario, en el nodo1):

    # apt install xfsprogs
  
    # mkfs.xfs /dev/drbd1
  
    # mount /dev/drbd1 /mnt
    # cd /mnt/
    # echo "<h1>Prueba</h1>" >> index.html
    # umount /mnt
  
## Configuración del DRBD en nuestro cluster de alta disponibilidad

A continuación vamos a crear dos recursos en pacemaker.

El primer recurso creado es para que el cluster controle el recurso drbd, el cluster decidirá que nodo se pone como primario y secundario en todo momento. Para realizar esta configuración vamos a usar una característica de pacemaker, los cambios lo vamos a realizar sobre un fichero (llamado `drbd_cfg`) y en la última instrucción vamos a aplicar todos los cambios al cluster desde este fichero, sería de esta forma:

    pcs cluster cib drbd_cfg
    pcs -f drbd_cfg resource create WebData ocf:linbit:drbd drbd_resource=wwwdata op monitor interval=60s
    pcs -f drbd_cfg resource promotable WebData promoted-max=1 promoted-node-max=1 clone-max=2  clone-node-max=1 notify=true
    pcs cluster cib-push drbd_cfg --config
  
El segundo recurso que vamos a crear corresponde al punto de montaje del dsipositivo DRBD, con esto conseguimos que el cluster sea responsable de montar en `/var/www/html` en el nodo principal el dispositivo drbd. Además vamos a crear todas las restricciones necesarias para para que estos recursos se asignen en el nodo principal y en el orden adecuado:

    pcs cluster cib fs_cfg
    pcs -f fs_cfg resource create WebFS Filesystem device="/dev/drbd1" directory="/var/www/html" fstype="xfs"
    pcs -f fs_cfg constraint colocation add WebFS with WebData-clone INFINITY with-rsc-role=Master
    pcs -f fs_cfg constraint order promote WebData-clone then start WebFS
    pcs -f fs_cfg constraint colocation add WebSite with WebFS INFINITY
    pcs -f fs_cfg constraint order WebFS then WebSite
    pcs cluster cib-push fs_cfg --config
  
Una vez terminada la configuración vemos el estado del cluster:

    # pcs status
    Cluster name: mycluster
    Stack: corosync
    Current DC: nodo2 (version 2.0.1-9e909a5bdd) - partition with quorum
    Last updated: Wed Feb 19 18:34:10 2020
    Last change: Wed Feb 19 18:33:57 2020 by root via cibadmin on nodo1

    2 nodes configured
    5 resources configured

    Online: [ nodo1 nodo2 ]

    Full list of resources:

     VirtualIP	(ocf::heartbeat:IPaddr2):	Started nodo1
     WebSite	(ocf::heartbeat:apache):	Started nodo1
     Clone Set: WebData-clone [WebData] (promotable)
         Masters: [ nodo1 ]
         Slaves: [ nodo2 ]
     WebFS	(ocf::heartbeat:Filesystem):	Started nodo1

  
## Prueba de funcionamiento

* Edita el fichero `/etc/resolv.conf` de tu equipo y añade como servidor DNS primario el nodo "dns" que tiene la dirección IP `10.1.1.103`
* Comprueba la conectividad con los nodos del cluster con ping Utiliza dig para resolver el nombre `www.example.com`:

        $ dig @10.1.1.103 www.example.com

* Comprueba que la dirección `www.example.com` está asociada a la dirección IP `10.1.1.100`, que en este escenario es la IP virtual que estará asociada en todo momento al nodo que esté en modo maestro.
* Accede a uno de los nodos del clúster y ejecuta la instrucción `pcs status`. Comprueba que los dos nodos están operativos y que los recursos IPCluster, WebSite, WebData y WebFS están funcionando correctamente en uno de ellos. En esta configuración se ha forzado que todos los recursos se ejecuten siempre en un solo nodo, que será el maestro de todos los recursos.
* Utiliza el navegador y accede a la dirección `www.example.com`. Recarga la página y comprueba que siempre responde el mismo nodo (nodo maestro).
* Apaga el nodo maestro y comprueba que los recursos pasan al otro nodo2 y que la página sigue funcionando.