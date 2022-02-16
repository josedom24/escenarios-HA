# Balanceo por DNS con nombres virtuales

* [Balanceo de carga por DNS](https://www.josedomingo.org/pledin/2022/02/dns-balanceo-carga/)

## Levantar el escenario

Simplemente ejecutamos la instrucción:

    $ vagrant up
    $ cd ansible
    $ ansible-playbook site.yaml

Que levanta y configura la red en los tres nodos y configurar el escenario.

## Prueba de funcionamiento

En este caso podemos preguntar a nuestro servidor dns principal:

    $ dig @10.1.1.103 www.example.com

Aunque la respuesta no cambia mucho, podemos obtener las direcciones de los dos servidores como respuestas. Prueba a parar un servidor y vuelve a realizar la consulta, **¿qué dirección te da?**

Añadimos la dirección IP como servidor DNS primario la dirección `10.1.1.103` y podemos probar:

    while [ True ]; do curl http://www.example.com/info.txt && sleep 1 ; done

    nodo1
    nodo2
    ...

**En esta ocasión si paramos un servidor las resoluciones siempre nos devolverán la ip del otro servidor.**

