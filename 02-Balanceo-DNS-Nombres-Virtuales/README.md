# Balanceo por DNS con nombres virtuales

En el escenario anterior vimos que si un servidor web deja de funcionar, cuando se balancee la carga hacía el por medio del dns no podremos conectar.

Un solucón es considerar el nombre del servicio `www.example.com` como un nombre virtual, es decir será un alias (CNAME) de un nombre de un subdominio que estará delegado en dos servidores dns que instalaremos en los servidores que ofrecen el servicio (en nuestro caso en los servidores web).

## Configuración de bind9

Como hemos dicho la en la zona de resolución directa indicaremos que el nombre que queremos balancear `www.example.com` es un alias de un nombre de un subdominio delegado: `www.http.example.com`, e indicamos que los servidores con autoridad para este subdominio serán `nodo1` y `nodo2`:

    ...
    www     IN  CNAME   www.http
    http    IN  NS      nodo1
    http    IN  NS      nodo2

## Configuración de los servidores DNS delegados

Como hemos dicho en `nodo1` y `nodo2` tenemos que instalar un servidor DNS con autoridad para la zona `http.example.com`. Para que sea más fácil de configurar vamos a instalar un servidor `dnsmasq`, y la configuración será la siguiente:

En el fichero `/etc/dnsmasq.conf` de `nodo1`:

    address=/www.http.example.com/10.1.1.101

En el fichero `/etc/dnsmasq.conf` de `nodo2`:

    address=/www.http.example.com/10.1.1.102

En ambos ficheros, al estar trabajando con vagrant le tendremos que indicar la interfaz de escucha como `eth1`:

    interface=eth1

## Levantar el escenario

Simplemente ejecutamos la instrucción:

    $ vagrant up
    $ cd ansible
    $ ansible-playbook -b site.yaml

Que levanta y configura la red en los tres nodos y configurar el escenario

## Prueba de funcionamiento

En este caso podemos preguntar a nuestro servidor dns principal:

    $ dig @10.1.1.103 www.example.com

Aunque la respuesta no cambia mucho, podemos obtener las direcciones de los dos servidores como respuestas. Prueba a parar un servidor y vuelve a realizar la consulta, **¿qué dirección te da?**

Añadimos la dirección IP como servidor DNS primario la dirección `10.1.1.103` y podemos probar:

    while
    do
        curl http://www.example.com/info.txt
    done

    nodo1
    nodo2
    ...

**En esta ocasión si paramos un servidor las resoluciones siempre nos devolverán la ip del otro servidor.**

