# Week 4 — Usuaris, Grups i Control d'Accés

## Objectiu

Crear un entorn de col·laboració segur per als 4 developers de GreenDevCorp, aplicant el principi de mínim privilegi: cada usuari té exactament els permisos que necessita i res més.

---

## Estructura d'usuaris i grups

| Usuari | Grup principal | Accés |
|--------|---------------|-------|
| dev1 | greendevcorp | Escriptura a `done.log`, accés complet a `shared/` |
| dev2 | greendevcorp | Accés complet a `shared/`, lectura de `done.log` |
| dev3 | greendevcorp | Lectura de `shared/` i `done.log` |
| dev4 | greendevcorp | Lectura de `shared/` i `done.log` |

**Per què un sol grup `greendevcorp`?**
Tots els developers comparteixen el mateix nivell de confiança base. Les diferències individuals s'expressen via ACLs (des de Unix permissions és insuficient per als casos de `done.log`).

---

## Directoris i permisos

### Estructura

```
/home/greendevcorp/
├── bin/          (750, root:greendevcorp)   Scripts compartits, executables pel grup
├── shared/       (3770, root:greendevcorp)  Directori de treball compartit
└── done.log      (640, dev1:greendevcorp)   Registre de tasques
```

### Bits especials

**`shared/` — chmod 3770 (setgid + sticky bit)**
- **Setgid (2...)**: Els nous fitxers creats dins hereten el grup `greendevcorp`, no el grup primari del creador.
- **Sticky bit (...1...)**: Només el propietari d'un fitxer pot eliminar-lo, tot i que altres tinguin permís d'escriptura al directori.

**Diferència setgid en directori vs fitxer:**
- **En directori**: els nous fitxers hereten el grup del directori (útil per a col·laboració).
- **En fitxer executable**: el fitxer s'executa com el grup propietari (perillós, usar amb molta cura).

---

## POSIX ACLs

Les permissions Unix estàndard (rwx per user/group/other) no permeten especificar règles per a múltiples usuaris individuals. Les **ACLs** ho solucionen:

### done.log: dev1 rw, grup r--

```bash
setfacl -m "g:greendevcorp:r--" /home/greendevcorp/done.log  # grup: lectura
setfacl -m "u:dev1:rw-"         /home/greendevcorp/done.log  # dev1: lectura + escriptura
```

Verificació:
```bash
getfacl /home/greendevcorp/done.log
```

### shared/: dev1+dev2 rwx, dev3+dev4 r-x

S'usen **default ACLs** per garantir que els fitxers nous dins de `shared/` heretin les mateixes regles:

```bash
setfacl -d -m "u:dev1:rwx" /home/greendevcorp/shared  # default heredat
setfacl -d -m "u:dev2:rwx" /home/greendevcorp/shared
setfacl -d -m "g:greendevcorp:r-x" /home/greendevcorp/shared
```

---

## Límits de recursos per usuari (PAM)

Configurat a `/etc/security/limits.d/greendevcorp.conf`:

| Límit | Soft | Hard | Propòsit |
|-------|------|------|---------|
| nproc | 100 | 200 | Evita fork bombs |
| nofile | 1024 | 4096 | Fitxers oberts simultàniament |
| memlock | 64 MB | 128 MB | Memòria bloquejada |
| cpu | 60 min | 120 min | Temps de CPU |

**Diferència soft vs hard:**
- **Soft**: límit actiu per defecte; l'usuari el pot pujar fins al hard limit.
- **Hard**: límit absolut; ni l'usuari ni els seus processos el poden superar.

Verificació per a un usuari:
```bash
sudo -u dev1 bash -c 'ulimit -a'
```

---

## Entorn de shell compartit

El fitxer `/etc/profile.d/greendevcorp.sh` s'aplica a tots els usuaris en cada login:

```bash
alias ll='ls -la'
alias gs='git status'
export PATH=$PATH:/home/greendevcorp/bin
```

Verificació:
```bash
sudo -u dev1 bash -l -c 'echo $PATH'     # ha d'incloure /home/greendevcorp/bin
sudo -u dev3 bash -l -c 'type ll'        # ha de trobar l'àlies
```

---

## Scripts implementats

| Script | Funció |
|--------|--------|
| `setup_users.sh` | Crea grup i usuaris amb contrasenyes aleatòries, força canvi al primer login |
| `setup_directories.sh` | Crea l'estructura de directoris amb permisos correctes |
| `setup_acl.sh` | Configura ACLs POSIX per a control d'accés fi |
| `setup_pam_limits.sh` | Configura límits de recursos per grup via PAM |
| `setup_environment.sh` | Crea el fitxer `/etc/profile.d/greendevcorp.sh` |
| `verify_setup.sh` | Verifica tot: usuaris, permisos, ACLs, PAM limits, entorn |

**Ordre d'execució:**
```bash
sudo ./setup_users.sh
sudo ./setup_directories.sh
sudo ./setup_acl.sh
sudo ./setup_pam_limits.sh
sudo ./setup_environment.sh
sudo ./verify_setup.sh
```

---

## Troubleshooting: "Un usuari no pot accedir a un fitxer"

```bash
# 1. Identificar usuari i fitxer
id dev3                          # veure grups de l'usuari

# 2. Comprovar permisos Unix
ls -la /home/greendevcorp/done.log

# 3. Comprovar ACLs
getfacl /home/greendevcorp/done.log

# 4. Provar l'accés directament
sudo -u dev3 cat /home/greendevcorp/done.log    # ha de funcionar
sudo -u dev3 bash -c 'echo test >> /home/greendevcorp/done.log'  # ha de fallar

# 5. Si les ACLs semblen correctes:
#    - Verificar que el filesystem suporta ACLs (mount | grep acl)
#    - Verificar que l'usuari és al grup correcte (id dev3)
```

---

## Respostes a les preguntes de l'enunciat

**Si un fitxer és en un directori compartit (owned by dev1), com el llegeixen tots?**

Cal que els permisos del fitxer permetin almenys `r--` per al grup `greendevcorp`. Amb `chmod 640` i `chown dev1:greendevcorp` queda correcte. Per a casos més complexos (accés per usuari individual), s'usen ACLs.

**Diferència setgid en directori vs fitxer?**

- **Directori**: els fitxers nous hereten el grup del directori → perfecte per a `shared/`.
- **Fitxer executable**: s'executa amb els permisos del grup propietari → perillós, evitar tret de casos molt específics (p.ex. `passwd` usa setuid).

**Com verificar que el model de permisos funciona?**

El script `verify_setup.sh` fa proves reals (`sudo -u dev2 bash -c "echo test >> done.log"`) i comprova que fallen correctament. No n'hi ha prou amb mirar `ls -la` — cal provar l'accés com a l'usuari real.
