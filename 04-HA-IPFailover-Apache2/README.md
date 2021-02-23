# HA con pacemaker y corosync. IP Failover + Apache2

Partiendo del ejercicio de IP Failover, vamos a agregar el recurso apache al sistema de gestión del cluster. De esta forma el clúster controlará que el servicio esté siempre operativo en el nodo maestro, además como tenemos asociada la dirección `www.example.com` a la IP virtual `10.1.1.100`, accederemos siempre al servidor web del nodo maestro al poner en el navegador la dirección `www.example.com`

* `nodo1`: `10.1.1.101` <- Servidor web
* `nodo2`: `10.1.1.102` <- Servidor web
* `dns`: `10.1.1.103` <- Servidor DNS
* `www.example.com`: `10.1.1.100`

## Levantar el escenario

Simplemente ejecutamos la instrucción:

    $ vagrant up
    $ cd ansible
    $ ansible-playbook -b site.yaml

Que levanta y configura la red en los tres nodos y configurar el escenario sin el cluster creado. 

**Nota: Si utilizas vagrant con libvirt** tienes que utilizar el inventario `host_libvirt`, para ello, modifica el fichero `ansible.cfg` y modifica la línea:

    inventory = hosts_libvirt

En este escenario el fichero `init_cluster.sh` que ejecutamos en el cluster crea un nuevo recurso:

    pcs resource create WebSite ocf:heartbeat:apache  \
      configfile=/etc/apache2/apache2.conf \
      statusurl="http://localhost/server-status" \
      op monitor interval=1min

Por lo una vez terminada la instalación nos encontramos el siguiente estado en el cluster:

    $ pcs status

    Cluster name: mycluster
    Stack: corosync
    Current DC: nodo2 (version 2.0.1-9e909a5bdd) - partition with quorum
    Last updated: Wed Feb  5 16:31:27 2020
    Last change: Wed Feb  5 16:30:30 2020 by hacluster via crmd on nodo2

    2 nodes configured
    2 resources configured

    Online: [ nodo1 nodo2 ]

    Full list of resources:

     VirtualIP	(ocf::heartbeat:IPaddr2):	Started nodo1
     WebSite	(ocf::heartbeat:apache):	Started nodo2

    Daemon Status:
      corosync: active/enabled
      pacemaker: active/enabled
      pcsd: active/enabled


## Asegurar que los recursos se ejecutan en el mismo nodo

Como vemos cada recurso se ha levantado en un nodo. (**Comprueba que en el nodo1 tiene la IP virtual, y en el nodo2 existen los procesos de apache2**).

Por defecto corosync intenta distribuir los distintos recursos entre los nodos del cluster, pero en ocasiones (como es el caso de nuestro ejemplo) es necesario que los dos recursos se asignen a un mismo nodo. En nuestro caso el recurso `WebSite` sólo puede ejecutarse en el nodo donde tiene asignado el recurso `VirtualIP`. Para ello vamos a crear una restricción de colocación:

    $ pcs constraint colocation add WebSite with VirtualIP INFINITY

    $ pcs constraint 
    
    Location Constraints:
    Ordering Constraints:
    Colocation Constraints:
      WebSite with VirtualIP (score:INFINITY)
    Ticket Constraints:

Y ahora comprobamos la asignación de los recursos:

    $ pcs status

    ...
    VirtualIP	(ocf::heartbeat:IPaddr2):	Started nodo1
    WebSite	(ocf::heartbeat:apache):	Started nodo1

## Ordenando los recursos

Al igual que muchos servicios, Apache puede configurarse para escuchar en una dirección específica. En la configuración por defecto de apache (`<VirtualHost *:80>`) es indiferente que la IP este asignada antes o después de arrancar el servidor web. Sin embargo, si Apache se configure para que escuche en una determinada IP (`<VirtualHost 10.1.1.100:80>`) es necesario tener asignada la IP antes de arrancar el servicio.
Para asegurarnos de que nuestro sitio web responda independientemente de la configuración de dirección de Apache, debemos asegurarnos de que `VirtualIP` no solo se ejecute en el mismo nodo sino que se inicie antes que el sitio web. Para ello creamos una restricción de orden:

    $ pcs constraint order VirtualIP then WebSite

    $ pcs constraint 
    
    Location Constraints:
    Ordering Constraints:
      start VirtualIP then start WebSite (kind:Mandatory)
    Colocation Constraints:
      WebSite with VirtualIP (score:INFINITY)
    Ticket Constraints:

## Prueba de funcionamiento

* Edita el fichero `/etc/resolv.conf` de tu equipo y añade como servidor DNS primario el nodo "dns" que tiene la dirección IP `10.1.1.103`
* Comprueba la conectividad con los nodos del cluster con ping Utiliza dig para resolver el nombre `www.example.com`:

        $ dig @10.1.1.103 www.example.com

* Comprueba que la dirección `www.example.com` está asociada a la dirección IP `10.1.1.100`, que en este escenario es la IP virtual que estará asociada en todo momento al nodo que esté en modo maestro.
* Accede a uno de los nodos del clúster y ejecuta la instrucción `pcs status`. Comprueba que los dos nodos están operativos y que los recursos VirtualIP y WebSite están funcionando correctamente en uno de ellos. En esta configuración se ha forzado que todos los recursos se ejecuten siempre en un solo nodo, que será el maestro de todos los recursos.
* Utiliza el navegador y accede a la dirección `www.example.com`. Recarga la página y comprueba que siempre responde el mismo nodo (nodo maestro).
* Entra en el nodo maestro por ssh y para el servicio apache. Comprueba que transcurridos unos instantes el servicio vuelve a estar levantado en ese nodo (corosync se encarga de volver a levantarlo). ¿Qué diferencias encuentras entre esta configuración y la del ejercicio de balanceo DNS?
* Para el nodo maestro con vagrant y comprueba el estado del clúster con `pcs status` en el otro nodo. Verifica que es posible acceder con el navegador al sitio `www.example.com`, pero que ahora el contenido lo sirve el otro nodo. **¿Piensas que esta configuración es suficiente para ejecutar contenido web dinámico?**