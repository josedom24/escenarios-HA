# HA con pacemaker y corosync. IP Failover + Apache2 + RDBD + GFS2 (Activo-Activo)

Partiendo del ejercicio de IP Failover + Apache2 + DRBD,  vamos a agregar un sistema de almacenamiento distribuido [GFS2](https://es.wikipedia.org/wiki/Global_File_System_(Red_Hat)), por lo que podremos configurar nuestros sistema DRBD como *Dual-primary*, y la IP *ClusterIP* podrá estar asignado a cualquiera de los nodos, ya que los nodos podrán escribir o leer al mismo tiempo.

## Instalación de GFS2

En este apartado vamos a configurar OCFS2 como sistema de almacenamiento distribuido para conseguir el cluster de alta disponibilidad activo-activo.

Además vamos a instalar el programa DLM (*Distributed Lock Manager*) que será el encargado de gestionar el acceso del cluster al almacenamiento distribuido.

Ejecutamos:

    apt install gfs2-utils dlm-controld

 
## Configuración de DLM en nuestro cluster de alta disponibilidad

El DLM se tiene que ejecutar en los dos nodos, vamos a crear un recurso **ocf:pacemaker:controld** y lo vamos a clonar:

    pcs cluster cib dlm_cfg
    pcs -f dlm_cfg resource create dlm ocf:pacemaker:controld op monitor interval=60s
    pcs -f dlm_cfg resource clone dlm clone-max=2 clone-node-max=1
    pcs cluster cib-push dlm_cfg --config

Vemos como se ha creado el recurso y está funcionando en los dos nodos:

    pcs status
    ...
    Full List of Resources:
      * VirtualIP	(ocf::heartbeat:IPaddr2):	 Started nodo1
      * WebSite	(ocf::heartbeat:apache):	 Started nodo1
      * Clone Set: WebData-clone [WebData] (promotable):
        * Masters: [ nodo1 ]
        * Slaves: [ nodo2 ]
      * WebFS	(ocf::heartbeat:Filesystem):	 Started nodo1
      * Clone Set: dlm-clone [dlm]:
        * Started: [ nodo1 nodo2 ]
    ...

## Creación del sistema de archivos GFS2

Antes de continuar vamos a deshabilitar el recurso que controlaba el sistema de archivo del ejercicio anterior:

    pcs resource disable WebFS

Vemos como el recurso *WebFs* y *WebSite* se han detenido:

    pcs status
    ...
    Full List of Resources:
      * VirtualIP	(ocf::heartbeat:IPaddr2):	 Started nodo1
      * WebSite	(ocf::heartbeat:apache):	 Stopped
      * Clone Set: WebData-clone [WebData] (promotable):
        * Masters: [ nodo1 ]
        * Slaves: [ nodo2 ]
      * WebFS	(ocf::heartbeat:Filesystem):	 Stopped (disabled)
      * Clone Set: dlm-clone [dlm]:
        * Started: [ nodo1 nodo2 ]

Tenemos que poner el nodo secundario de DRBD como primario, por lo tanto en el nodo2 ejecutamos:

    drbdadm primary --force wwwdata

Y formateamos el dispositivo de bloque:

    mkfs.gfs2 -p lock_dlm -j 2 -t mycluster:web /dev/drbd1

Y creamos el fichero `index.html`:

    mount /dev/drbd1 /mnt
    # cd /mnt/
    # echo "<h1>Prueba con OCFS2</h1>" >> index.html
    # umount /mnt

## Reconfigurar el cluster para OCFS2

Tenemos que cambiar el tipo de sistema de archivo en el recurso *WebFS*:

    pcs resource update WebFS fstype=gfs2

GFS2 requiere que DLM este corriendo, por lo que ponemos una restricción:

    pcs constraint colocation add WebFS with dlm-clone INFINITY
    pcs constraint order dlm-clone then WebFS

Por último tenemos que montar el recurso del sistema de archivo *WebFS* en los dos nodos:

    pcs cluster cib active_cfg
    pcs -f active_cfg resource clone WebFS
    pcs -f active_cfg constraint
    pcs -f active_cfg resource update WebData-clone master-max=2
    pcs cluster cib-push active_cfg --config
    
    pcs resource enable WebFS

Y comprobamos como el recurso *WebFS* está montado en los dos nodos:

    pcs status
    ...
    Full List of Resources:
      * VirtualIP	(ocf::heartbeat:IPaddr2):	 Started nodo1
      * WebSite	(ocf::heartbeat:apache):	 Started nodo1
      * Clone Set: WebData-clone [WebData] (promotable):
        * Masters: [ nodo1 ]
        * Slaves: [ nodo2 ]
      * Clone Set: dlm-clone [dlm]:
        * Started: [ nodo1 nodo2 ]
      * Clone Set: WebFS-clone [WebFS]:
        * Started: [ nodo1 ]
        * Stopped: [ nodo2 ]
    ...



## Prueba de funcionamiento

* Edita el fichero `/etc/resolv.conf` de tu equipo y añade como servidor DNS primario el nodo "dns" que tiene la dirección IP `10.1.1.103`
* Comprueba la conectividad con los nodos del cluster con `ping`. Utiliza `dig` para resolver el nombre `www.example.com`:

        $ dig @10.1.1.103 www.example.com

* Comprueba que la dirección `www.example.com` está asociada a la dirección IP `10.1.1.100`, que en este escenario es la IP virtual que estará asociada en todo momento al nodo que esté en modo maestro.
* Accede a uno de los nodos del clúster y ejecuta la instrucción `pcs status`. Comprueba que los dos nodos están operativos y que los recursos `IPCluster`, `WebSite`, `WebData` y `WebFS` están funcionando correctamente en uno de ellos. En esta configuración se ha forzado que todos los recursos se ejecuten siempre en un solo nodo, que será el maestro de todos los recursos.
* Utiliza el navegador y accede a la dirección `www.example.com`. Recarga la página y comprueba que siempre responde el mismo nodo (nodo maestro).
* Apaga el nodo maestro y comprueba que los recursos pasan al otro nodo2 y que la página sigue funcionando.


Mover recurso:

pcs resource move VirtualIP nodo2
pcs resource move WebSite nodo2


Poner balanceo de carga DNS

Poner balanceador de carga en HA

HAProxy

