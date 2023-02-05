# Balanceo con HAProxy

HAProxy, (High Availability Proxy (Proxy de alta disponibilidad)), es un popular
software de código abierto TCP/HTTP Balanceador de carga y una solución de proxy
que se puede ejecutar en Linux, Solaris y FreeBSD. Su uso más común es mejorar el
rendimiento y la confiabilidad de un entorno de servidor distribuyendo la carga de
trabajo entre múltiples servidores (por ejemplo, web, aplicación, base de datos).

## Levantar el escenario

Simplemente ejecutamos la instrucción:

    $ vagrant up
    $ cd ansible
    $ ansible-playbook site.yaml

Que levanta y configura la red en los tres nodos y configurar el escenario.

## Prueba de funcionamiento

En este caso cuando accedemos a `www` estaremos accidiendo al nodo balanceador de carga, donde hemos instalado HAPorxy, podemos preguntar a nuestro servidor dns principal:

    $ dig @10.1.1.103 www.example.com

A continuación vamos a configurar el balanceador de carga HAProxy:

```
vagrant ssh lb
```

Para ello añade la siguiente configuración en el fichero `/etc/haproxy/haproxy.cfg`:

```
frontend servidores_web
	bind *:80 
	mode http
	stats enable
	stats uri /ha_stats
	stats auth  cda:cda
	default_backend servidores_web_backend

backend servidores_web_backend
	mode http
	balance roundrobin
	server nodo1 10.1.1.101:80 check
	server nodo2 10.1.1.102:80 check
```

* La sección **frontend** representa al balanceador de carga, que va a escuchar n todas las interfaces en el puerto 80, en modo http, que va a ofrecer estadística en la URL `/ha_stats` y que va a balancear en los servidores definido en el `default_backend`.
* La sección **backend** define los servidores entre los que se va a balancear, el tipo de balanceo y el modo.


Reiniciamos el servidor HAProxy y en nuestro ordenador añadimos la dirección IP como servidor DNS primario la dirección `10.1.1.103` y podemos probar:

    while [ True ]; do curl http://www.example.com/info.txt && sleep 1 ; done

    nodo1
    nodo2
    ...

Podemos controlar nuestro balanceador de carga HAProxy accediiendo a las estadísticas y controlando a que nodos se está balanceado la carga utilizando la herramienta `hatop`:

```
vagrant ssh lb
sudo apt install hatop
```

Y conectamos a un socket unix donde escucha HAProxy:

```
sudo hatop -s /run/haproxy/admin.sock
```

Podemos ver los frontend y backend que tenemos definido, además podemos las peticiones que se están balanceado en cada nodo. Podemos activar o desactivar un nodo del backend, para ello lo seleccionamos y pulsamos F10 para desactivar y F9 para activar.


