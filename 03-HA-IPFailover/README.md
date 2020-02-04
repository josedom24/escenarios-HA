# HA Ip Failover

El caso más sencillo de cluster de alta disponibilidad es utilizar dos nodos que funcionen en modo maestro esclavo y que ofrezcan como recurso de alta disponibilidad una dirección IP, que se denomina en algunos casos IP virtual.

Cada nodo del clúster posee su propia dirección IP y uno de ellos posee además la dirección IP virtual. El software de alta disponibilidad está monitorizando ambos nodos en todo momento y en el caso de que el nodo que ofrece el recurso tenga algún problema, el recurso (la dirección IP en este caso) pasa al nodo que esté en modo esclavo.

Vamos a utilizar la misma configuración de equipos que en el primer ejercicio, salvo que en esta ocasión utilizaremos la dirección IP 10.1.1.100 como IP virtual asociada a www.example.com

* `nodo1`: `10.1.1.101` <- Servidor web
* `nodo2`: `10.1.1.102` <- Servidor web
* `dns`: `10.1.1.103` <- Servidor DNS

## Levantar el escenario

Simplemente ejecutamos la instrucción:

    $ vagrant up
    $ cd ansible
    $ ansible-playbook -b site.yaml

Que levanta y configura la red en los tres nodos y configurar el escenario sin el cluster creado.

## Creación del cluster manualmente

En primer lugar vamos a hacer la configuración del cluster manualmente. Vamos a usar `pacemaker` donde vamos a crear los recursos del cluster, `corosync` que es el encargado de que los recursos del clustere estén funcionando siempre en algún nodo y `pcs` que es la utilidad para gestionar el cluster.

Lo primero que hacemos es instalar los paquetes:

    apt install pacemaker pcs

A continuación cambiamos en los dos nodos la contraseña del usuario `hacluster` (para este ejemplo ponemos como contrasña `hacluster`):

    passwd hacluster

Los nodos del cluster deben ser conocidos por el resto de nodos, por la tanto en el fichero `/etc/hosts` de los nodos indicamos la siguiente configuración:

    10.1.1.101    nodo1
    10.1.1.102    nodo2

Las instrucciones que vienen a continuación se realizan en un solo nodo del cluster, por ejemplo en el `nodo1`. 
Durante la instalación del sistema ya se ha creado un cluster, por lo que lo primero es eliminar el cluster actual:

    pcs cluster destroy

Autentificar los nodos que van a pertenecer al cluster:

    pcs host auth nodo1 nodo2 -u hacluster -p hacluster

Y crear un cluster que llamaremos `mycluster`:

    pcs cluster setup mycluster nodo1 nodo2 --start --enable --force

Para asegurar que los datos del cluster no se puedan corromper la propiedad `stonith` está habilitada por defecto, en nuestro caso para que funcione el cluster es necesario deshabilitarla:

    pcs property set stonith-enabled=false

Por último vamos a crear un recurso del tipo `ocf:heartbeat:IPaddr2`que nos permite que el cluster gestione una ipv4 que se asignará a la interface `eth1``de uno de los nodos. Si el nodo que tiene asignado el recurso no funciona, automáticamente se asignará al otro nodo.

    pcs resource create VirtualIP ocf:heartbeat:IPaddr2 ip=10.1.1.100 cidr_netmask=32 nic=eth1 op monitor interval=30s

Comprobamos el estado del cluster:

    pcs status

    pcs status
    Cluster name: mycluster
    Stack: corosync
    Current DC: nodo1 (version 2.0.1-9e909a5bdd) - partition with quorum
    Last updated: Tue Feb  4 14:59:10 2020
    Last change: Tue Feb  4 14:41:22 2020 by hacluster via crmd on nodo1

    2 nodes configured
    1 resource configured

    Online: [ nodo1 nodo2 ]

    Full list of resources:

     VirtualIP	(ocf::heartbeat:IPaddr2):	Started nodo1

    Daemon Status:
      corosync: active/enabled
      pacemaker: active/enabled
      pcsd: active/enabled

Vemos como el cluster tiene configurado 2 nodos y un recurso, una IP virtual del tipo `ocf::heartbeat:IPaddr2` asignada al `nodo1`.
Si comprobamos la interface `eth1` del `nodo1` lo podemos comprobar:

    ip a show eth1
    3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
        link/ether 08:00:27:4c:68:a8 brd ff:ff:ff:ff:ff:ff
        inet 10.1.1.101/24 brd 10.1.1.255 scope global eth1
           valid_lft forever preferred_lft forever
        inet 10.1.1.100/32 brd 10.1.1.255 scope global eth1
           valid_lft forever preferred_lft forever

## Prueba de funcionamiento

* Edita el fichero `/etc/resolv.conf` de tu equipo y añade como servidor DNS primario el nodo "dns" que tiene la dirección IP `10.1.1.103`
* Comprueba la conectividad con los nodos del cluster con ping Utiliza dig para resolver el nombre `www.example.com`:

    $ dig @10.1.1.103 www.example.com

* Comprueba que la dirección `www.example.com` está asociada a la dirección IP `10.1.1.100`, que en este escenario es la IP virtual que estará asociada en todo momento al nodo que esté en modo maestro.
* Accede a uno de los nodos del clúster y ejecuta la instrucción `pcs status`. Comprueba que los dos nodos están operativos y que el recurso
IPCluster está funcionando correctamente en uno de ellos.
* Haz ping a `www.example.com` desde la máquina anfitriona y comprueba la tabla arp. Podrás verificar que la dirección MAC asociada a la dirección IP `10.1.1.100` coincide con la del nodo maestro en estos momentos.
* Para el nodo maestro (supongamos que es `nodo1`):

    $ vagrant halt node2

* Haz ping a `www.example.com` y comprueba que la tabla arp ha cambiado. Ahora la dirección MAC asociada a la dirección IP `10.1.1.100` es la del otro nodo.
* Entra en el nodo maestro y comprueba el estado del clúster con `pcs status`.
* Levanta de nuevo el nodo que estaba parado. Los recursos no van a volver a él porque en la configuración se ha penalizado el movimiento de los recursos, estos tienden a quedarse en el nodo en el que se están ejecutando, no a volver al nodo que era maestro
* Si queremos que cuando un nodo este levantado el recurso se asigne a este nodo tenemos que crear una restricción de localización de afinidad, por ejemplo cuando el nodo1 este levantado se le asigna el recurso indicamos los siguiente:

    pcs constraint location VirtualIP prefers nodo1=INFINITY

* Podmos ver las restricciones que tenemos asignadas:

    pcs constraint show
    Location Constraints:
      Resource: VirtualIP
        Enabled on: nodo1 (score:INFINITY)
    Ordering Constraints:
    Colocation Constraints:
    Ticket Constraints:

* Vuelve a apacgar el `nodo1` comprueba que el recurso se asigna al `nodo2`, vuelve a encender el `nodo1` y comprueba que por la restricción de localización el recurso vuelve a `nodo1`.

* Para eleminar la restricción ejecutamos:

    pcs constraint rm location-VirtualIP-pcmk-1-INFINITY

* Por último accede desde un navegador web a `www.example.com` comprueba al nodo al que esta accediendo, para ese nodo y comprueba que se accede al otro nodo.

## Creación del cluster de forma automática

He creado otro playbook para crear el cluster desde ansible, para ello simplemente:

    $ ansible-playbook -b site_cluster.yaml