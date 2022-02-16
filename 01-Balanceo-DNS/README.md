# Balanceo por DNS

* [Balanceo de carga por DNS](https://www.josedomingo.org/pledin/2022/02/dns-balanceo-carga/)

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

