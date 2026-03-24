# Week 4 — Usuaris, Grups & Control d'Accés

## Objectiu i context

GreenDevCorp té 4 developers que comparteixen el mateix servidor. Cal un model de seguretat que permeti col·laboració sense comprometre la privacitat ni la integritat de les dades. El principi fonamental: **mínim privilegi** — cada usuari té exactament els permisos que necessita, i res més.

---

## Disseny de la estructura d'usuaris i grups

### Per qué un sol grup `greendevcorp` i no un per usuari?

```
Opció A: un grup compartit (ESCOLLIT)
  dev1, dev2, dev3, dev4 → greendevcorp
  Avantages: simple, s'escala bé, les diferències fines es gestionen amb ACLs

Opció B: grups individuals + grup compartit
  dev1 → dev1_grp + greendevcorp
  Avantages: granularitat a nivell Unix
  Desavantages: complexitat creixent O(n²) amb persones
```

**Decisió**: grup compartit + ACLs POSIX per als casos especials. Unix permissions gestiona les regles generals, ACLs gestiona les excepcions.

### Taula de permisos

- **dev1**: rw (escriptura) a `done.log`, rwx a `shared/`, r-x a `bin/`
- **dev2**: r-- (lectura) a `done.log`, rwx a `shared/`, r-x a `bin/`
- **dev3**: r-- (lectura) a `done.log`, r-x (lectura) a `shared/`, r-x a `bin/`
- **dev4**: r-- (lectura) a `done.log`, r-x (lectura) a `shared/`, r-x a `bin/`

---

## Estructura de directoris i permisos especials

```
/home/greendevcorp/
├── bin/           chmod 750  owner: root:greendevcorp    Scripts executables
├── shared/        chmod 3770 owner: root:greendevcorp    Treball compartit
└── done.log       chmod 640  owner: dev1:greendevcorp    Registre de tasques
```

### Bits especials a `shared/` (chmod 3770)

**Setgid (bit 2):** Quan un fitxer es crea dins de `shared/`, el grup propietari és `greendevcorp` (heretat del directori), no el grup primari de qui el crea. Sense setgid, un fitxer creat per dev1 tindria grup `dev1`, i dev2 no podria llegir-lo si els permisos de "other" estan restringits.

**Sticky bit (bit 1):** Dins de `shared/`, un usuari no pot eliminar fitxers creats per altri, fins i tot si té permís d'escriptura al directori. Sense sticky bit, dev2 podria eliminar fitxers de dev1.

**Diferència setgid en directori vs. fitxer:**
- **Directori**: els nous fitxers hereten el grup del directori → segur i útil
- **Fitxer executable**: el fitxer s'executa amb els privilegis del grup propietari → perillós (similar a setuid). Exemple legítim: `crontab` usa setgid per escriure al spool.

---

## POSIX ACLs — Per qué i com

### Limitació de Unix permissions estàndard

Unix permissions permeten especificar tres actors: user (propietari), group, others. Si volem "dev1 pot escriure, dev2 pot llegir, dev3+dev4 poden llegir, ningú més" amb Unix permissions pur:
- Establim `group::r--` → tothom al grup llegeix
- No hi ha forma d'afegir "dev1 pot escriure" sense fer-lo propietari

Les **ACLs** afegeixen entrades addicionals a la llista de control d'accés, una per usuari o grup:

```bash
# done.log: dev1 rw, resta del grup r--
setfacl -b /home/greendevcorp/done.log             # netejar ACLs existents
setfacl -m "g:greendevcorp:r--" /home/greendevcorp/done.log
setfacl -m "u:dev1:rw-" /home/greendevcorp/done.log

# Verificar
getfacl /home/greendevcorp/done.log
```

### Bug POSIX ACL: `group::` vs `group:<name>`

**Problema trobat durant la implementació:** Quan s'aplica `setfacl -b` i s'estableix `g:greendevcorp:r-x` per a `shared/`, el directori té `chmod 3770` (rwxrwx), de manera que l'entrada base `group::rwx` segueix present. En POSIX ACL, quan un usuari coincideix amb múltiples entrades de grup (group:: i group:greendevcorp:), el sistema aplica la **més permissiva**. Per tant dev3 (membre de greendevcorp = el grup propietari) obtenia `rwx` en lloc de `r-x`.

