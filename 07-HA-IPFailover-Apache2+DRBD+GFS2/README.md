# HA con pacemaker y corosync. IP Failover + Apache2 + RDBD + GFS2 (Activo-Activo)

Partiendo del ejercicio de IP Failover + Apache2 + DRBD,  vamos a agregar un sistema de almacenamiento distribuido [GFS2](https://es.wikipedia.org/wiki/Global_File_System_(Red_Hat)), por lo que podremos configurar nuestros sistema DRBD como *Dual-primary*, y la IP *ClusterIP* podrá estar asignado a cualquiera de los nodos, ya que los nodos podrán escribir o leer al mismo tiempo.

En definitiva, vamos a convertir nuestro clúster en **activo-activo**.

No vamos a activar el STONITH, pero si quieres aprender un poco más sobre el fencing, puedes leer [Fencing y STONITH (Shoot The Other Node In The Head)](fencing.md).

## Instalación de GFS2

En este apartado vamos a configurar GFS2 como sistema de almacenamiento distribuido para conseguir el cluster de alta disponibilidad activo-activo.

Además vamos a instalar el programa DLM (*Distributed Lock Manager*) que será el encargado de gestionar el acceso del clúster al almacenamiento distribuido.

Ejecutamos en los dos nodos:

    apt install gfs2-utils dlm-controld

 
## Configuración de DLM en nuestro cluster de alta disponibilidad

El DLM se tiene que ejecutar en los dos nodos, vamos a crear un recurso **ocf:pacemaker:controld** y lo vamos a clonar. Ejecutamos en el nodo1:

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

Y formateamos el dispositivo de bloque (en el nodo1):

    mkfs.gfs2 -p lock_dlm -j 2 -t mycluster:web /dev/drbd1

* `-p lock_dlm`: Indica que vamos a usar el programa DLM (*Distributed Lock Manager*) para gestionar los cambiso del sistema de archivo.
* `-j 2`: Se va a reservar espacio para 2 journals (registro donde se almacena información necesaria para recuperar los datos afectados por una transición en caso de que falle) uno para cada nodo.
* `-t mycluster:web`: El nombre de la tabla de bloqueo (lock) (`web`) en el cluster `mycluster` (nombre del cluster que indicamos al crearlo con corosync y que lo podemos encontrar en `/etc/corosync/corosync.conf`).

A continuación podemos guardar información en el dispositivo de bloques. Creamos el fichero `index.html`:

    mount /dev/drbd1 /mnt
    cd /mnt/
    echo "<h1>Prueba con GFS2</h1>" >> index.html
    umount /mnt

## Reconfigurar el cluster para GFS2

Tenemos que cambiar el tipo de sistema de archivo en el recurso *WebFS*:

    pcs resource update WebFS fstype=gfs2

GFS2 requiere que DLM este corriendo, por lo que ponemos dos restricciones:

    pcs constraint colocation add WebFS with dlm-clone INFINITY
    pcs constraint order dlm-clone then WebFS

Por último tenemos que montar el recurso del sistema de archivo *WebFS* en los dos nodos y modificar el recurso *WebData-clone** para indicar que ambos nos se pongan como primarios en el DRBD.

    pcs cluster cib active_cfg
    pcs -f active_cfg resource clone WebFS
    pcs -f active_cfg constraint
    pcs -f active_cfg resource update WebData-clone promoted-max=2
    pcs cluster cib-push active_cfg --config
    
    pcs resource enable WebFS

Y comprobamos como el recurso *WebFS* está montado en los dos nodos y que 

    pcs status
    ...
    Full List of Resources:
      * VirtualIP	(ocf::heartbeat:IPaddr2):	 Started nodo1
      * WebSite	(ocf::heartbeat:apache):	 Started nodo1
      * Clone Set: WebData-clone [WebData] (promotable):
        * Masters: [ nodo1 nodo2 ]
      * Clone Set: dlm-clone [dlm]:
        * Started: [ nodo1 nodo2 ]
      * Clone Set: WebFS-clone [WebFS]:
        * Started: [ nodo1 nodo2 ]

    ...

En este momento tenemos el DRBD como dual-primary y el sistema de ficheros GFS2 montado en los dos nodos. Cualquiera de los servidores web pueden escribir ficheros en `/var/www/html`, por lo que podemos clonar el recurso *WebSite* y quitar la restricción de colocación que hacía que el servidor web se activa en el nodo que tenía asignada la *VirtualIP*. Para ello:

    pcs cluster cib active_cfg
    pcs -f active_cfg resource clone WebSite
    pcs cluster cib-push active_cfg --config

    pcs constraint colocation delete WebSite-clone VirtualIP

Ahora la *VirtualIP* puede estar asignada a cualquier nodo y el clúster funcionaría de forma correcta. Por lo que si un nodo falla, la *VirtualIP* se asignará al otro y el clúster seguirá funcionando.


## Prueba de funcionamiento

* Edita el fichero `/etc/resolv.conf` de tu equipo y añade como servidor DNS primario el nodo "dns" que tiene la dirección IP `10.1.1.103`
* Comprueba la conectividad con los nodos del clúster con `ping`. Utiliza `dig` para resolver el nombre `www.example.com`:

        $ dig @10.1.1.103 www.example.com

* Comprueba que la dirección `www.example.com` está asociada a la dirección IP `10.1.1.100`, que en este escenario es la IP virtual que estará asociada en todo momento al nodo que esté en modo maestro.
* Accede a uno de los nodos del clúster y ejecuta la instrucción `pcs status`. Comprueba que los dos nodos están operativos y que los recursos están asignados a los dos nodos (excepto el *VirtualIP*)
* Utiliza el navegador y accede a la dirección `www.example.com`. Recarga la página y comprueba que siempre responde el nodo que tiene asignada la *VirtualIP*.
* Puedes mover el recurso *VirtualIP* al ootro nodo y comprobar que sigue funcionando: `pcs resource move VirtualIP nodo2`.
* Apaga el nodo que tiene asignada la *VirtualIP* y comprueba que se asigna al otro nodo y sigue funcionando el cluster.

## Balanceo de carga

* Balanceo por DNS: Podríamos quitar el recurso *VirtualIP* y hacer un balanceo de carga por DNS como vimos en el escenario 1 y el 2.
* Añadir un balanceador de carga HAProxy en cada nodo (que balancee la carga entre los dos servidores web) y configurar un recurso del clúster para que los controle. Para ello habría que crear un recurso con pacemaker para controlar los balanceadores de carga, y se podría configurar como activo-pasivo o activo-activo.
