# Reflexió Individual — GreenDevCorp Infrastructure Project

## Quin ha estat l'aspecte més difícil d'aquest projecte?

L'aspecte més difícil ha estat entendre per que les coses estan dissenyades d'una manera concreta, no simplement fer-les funcionar. Per exemple, quan configures SSH és ràpid copiar un tutorial i desactivar el login per contrasenya — però entendre "per què" és important.

Igualment, escriure scripts idempotents ha requerit un canvi de mentalitat: en lloc de pensar "executa aquesta comanda", cal pensar "assegura't que l'estat desitjat existeix". Per exemple cada cop que afegeixes un `if [[ ! -d "$DIR" ]]; then mkdir ...` estàs blindant el script per a que no falli per molt que l'executis.

---

## Què faries diferent si comencessis de nou?

Documentaria mentre implementem, no al final. Diverses vegades hem hagut de reconstruir el raonament d'una decisió perquè ja no recordàvem per que havíem triat una opció sobre una altra. En entorns reals, les decisions s'obliden ràpidament si no es documenten immediatament.

A més, establiria una convenció de commits des del principi: tots els commits seguirien el format `[WeekN] acció: descripció`. Revisar el nostre historial ara es una mica confús.

---

## Com ha canviat la teva comprensió de l'administració de sistemes?

Abans d'aquesta pràctica, "administrar un servidor" em semblava instal·lar programari i reiniciar serveis quan fallen. Ara entenc que la feina real és:

- **Prevenció**: límits de recursos, backups automàtics, actualitzacions de seguretat
- **Observabilitat**: si no pots veure el que passa, no pots arreglar-ho
- **Reproducibilitat**: un sistema que no pot ser recreat per un altre administrador és un risc
- **Documentació**: el sistema ha de poder ser entregat a un altre sense conversa

La gran revelació ha estat que un sysadmin professional passa la major part del temps evitant problemes, no resolent-los.

---

## Quina és una cosa que voldries aprendre més?


M'agradaria aprofundir en monitoratge actiu. Durant la pràctica hem vist com consultar logs reactivament (quan ja hi ha un problema), però en producció necessites detectar anomalies proactivament: el disc va creixent, la memòria s'aproxima al límit, un servei respon lentament.

Igualment, m'interessa la gestió de secrets com a alternativa als fitxers manuals que hem usat per a la passphrase del backup. En un equip gran, gestionar secrets manualment no escala.

---

## Valoració del treball en parella

Treballar en parella ens ha permès qüestionar les decisions constantment, la qual cosa ha evitat bastants errors de disseny. Si un configurava una eina, l'altre ho revisava. Ara bé, he notat que l'administració de sistemes té molta feina seqüencial que simplement no es pot dividir bé per treballar en paral·lel. Acabes depenent absolutament de què l'altre acabi la seva part de configuració per poder començar tu. Per aquest motiu, hem acabat fent gran part de les tasques clau de manera conjunta des d'un únic ordinador. Això fomenta el treball en equip, però la contrapartida evident és que es perd la possibilitat d'avançar ràpidament.
