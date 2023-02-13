# Fencing y STONITH (Shoot The Other Node In The Head)

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

      hostlist="nodo1:07-HA-IPFailover-Apache2DRBDGFS2_nodo1,nodo2:06-HA-IPFailover-Apache2DRBDGFS2_nodo2"
  
* `hypervisor_uri`: La uri del sistema de virtualización KVM. En nuestro caso:

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

