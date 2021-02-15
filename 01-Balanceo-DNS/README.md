# Balanceo por DNS

Utilizando entradas tipo A duplicadas en un servidor DNS es posible realizar de forma muy sencilla un balanceo de carga entre varios equipos, esto se conoce como [DNS round robin](http://en.wikipedia.org/wiki/Round-robin_DNS).

En este caso vamos a realizar un balanceo de carga entre dos servidores web, para lo que creamos un escenario con tres equipos:

* `nodo1`: `10.1.1.101` <- Servidor web
* `nodo2`: `10.1.1.102` <- Servidor web
* `dns`: `10.1.1.103` <- Servidor DNS

## Levantar el escenario

Simplemente ejecutamos la instrucción:

    $ vagrant up
    $ cd ansible
    $ ansible-playbook -b site.yaml

Que levanta y configura la red en los tres nodos y configurar el escenario.

**Nota: Si utilizas vagrant con libvirt** tienes que utilizar el inventario `host_libvirt`, para ello, modifica el fichero `ansible.cfg` y modifica la línea:
    inventory = hosts_libvirt



## Prueba de funcionamiento

Si no ha habido errores durante la ejecución de los playbooks, se puede comprobar que se realiza el balanceo `www.example.com` entre nodo1 y nodo2, repitiendo la consulta DNS con dig:

    $ dig @10.1.1.103 www.example.com

También puede verse de forma mucho más clara a través del navegador, para lo cual es necesario añadir la dirección IP como servidor DNS primario la dirección `10.1.1.103` y podremos comprobar como se balancean las peticiones entre los dos servidores web nodo1 y nodo2 (es necesario forzar la recarga, `CTRL+F5` por ejemplo).

Otra prueba que podemos hacer es:

    while [ True ]; do curl http://www.example.com/info.txt && sleep 1 ; done

    nodo1
    nodo2
    ...

**¿Qué pasa si un nodo se apaga?**