**Solució**: Establir explícitament `group::r-x` per sobreescriure l'entrada base:

```bash
setfacl -m "g::r-x"            /home/greendevcorp/shared  # override base
setfacl -d -m "g::r-x"         /home/greendevcorp/shared  # default
setfacl -m "g:greendevcorp:r-x"  /home/greendevcorp/shared
setfacl -m "u:dev1:rwx"         /home/greendevcorp/shared
setfacl -m "u:dev2:rwx"         /home/greendevcorp/shared
```

### ACLs per defecte (default ACLs)

Les ACLs de directori no s'apliquen automàticament als fitxers nous que es creen dins. Per garantir que els fitxers nous heretin les mateixes regles, cal configurar **default ACLs** amb `-d`:

```bash
setfacl -d -m "g:greendevcorp:r-x" /home/greendevcorp/shared
setfacl -d -m "u:dev1:rwx" /home/greendevcorp/shared
setfacl -d -m "u:dev2:rwx" /home/greendevcorp/shared
```

---

## Límits de recursos per usuari (PAM)

Configurat a `/etc/security/limits.d/greendevcorp.conf`:

- **nproc**: Soft 100, Hard 200. Evita fork bombs (`:(){ :|:& };:`).
- **nofile**: Soft 1024, Hard 4096. Límits als fitxers oberts simultàniament.
- **memlock**: Soft 64 MB, Hard 128 MB. Límits per a memòria bloquejada (no paginable).
- **cpu**: Soft 60 min, Hard 120 min. Minuts de CPU total per sessió.

**Soft vs Hard:**
- **Soft**: límit actiu per defecte. L'usuari el pot pujar fins al hard limit (sense privilegis).
- **Hard**: límit absolut, immutable per l'usuari. Només root el pot modificar.

**Com funciona**: PAM (`pam_limits.so`) aplica els límits quan l'usuari fa login. Els limits s'hereten per tots els processos fills de la sessió.

```bash
# Verificació
sudo -u dev1 bash -l -c 'ulimit -a'         # tots els limits de dev1
sudo -u dev1 bash -l -c 'ulimit -n'         # nofile soft limit
```

**Limitació important**: els limits de PAM s'apliquen en el moment del **login**. Sessions ja actives no es veuen afectades fins al proper login.

---

## Entorn de shell compartit

```bash
# /etc/profile.d/greendevcorp.sh
export PATH="$PATH:/home/greendevcorp/bin"
alias ll='ls -la --color=auto'
alias gs='git status'
alias glog='git log --oneline --graph'
export PS1="\u@\h [\$(date +%H:%M)] \w\$ "
```

`/etc/profile.d/` s'executa en cada login shell (bash, sh). Tots els usuaris del sistema hereten les variables definides aquí.

```bash
# Verificar
sudo -u dev1 bash -l -c 'echo $PATH'     # ha d'incloure /home/greendevcorp/bin
sudo -u dev3 bash -l -c 'type ll'        # ha de trobar l'àlies
```

---

## Scripts implementats

- **`setup_users.sh`**: Crea grup i usuaris amb passwords aleatoris (mitjançant `tr` llistant de `/dev/urandom`), i força el canvi al primer login.
- **`setup_directories.sh`**: Crea estructura de directoris amb permisos pertinents com `setgid` i l'stiky bit.
- **`setup_acl.sh`**: Configura ACLs de funcionalitat POSIX per certs arxius (`done.log`, `shared/` i `bin/`).
- **`setup_pam_limits.sh`**: Configura límits establint contingut dins de `/etc/security/limits.d/greendevcorp.conf`.
- **`setup_environment.sh`**: Prepara variables d'entorn i alias a `/etc/profile.d/greendevcorp.sh`.
- **`verify_setup.sh`**: Realitza proves com l'accés real (per exemple `sudo -u dev2`) incloent anàlisi de límits PAM.

### Generació de passwords segures

```bash
# Generació via /dev/urandom (font aleatòria del kernel)
PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16 || true)
```

