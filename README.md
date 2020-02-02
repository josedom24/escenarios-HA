# Escenarios Alta Disponibilidad

Escenarios para ejemplos de cluster de alta disponibilidad para la asignatura de Seguridad Informática en el ciclo de grado superior de Administración de Sistemas Informáticos. Basada en el repositorio:  [https://github.com/albertomolina/Escenarios-HA](https://github.com/albertomolina/Escenarios-HA).

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

Cada directorio contiene todos los ficheros necesarios para montar algún tipo de escenario de alta disponibilidad o balanceo de carga de forma sencilla y automática.

Para poder desplegar los diferentes clústeres, basta con acceder a cada directorio y ejecutar las siguientes instrucciones:

    $ vagrant up
    $ cd ansible
    $ ansible-playbook -b site.yaml
