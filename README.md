# Pràctica 1 -- Gestió de Sistemes i Xarxes

## Objectiu

Aquest repositori conté la configuració automatitzada del servidor
Debian per a la Week 1 del projecte GreenDevCorp.

L'objectiu és establir una base segura, reproduïble i automatitzada que
permeti:

-   Accés remot segur mitjançant SSH
-   Escalada de privilegis controlada amb sudo
-   Estructura administrativa definida
-   Verificació automàtica de la configuració
-   Preparació per a futures ampliacions (Weeks 2--6)

Tota la configuració del sistema es realitza mitjançant scripts.

------------------------------------------------------------------------

## Arquitectura bàsica

El servidor s'executa en una màquina virtual VirtualBox.

-   Mode de xarxa: NAT
-   Port forwarding: Host 2222 → Guest 22
-   Sistema operatiu: Debian (instal·lació mínima)
-   Usuari administratiu: gsx

------------------------------------------------------------------------

## Configuració de xarxa (VirtualBox)

1.  Obrir configuració de la VM
2.  Xarxa → Adaptador 1
3.  Mode: NAT
4.  Reenvío de puertos:

  Nom   Protocol   Port host   Port convidat
  ----- ---------- ----------- ---------------
  SSH   TCP        2222        22

Això permet que el port 2222 del sistema host redirigeixi al port 22 del
servidor Debian.

------------------------------------------------------------------------

## Configuració de clau SSH (si no existeix)

Si el sistema host no disposa d'una clau SSH:

    ssh-keygen

Acceptar la ubicació per defecte.

Això generarà:

-   Clau privada (\~/.ssh/id_ed25519)
-   Clau pública (\~/.ssh/id_ed25519.pub)

------------------------------------------------------------------------

## Registrar la clau pública al servidor

Des del sistema host:

    ssh-copy-id -p 2222 gsx@localhost

Si ssh-copy-id no està disponible, copiar manualment el contingut de la
clau pública al fitxer:

    ~/.ssh/authorized_keys

del servidor.

------------------------------------------------------------------------

## Connexió al servidor

Des del sistema host:

    ssh gsx@localhost -p 2222

Configuració aplicada pel bootstrap:

-   Autenticació per clau pública
-   PasswordAuthentication desactivat
-   Login de root desactivat
-   Ús de sudo per tasques administratives

------------------------------------------------------------------------

## Instal·lació des de zero (flux complet)

1.  Instal·lar Debian (instal·lació mínima)
2.  Seleccionar "OpenSSH Server" durant la instal·lació
3.  Clonar el repositori
4.  Executar:

```{=html}
<!-- -->
```
    ./scripts/bootstrap.sh

5.  Verificar configuració:

```{=html}
<!-- -->
```
    ./scripts/verify_setup.sh

Si retorna 0, el sistema està correctament configurat.

------------------------------------------------------------------------

## Estructura del projecte

    scripts/
        setup_server.sh
        verify_setup.sh
        backup.sh

    docs/
        design_decisions.md
        week1.md

    .gitignore
    README.md

### Descripció dels scripts

-   **bootstrap.sh** → Instal·la paquets, configura sudo, endureix SSH i
    crea l'estructura administrativa.
-   **verify_setup.sh** → Comprova automàticament que el sistema està
    correctament configurat.
-   **backup.sh** → Script per empaquetar dades sensibles preservant
    permisos.

------------------------------------------------------------------------

## Principis aplicats

-   Infraestructura com a codi
-   Idempotència
-   Principi de mínim privilegi
-   Automatització abans que configuració manual
-   Separació entre configuració i documentació

------------------------------------------------------------------------

## Verificació

El script `verify_setup.sh`:

-   Comprova estat del servei SSH
-   Comprova configuració segura
-   Comprova pertinença al grup sudo
-   Comprova estructura administrativa

Retorna:

-   0 → Tot correcte
-   1 → Errors detectats

------------------------------------------------------------------------

Per a més detalls tècnics i decisions de disseny, consultar la carpeta
`docs/`.