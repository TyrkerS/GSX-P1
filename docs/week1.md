# Week 1 — Foundation & Remote Access

## Objectiu i context

GreenDevCorp parteix d'un servidor Debian acabat d'instal·lar, accessible únicament per consola local. L'objectiu d'aquesta setmana és:

1. Habilitar accés remot segur via SSH
2. Configurar escalada de privilegis sense root login
3. Endurir el sistema (mesures de seguretat bàsiques)
4. Activar actualitzacions automàtiques de seguretat
5. Crear l'estructura administrativa i versionar-la amb Git
6. Automatitzar tot amb scripts idempotents

---

## Arquitectura de seguretat

### Per qué SSH i no altres alternatives?

SSH (Secure Shell) és l'estàndard de facto per administració remota de servidors Linux perquè:
- Tot el tràfic és **xifrat end-to-end** (TLS/ChaCha20)
- Suporta autenticació forta per **clau pública** (elimina passwords)
- Permet **execució remota**, túnels, i còpies de fitxers segures (scp/rsync)
- S'integra perfectament amb automatització (Ansible, scripts CI/CD)

Alternatives com VNC/RDP requereixen interfície gràfica i no són adequades per servidors. Accés per consola física no és escalable.

### Passwords vs claus públiques — implicacions de seguretat

- **Atac de força bruta**: Password és vulnerable; Clau pública és immune (2048+ bits)
- **Phishing / captura**: Password pot ser capturada; Clau pública és impossible (la clau privada mai surt del host)
- **Revocació**: Amb Password cal canviar la contrasenya al servidor; Amb Clau pública només cal eliminar la línia d'`authorized_keys`
- **Auditoria**: Amb Password és difícil saber qui ha autenticat; Amb Clau pública l'usuari és identificable per la clau
- **Complexitat operativa**: Password és simple però insegur; Clau pública requereix gestió de claus

**Decisió**: s'activa autenticació per clau pública i es deixa `PasswordAuthentication yes` mentre no hi hagi clau instal·lada (per no bloquejar l'accés). En quant s'afegeix una clau, `setup_server.sh` desactiva automàticament l'autenticació per password.

### Per qué desactivar el login de root?

Un atacant que obtingui accés SSH com a `root` té control total i immediat. Amb `PermitRootLogin no`:
- L'atacant ha de compromitre dos comptes (usuari + sudo)
- Totes les accions privilegiades queden auditades als logs de sudo
- S'aplica el **principi de mínim privilegi**: el compte `gsx` no té privilegis per defecte, els adquireix explícitament via `sudo`

### Per qué canviar el port SSH (22222 en lloc de 22)?

El port 22 rep milers d'intents d'autenticació automàtics diàriament (bots). Canviar el port:
- Redueix el **soroll als logs** (facilita detectar intents reals)
- No és "seguretat per obscuritat" — és simplement filtrar tràfic automatitzat

**Limitació**: no protegeix contra atacants dirigits que fan scan de ports.

---

## Actualitzacions automàtiques de seguretat

S'instal·la i configura `unattended-upgrades` per aplicar pegats de seguretat de forma automàtica sense intervenció manual. Racional:
- Les vulnerabilitats explotades solen tenir pegat disponible dies o setmanes abans de l'atac
- La finestra entre publicació del CVE i explotació s'ha reduït a hores en alguns casos
- Risc assumit: una actualització pot trencar alguna cosa → mitigat amb snapshots de VirtualBox

---

## Estructura administrativa

```
/opt/P1/               ← BASE_DIR: arrel del projecte
├── scripts/           ← scripts d'administració (versionats)
├── docs/              ← documentació (versionada)
├── logs/              ← logs operacionals (gitignored)
├── etc/               ← còpies de configuració (/etc snapshot)
└── .git/              ← repositori Git

/var/backups/P1/       ← BACKUP_DIR: backups (fora del repo)
/etc/P1/               ← ETC_DIR: configuració extra del projecte
```

**Per qué `/opt/P1` i no `/home/gsx`?**
- `/opt` és el lloc estàndard FHS (Filesystem Hierarchy Standard) per aplicacions opcionals i específiques
- Separa la infraestructura del projecte dels fitxers personals de l'usuari
- Permet que múltiples usuaris administradors accedeixin als scripts sense conflictes de permisos

### Què ha d'estar a Git i què no?

**Ha d'estar a Git:**
- Scripts de setup/verify
- Fitxers de configuració template
- Documentació i runbooks
- Unit files de systemd
- `.gitignore`

**NO ha d'estar a Git:**
- Passwords i passphrases
- Claus privades SSH
- Fitxers de backup (pesats)
- Logs (canvien constantment)
- `/etc/backup.passphrase`

El `.gitignore` exclou: `*.log`, `backups/`, `*.tar.gz`, `*.gpg`, `authorized_keys`, `*.pem`, `*.key`.

---

## Scripts implementats

- **`setup_server.sh`**: Bootstrap complet (paquets, sudo, SSH, estructura, Git)
- **`backup.sh`**: Backup xifrat de `/home` amb GPG AES-256
- **`verify_setup.sh`**: Verificació automàtica de tot el setup

