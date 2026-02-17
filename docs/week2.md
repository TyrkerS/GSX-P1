# Week 2 — Serveis, Observabilitat i Automatització

## Context i objectiu
Durant la Week 2 hem passat d’un servidor amb processos gestionats “a mà” a un sistema **robust, observable i automatitzat**. L’objectiu principal ha estat:

- Executar serveis de manera fiable amb **systemd**
- Assegurar que els serveis **s’inicien automàticament** en arrencar el sistema
- Garantir **recuperació automàtica** en cas de fallada
- Implementar **backups automàtics verificables**
- Disposar de **traçabilitat (logs)** per diagnosticar problemes

---

## Arquitectura i decisions preses

### Gestió de serveis amb systemd
Hem decidit utilitzar **systemd** com a gestor de serveis perquè:
- És l’estàndard en Debian
- Permet definir dependències, reinicis automàtics i arrencada al boot
- Proporciona una integració directa amb el sistema de logs (**journald**)

**Servei Nginx**
- S’ha instal·lat Nginx com a servidor web
- S’ha activat l’arrencada automàtica amb:
  ```bash
  systemctl enable nginx

S’ha creat un override de systemd per assegurar reinici automàtic en cas de fallada:

    [Service]
    Restart=on-failure
    RestartSec=2s

Hem preferit un override en lloc de modificar la unitat original per mantenir compatibilitat amb actualitzacions del paquet.

Motivació: en entorns reals no es pot dependre de reinicis manuals; systemd ens ofereix una solució declarativa i robusta.

### Servei de backups amb systemd + timer

S’ha creat un **servei propi** de systemd (p1-backup.service) que executa un script de backup, i un timer (p1-backup.timer) que el dispara automàticament cada dia.

    - Tipus de servei: oneshot (s’executa i finalitza)

    - Execució programada amb systemd timers (alternativa moderna a cron)

    - Logs del backup disponibles a journald

    - Verificació manual possible amb:

        systemctl start p1-backup.service

**Decisió**: hem triat systemd timers en lloc de cron perquè:

    - Estan integrats amb systemd

    - Permeten persistència (si el sistema estava apagat, el backup s’executa en tornar a arrencar)

    - Tenen millor observabilitat (estat i logs amb systemctl i journalctl)

### Observabilitat i logs

Tota l’activitat dels serveis queda registrada a journald.
Hem creat scripts per facilitar la consulta:

    **show-nginx-logs.sh** → mostra logs recents de Nginx

    **show-backup-logs.sh** → mostra logs del servei de backups

    **status-week2.sh** → estat de serveis, timers i ús de disc de logs

Motivació: en un entorn d’operacions, els logs són la principal font d’informació per entendre errors. Tenir scripts d’observabilitat facilita la diagnosi ràpida.

### Gestió de l’espai de logs

Per evitar que els logs ocupin tot el disc, hem configurat límits a journald (retenció i espai màxim).
Això garanteix que el sistema no quedi sense espai per creixement incontrolat de logs.
**Verificació del funcionament**
Estat del servei Nginx:

    - systemctl status nginx
    - journalctl -u nginx

Estat del servei de backups:

    - systemctl status p1-backup.service
    - journalctl -u p1-backup.service

Timers actius:

    - systemctl list-timers --all | grep p1-backup

Verificació de backups:

        Es genera un arxiu .tar.gz a la carpeta backups/

        Els logs confirmen l’execució correcta del servei

## Resposta a les preguntes de l’enunciat
**Què hauria de passar si Nginx cau a les 3 del matí?**

Gràcies a la configuració de systemd amb Restart=on-failure, el servei es reinicia automàticament.
L’incident queda registrat a journald, de manera que l’endemà es pot consultar què ha passat:

    journalctl -u nginx --since "today"

En un entorn real, aquest mecanisme es podria complementar amb alertes (monitorització externa).

**Com comprovem que un servei es reinicia automàticament?**

No cal esperar que falli “de veritat”. Podem simular una fallada:

    sudo kill -9 $(pidof nginx)

I després comprovar:

    systemctl status nginx
    journalctl -u nginx

Això demostra que el servei es recupera i que l’error queda registrat als logs.

**Si els backups fallen silenciosament, com ho sabríem?**

L’estat del servei i del timer és visible amb:

    systemctl status p1-backup.service
    systemctl list-timers

Els logs de l’execució del backup queden a:

    journalctl -u p1-backup.service

L’absència de nous fitxers a la carpeta backups/ també és un indicador de problema.

En un entorn productiu, aquests indicadors es podrien convertir en alertes automàtiques.

**Com explicaríem una fallada del servei a l’equip utilitzant només logs?**

Consultaríem:

    journalctl -u nginx

o

    journalctl -u p1-backup.service

I explicaríem:

    - Hora de la fallada

    - Missatge d’error concret

    - Accions automàtiques del sistema (reinici del servei)

    - Estat final del servei

Això permet una comunicació clara i basada en evidències, no en suposicions.

