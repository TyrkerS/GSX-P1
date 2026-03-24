# Reflexió Individual — GreenDevCorp Infrastructure Project


## Quin ha estat l'aspecte més difícil d'aquest projecte?


El més difícil ha estat aprendre a pensar en termes d'operacions i no de codi. En el desenvolupament de programari estàs acostumat a tenir un output clar (el programa fa el que esperes o no). En sysadmin, el sistema sembla funcionar però pot tenir problemes latents: el disc s'omple lentament, un servei es reinicia en silenci, un backup falla la primera vegada que el necessites de veritat, o quan un servei sembla que funciona pero no es pot accedir des de fora.

---

## Què faries diferent si comencessis de nou?


Provaria el backup des del primer dia. Hem posat molta atenció a configurar el backup, però hem esperat molt temps abans de provar la restauració. En producció, un backup que mai has restaurat realment no saps si funciona. Per tant, hauriem de provar la restauració des del primer dia.

Aplicaria el concepte "chaos engineering" des de Week 1: matar serveis deliberadament, omplir el disc, crear usuaris maliciosos, i verificar que el sistema respon com s'espera. Seria la millor forma d'aprendre que els scripts de verificació funcionen de veritat.

---

## Com ha canviat la teva comprensió de l'administració de sistemes?


Tenia la idea que un sysadmin és algú que "arregla coses quan fallen". Ara entenc que és molt més preventiu i sistemàtic: es tracta de dissenyar sistemes que no fallin, i quan fallen, que ho facin de manera predictible i recuperable.

El concepte que m'ha agradat més és la idempotència: la idea que pots executar qualsevol script N vegades i el resultat final és sempre el mateix. Sembla obvi però requereix canviar la forma d'escriure codi: en lloc d'"afegir una línia al fitxer" hi ha de dir "assegurar-se que la línia hi és".

---

## Quina és una cosa que voldries aprendre més?

M'agradaria aprofundir en seguretat de xarxa i tallafocs. Hem configurat SSH amb bones pràctiques, però la VM és bastant exposada a nivell de xarxa. En un entorn real voldria entendre millor com protegir-la millor. Per exemple, com funciona un tallafocs real, com segmentar la xarxa, etc.

---

## Valoració del treball en parella

La col·laboració ha estat profitosa perquè t'obliga a raonar en veu alta; explicar a la parella una decisió tècnica és una bona manera de comprovar si realment ho has entès. A més, el debat previ ens ajudava a veure on ens equivocàvem.

En canvi, la dificultat més gran ha estat que, a diferència del desenvolupament de programari convencional, configurar una mateixa màquina virtual requereix anar amb compte de no sobreescriure's els canvis contínuament. Sovint ens ha estat impossible treballar de manera asíncrona: una persona o l'altra se n'havia de fer càrrec completament, la qual cosa ens ha portat a treballar junts des del mateix equip en molts casos. Aquest enfocament ens ha assegurat no trencar el sistema operatiu entre nosaltres, però alhora ens ha impedit avançar tan de pressa com si ho haguéssim pogut dividir completament en paral·lel.