### Idempotència

Tots els scripts comproven l'estat actual abans d'actuar:
```bash
# setup_server.sh: no re-inicialitza Git si ja existeix
if [ ! -d "$BASE_DIR/.git" ]; then
    sudo -u "$USER_NAME" git -C "$BASE_DIR" init
fi

# setup_server.sh: no afegeix la clau SSH si ja hi és
if ! grep -qF "$SSH_PUBKEY" "$AUTH_KEYS" 2>/dev/null; then
    echo "$SSH_PUBKEY" >> "$AUTH_KEYS"
fi
```

Executar els scripts múltiples vegades produeix el mateix resultat final.

### Backup amb xifratge GPG

```bash
# Xifratge simètric AES-256 amb passphrase
tar --preserve-permissions --same-owner -czf - /home \
  | gpg --batch --yes --symmetric \
        --cipher-algo AES256 \
        --passphrase-file /etc/backup.passphrase \
        -o "$BACKUP_FILE"
```

La passphrase es guarda a `/etc/backup.passphrase` (chmod 600, owned root). **Important**: guardar aquesta passphrase fora del servidor (gestor de contrasenyes). Sense ella, els backups xifrats no es poden restaurar.

---

## Com evitar que dos membres executin el setup simultàniament

Executar el mateix script des de dues sessions simultànies pot produir condicions de carrera (duplicar línies a `sshd_config`, conflictes a `git commit`, etc.).

El script usa un **fitxer de bloqueig** via `flock`:
```bash
exec 9>/var/lock/gsx-setup.lock
if ! flock -n 9; then
    echo "ERROR: Another instance is already running. Exiting."
    exit 1
fi
```

- El primer procés adquireix el lock i continua
- El segon detecta que el lock és actiu i surt amb error immediatament
- Quan el primer procés acaba (o mor), el kernel allibera el lock automàticament

Alternativament: com el script és idempotent, executar-lo dues vegades rarament causa problemes reals però el lockfile és la pràctica correcta.

---

## Si cal reinstal·lar: pot el script restaurar tot?

**El que pot restaurar el script:**
- Paquets instal·lats (apt)
- Configuració SSH (sshd_config)
- Usuari `gsx` i permisos sudo
- Estructura de directoris
- Configuració de Git al repositori

**El que requereix acció manual:**
- La clau SSH de l'administrador (cal passar `--ssh-pubkey`)
- La passphrase de backup (`/etc/backup.passphrase`)
- El contingut dels backups xifrats (restaurar des del fitxer `.tar.gz.gpg`)
- Els commits de Git del repositori (si el disc estava corrupte)

**Conclusió**: el sistema és aproximadament 80% auto-recuperable. El 20% restant requereix custodiar de forma segura: passphrase de backup i claus SSH. Documentat al `runbook.md`.

---

## Verificació

```bash
sudo bash scripts/Week_1/verify_setup.sh
```

Comprova automàticament:
- SSH actiu i amb port correcte
- Root login desactivat
- Autenticació per clau pública activada
- Usuari a grup sudo
- unattended-upgrades instal·lat i actiu
- Estructura de directoris completa
- Repositori Git inicialitzat amb commit baseline

---

## Respostes a les preguntes de l'enunciat

**Per qué SSH sobre altres opcions?**
SSH és l'únic que ofereix xifrat + autenticació forta + no requereix GUI, tot a la vegada. VNC/RDP tenen superfície d'atac molt més gran i requereixen el servidor X.

**Claus vs passwords: implicacions de seguretat?**
Les claus pública/privada usen criptografia asimètrica de 256+ bits. Un atac de força bruta contra una clau ed25519 és computacionalment inviable. Una password de 12 caràcters pot caure en hores amb GPU si es filtra el hash.

**Si cal reinstal·lar, poden els scripts restaurar tot el sistema?**
Sí, els scripts recuperen la configuració del servidor (~80%). El 20% que no pot automatitzar-se (passphrase de backup, claus SSH de l'admin) s'ha de custodiar externament i documentat al runbook.

**Com s'evita que els dos membres executin el setup simultàniament?**
Amb un fitxer de bloqueig (`flock`). El segon intent detecta el lock actiu i surt immediatament amb error.

**Quina informació ha d'estar a Git i quina no?**
A Git: scripts, documentació, configs template. Fora: secrets (passwords, claus privades, passphrases), backups (fitxers grans), logs. Documentat al `.gitignore`.

---

## Reflexió

La part més sorprenent ha estat descobrir com una instal·lació aparentment trivial (SSH + sudo) amaga moltes decisions de seguretat: cada directiva de `sshd_config` respon a un vector d'atac específic.

Escriure scripts idempotents ha canviat la forma de pensar sobre la infraestructura: en lloc de "executar passos", el paradigma és "assegurar un estat desitjat".

**Millores futures**: gestió de secrets amb HashiCorp Vault en lloc de fitxers a `/etc/`, rotació automàtica de claus SSH.
