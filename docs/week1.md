# Week 1 -- Decisions de Disseny i Reflexió

## 1. Objectiu de la Week 1

L'objectiu principal d'aquesta setmana ha estat establir una base
sòlida, segura i reproduïble per al servidor Debian del projecte
GreenDevCorp.

Aquesta base ha d'assegurar:

-   Accés remot segur
-   Escalada de privilegis controlada
-   Automatització de la configuració
-   Separació clara d'estructura administrativa
-   Capacitat de verificació automàtica

La filosofia aplicada ha estat Infraestructura com a Codi
(Infrastructure as Code).

------------------------------------------------------------------------

## 2. Per què SSH com a mètode d'accés remot?

SSH és l'estàndard en entorns Linux per administració remota segura.

Avantatges:

-   Comunicació xifrada
-   Autenticació forta
-   Execució remota de comandes
-   Integració amb automatització

Alternatives com accés directe per consola o interfícies gràfiques no
són adequades per entorns de servidor professionals.

------------------------------------------------------------------------

## 3. Per què autenticació per clau pública?

S'ha desactivat l'autenticació per password i el login directe de root.

Raons:

-   Evitar atacs de força bruta
-   Reduir superfície d'atac
-   Aplicar bones pràctiques de seguretat
-   Seguir el principi de mínim privilegi

L'autenticació per clau pública és més segura i és la pràctica habitual
en entorns productius.

------------------------------------------------------------------------

## 4. Per què utilitzar sudo en lloc de root?

Permetre login directe de root incrementa el risc en cas de compromís.

L'ús de sudo permet:

-   Control d'accés més granular
-   Traçabilitat de les accions
-   Separació entre usuari normal i privilegis elevats

Aquesta decisió segueix el principi de mínim privilegi.

------------------------------------------------------------------------

## 5. Per què automatitzar amb bootstrap.sh?

La configuració manual és:

-   Propensa a errors
-   Difícil de reproduir
-   No auditable
-   Difícil de mantenir

L'script bootstrap:

-   Instal·la paquets necessaris
-   Configura sudo
-   Endureix SSH
-   Crea estructura administrativa

Això garanteix idempotència i consistència.

------------------------------------------------------------------------

## 6. Per què un script de verificació?

El script verify_setup.sh permet:

-   Validar que el sistema compleix els requisits
-   Detectar errors automàticament
-   Retornar codi d'estat (0 o 1)
-   Facilitar proves futures

Això introdueix mentalitat de testing i control d'estat del sistema.

------------------------------------------------------------------------

## 7. Per què una estructura a /opt/greendevcorp?

El directori /opt està pensat per programari opcional o específic.

Separar la infraestructura del projecte dels fitxers del sistema:

-   Millora organització
-   Facilita manteniment
-   Evita modificar directament fitxers crítics del sistema

------------------------------------------------------------------------

## 8. Per què un script de backup?

El backup és necessari per:

-   Preservar configuracions crítiques
-   Permetre recuperació en cas d'error
-   Garantir preservació de permisos

S'utilitza tar amb compressió i preservació de permisos.

Aquesta base permetrà automatització amb systemd a Weeks futures.

------------------------------------------------------------------------

## 9. Principis aplicats

Durant aquesta setmana s'han aplicat els següents principis:

-   Infraestructura com a codi
-   Idempotència
-   Principi de mínim privilegi
-   Automatització abans que configuració manual
-   Separació entre codi i documentació
-   Seguretat per defecte