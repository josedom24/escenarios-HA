# HA con pacemaker y corosync. IP Failover + Apache2 + RDBD + GFS2 (Activo-Activo)

Partiendo del ejercicio de IP Failover + Apache2 + DRBD,  vamos a agregar un sistema de almacenamiento distribuido [GFS2](https://es.wikipedia.org/wiki/Global_File_System_(Red_Hat)), por lo que podremos configurar nuestros sistema DRBD como *Dual-primary*, y la IP *ClusterIP* podrá estar asignado a cualquiera de los nodos, ya que los nodos podrán escribir o leer al mismo tiempo.

En definitiva, vamos a convertir nuestro cluster en **activo-activo**.

## Fencing y STONITH (Shoot The Other Node In The Head)

El fencing (cercado o vallado) es una cualidad del cluster que permite que un nodo no utilice un recurso que no debe usar, por ejemplo si tenemos información compartida en un sistema de almacenamiento DRBD, el cluster debería asegurar que sólo escribe el nodo que tiene asigna el rol de primario. El fencing protege la información del cluster para que la aplicación se quede no disponible.

El STONITH es la implementación del fencing que nos proporciona un cluster de corosyng/pacemaker y que usando un agente de fencing, el cluster es capaz de controlar los nodos, y si es necesario es capaz de apagar un nodo que no esté funcionando de manera adecuada.

En los primeros ejemplos que vimos, desactivanos esta característica, pero en el momento que tenemos un recurso compartido para varios nodos (DRBD) los logs del sistema nos avisan que es necesario tener activado un método de fencing para evitar que convirtamos la información en inconsistente.

En el escenario anterior nos aparece los siguientes errores:

```
# journalctl -u pacemaker | grep error
Feb 13 17:22:00 nodo1 pacemaker-schedulerd[4559]:  error: Resource start-up disabled since no STONITH resources have been defined
Feb 13 17:22:00 nodo1 pacemaker-schedulerd[4559]:  error: Either configure some or disable STONITH with the stonith-enabled option
Feb 13 17:22:00 nodo1 pacemaker-schedulerd[4559]:  error: NOTE: Clusters with shared data need STONITH to ensure data integrity
```

Y al cabo de unos minutos el servicio del cluster se desactiva.

### Configuración del stonith usando el agente external/libvirt

El objetivo del fencing es poder desconectar un nodo o un recurso compartido, si el nodo tiene algún problema. Dependiendo del tipo del nodo o el recurso, esto se puede hacer con soluciones hardware (SAI inteligentes, IPMI,...) o software. Para ello tenemos diferentes agentes de fencing a nuestra disposición:

```
# pcs stonith list
```

En nuestro caso al tener máquinas kvm en nuestro escenario vamos a usar el agente `external/libvirt` ([documentación](https://hawk-guide.readthedocs.io/en/latest/stonith.html)). Este agente proporciona al cluster la funcionalidad (usando `virsh`) de apagar un nodo que tenga algún problema. Por lo tanto en los nodos vamos a instalar los clientes de libvirt:

```
apt install libvirt-clients
```

Además los nodos deben poder acceder al host por ssh con el usuario root sin contraseña. Para ello vamos a crear un par de calves pública y privada en cada nodo y vamos a configurar el host para permitir el acceso. En cada nodo:

```
# ssh-keygen -t rsa
# ssh-copy-id 192.168.121.1
```

Ahora podemos comprobar los parámetro necesario que necesitamos para configurar el stonith con el agente `external/libvirt`, para ello:

```
# pcs stonith describe external/libvirt
```

Y podemos ver que tenemos que indicar al menos dos parámetros obligatoriamente:

* `hostlist`: Una lista que relaciona los hostnames de los nodos del cluster con el nombre de la máquina virtual en el hypervisor. En nuestro caso el valor sería:

    hostlist="nodo1:06-HA-IPFailover-Apache2DRBDGFS2_nodo1,nodo2:06-HA-IPFailover-Apache2DRBDGFS2_nodo2"
  
* `hypervisor_uri`: La uri del sistema de virtualización KVM. en nuestro caso:

    qemu+ssh://192.168.121.1/system

Con esos datos habilitamos el fencing en el cluster ejecutando:

```
pcs cluster cib stonith_cfg
pcs -f stonith_cfg stonith create fencing-libvirt external/libvirt \
 hostlist="nodo1:06-HA-IPFailover-Apache2DRBDGFS2_nodo1,nodo2:06-HA-IPFailover-Apache2DRBDGFS2_nodo2" \
 hypervisor_uri="qemu+ssh://192.168.121.1/system"
pcs -f stonith_cfg property set stonith-enabled=true
pcs cluster cib-push stonith_cfg --config
```

Si quieres probarlo puedes ejecutar desde el nodo1:

```
# pcs cluster stop nodo2
# stonith_admin --reboot nodo2
```


## Instalación de GFS2

En este apartado vamos a configurar GFS2 como sistema de almacenamiento distribuido para conseguir el cluster de alta disponibilidad activo-activo.

Además vamos a instalar el programa DLM (*Distributed Lock Manager*) que será el encargado de gestionar el acceso del cluster al almacenamiento distribuido.

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

En este momento tenemos el DRBD como dual-primary y el sistema de ficheros GFS2 montado en lso dos nodoos. Cualquiera de los servidores web pueden escribir ficheros en `/var/www/html`, por lo que podemos clonar el recurso *WebSite* y quitar la restricción de colocación que hacía que el servidor web se activa en el nodo que tenía asignada la *VirtualIP*. Para ello:

    pcs cluster cib active_cfg
    pcs -f active_cfg resource clone WebSite
    pcs cluster cib-push active_cfg --config

    pcs constraint colocation delete WebSite-clone VirtualIP

Ahora la *VirtualIP* puede estar asignada a cualquier nodo y el cluster funcionaría de forma correcta. Por lo que si un nodo falla, la *VirtualIP* se asignará al otro y el cluster seguirá funcionando.


## Prueba de funcionamiento

* Edita el fichero `/etc/resolv.conf` de tu equipo y añade como servidor DNS primario el nodo "dns" que tiene la dirección IP `10.1.1.103`
* Comprueba la conectividad con los nodos del cluster con `ping`. Utiliza `dig` para resolver el nombre `www.example.com`:

        $ dig @10.1.1.103 www.example.com

* Comprueba que la dirección `www.example.com` está asociada a la dirección IP `10.1.1.100`, que en este escenario es la IP virtual que estará asociada en todo momento al nodo que esté en modo maestro.
* Accede a uno de los nodos del clúster y ejecuta la instrucción `pcs status`. Comprueba que los dos nodos están operativos y que los recursos están asignados a los dos nodos (excepto el *VirtualIP*)
* Utiliza el navegador y accede a la dirección `www.example.com`. Recarga la página y comprueba que siempre responde el nodo que tiene asignada la *VirtualIP*.
* Puedes mover el recurso *VirtualIP* al ootro nodo y comprobar que sigue funcionando: `pcs resource move VirtualIP nodo2`.
* Apaga el nodo que tiene asignada la *VirtualIP* y comprueba que se asigna al otro nodo y sigue funcionando el cluster.

## Balanceo de carga

* Balanceo por DNS: Podríamos quitar el recurso *VirtualIP* y hacer un balanceo de carga por DNS como vimos en el escenario 1 y el 2.
* Añadir un balanceador de carga HAProxy (que balancee la carga entre los dos servidores web) y configurar un recurso del cluster para que los controle. Para ello habría que crear un recurso con pacemaker para controlar los balanceadores de carga, y se podría configurar como activo-pasivo o activo-activo.