El `|| true` evita un SIGPIPE: quan `head` tanca el pipe (després de 16 caràcters), `tr` rep el senyal de pipe trencat. Amb `set -euo pipefail`, aquest error sense `|| true` mata l'script.

Les passwords es mostren per pantalla un cop creades i es força canvi en el primer login amb `chage -d 0`. **Mai es guarden en Git**.

### ACL base de grup vs. regla de permís més permissiu

**Anàlisi d'Error Evitat**: Als inicis de la configuració de `shared/`, usàvem `chmod 3770` combinat amb directives base per als developers secundaris. En ACL POSIX, el problema radica que quan un usuari coincideix amb múltiples permisos (és dir, l'ACL nominal de dev2 vs el grup Unix al directori), POSIX aplica sistemàticament la regla *més permissiva* sense que el propietari estigui assabentat. Això causava que "dev3" obtingués escriptura si el grup `greendevcorp` sencer la tenia establerta a la base nativa `g::rwx`, anulant totalment l'ACL `r-x` teòric d'aquell usuari.

**Solució Adoptada**: Ocultarem la potència d'extracció accidental aplicant programàticament i expressament un retall sobre l'entrada base Unix amb ACL: `setfacl -m "g::r-x"`. En limitar completament això a lectura pel macro-grup, deixem finalment que l'únic individu que aconsegueixi el lliure accés amb Write siguin de facto (`u:dev1,dev2`) per un ACL atatorgat especial i directe.

---

## Troubleshooting: "Un usuari no pot accedir a un fitxer"

```bash
# PASSO 1: Identificar usuari, fitxer, i context
id dev3                                              # grups de l'usuari
ls -la /home/greendevcorp/done.log                   # permisos Unix

# PASSO 2: Comprovar ACLs
getfacl /home/greendevcorp/done.log                  # llista completa de regles

# PASSO 3: Provar l'accés com a l'usuari
sudo -u dev3 cat /home/greendevcorp/done.log         # ha de funcionar
sudo -u dev3 bash -c 'echo test >> /home/greendevcorp/done.log'  # ha de fallar

# PASSO 4: Verificar suport d'ACLs al sistema de fitxers
mount | grep -E "(acl|/home)"          # ha de mostrar "acl" o bé ext4 (suporta ACLs per defecte)

# PASSO 5: Diagnosi de PAM limits
sudo -u dev3 bash -l -c 'ulimit -n'   # fitxers oberts (ha de ser ≤ 4096)
```

---

## Respostes a les preguntes de l'enunciat

**Si un fitxer és en un directori compartit (owned by dev1), com el llegeixen tots?**

`chmod 640 dev1:greendevcorp` permet lectura al grup `greendevcorp`. Com tot el directori té setgid, nous fitxers hereten el grup automàticament. Per casos on cal que un usuari específic tingui permisos diferents al grup general, s'usa ACL.

**Diferència setgid en directori vs fitxer?**

Directori: facilita la col·laboració, els fitxers nous hereten el grup → segur. Fitxer executable: executa amb privilegis del grup → perillós, pot permetre escalada de privilegis si no es controla molt bé.

**Si les permissions estan mal configurades i un usuari no pot accedir al fitxer que necessita, com es fa debug?**

1. `id <user>` → verificar grup membership
2. `ls -la <fitxer>` → veure permisos Unix
3. `getfacl <fitxer>` → veure ACLs completes
4. `sudo -u <user> cat <fitxer>` → provar directament

**Com verificar que el model de permisos enforça correctament la política de seguretat?**

El `verify_setup.sh` fa proves reals (`sudo -u dev2 bash -c 'echo test >> done.log'`) i verifica que fallen. `ls -la` no és suficient — cal provar l'accés com a l'usuari real. Els bits i ACLs poden semblar correctes i tot i així haver-hi un edge case (com el bug `group::` descrit).

---

## Reflexió

La lliçó principal: Unix permissions estàndard (rwx per user/group/other) és un model intentionalment simple. Quan els requisits superen 3 actors (tots els membres del grup igual d'importants), cal ACLs. I fins i tot les ACLs amaguen subtileses (ordre d'evaluació, precedència d'entrades) que cal entendre per no tenir falsos sentits de seguretat.
