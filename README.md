# Escenarios Alta Disponibilidad

Escenarios para ejemplos de cluster de alta disponibilidad. Basada en el repositorio:  [https://github.com/albertomolina/Escenarios-HA](https://github.com/albertomolina/Escenarios-HA).

## Instalación de vagrant y ansible

Vagrant lo instalamos desde repositorio:

    apt install vagrant

Ansible lo podemos instalar de repositorio:

    apt install ansible

O usando un entorno virtual:

    $ python3 -m venv ansible
    $ source ansible/bin/activate
    $ pip install ansible
    (ansible) $

## Construcción de los escenarios

Cada directorio contiene todos los ficheros necesarios para montar algún tipo de escenario de alta disponibilidad o balanceo de carga de forma sencilla y automática. Los escenarios se levantan sobre KVM utilizando el plugin de vagrant [libvirt-vagrant](https://github.com/vagrant-libvirt/vagrant-libvirt).

Para poder desplegar los diferentes clústeres, basta con acceder a cada directorio y ejecutar las siguientes instrucciones:

    $ vagrant up
    $ cd ansible
    $ ansible-playbook -b site.yaml
    
## Escenarios

* [Balanceo por DNS](01-Balanceo-DNS)
* [Balanceo por DNS con nombre virtuales](02-Balanceo-DNS-Nombres-Virtuales)
* [HA con pacemaker y corosync. IP Failover](03-HA-IPFailover)
* [HA con pacemaker y corosync. IP Failover + Apache2](04-HA-IPFailover-Apache2)
* [HA con pacemaker y corosync. IP Failover + Apache2 + DRBD](05-HA-IPFailover-Apache2+DRBD)
* [HA con pacemaker y corosync. IP Failover + Apache2 + RDBD + GFS2 (Activo-Activo)](06-HA-IPFailover-Apache2+DRBD+GFS2)