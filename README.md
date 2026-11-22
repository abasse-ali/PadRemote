# PadRemote : souris, clavier et télécommande iPhone pour ce PC

Transforme l'iPhone en **pavé tactile multi-touch**, **clavier** (avec saisie directe et dictée), **télécommande multimédia**, **télécommande de présentation** et **panneau de raccourcis** pour ce PC Windows, via le Wi-Fi.

- **Côté PC** : un petit serveur Python (aucune dépendance) qui simule souris et clavier avec l'API Windows `SendInput`.
- **Côté iPhone** : une web app installée sur l'écran d'accueil. Elle s'ouvre en plein écran avec son icône, comme une app de l'App Store. Il n'y a rien à compiler et aucun Mac n'est nécessaire.

## Installation (une seule fois)

1. **Sur le PC** : double-cliquez sur `Demarrer_PadRemote.bat`.
   - Une fenêtre affiche l'adresse et le **code PIN**, et une page avec un **QR code** s'ouvre dans le navigateur.
   - Si Windows demande l'accès au réseau pour Python, cochez **Réseaux privés** puis cliquez sur **Autoriser**.
2. **Sur l'iPhone** (même Wi-Fi que le PC) : scannez le QR code avec l'appareil photo. La page s'ouvre dans Safari, déjà connectée.
3. Dans Safari : bouton **Partager**, puis **Sur l'écran d'accueil**. Laissez « Ouvrir en tant qu'app web » activé, puis touchez **Ajouter**.
4. Lancez **PadRemote** depuis l'écran d'accueil.

> Sans QR code : tapez dans Safari l'adresse affichée dans la fenêtre (ex. `http://192.168.1.59:8765`), puis le code PIN.

### Lancer PadRemote automatiquement au démarrage du PC

Double-cliquez sur `Demarrage_auto_activer.bat`. Le serveur démarrera en arrière-plan, sans fenêtre, à chaque ouverture de session. Pour annuler : `Demarrage_auto_desactiver.bat`.

## Utilisation

| Onglet | Contenu |
|---|---|
| **Souris** | Pavé tactile, molette sur le bord droit, boutons Gauche / Milieu / Droit, bouton ⌨ pour taper en direct |
| **Clavier** | Zone de texte (idéale pour la dictée) + Envoyer, modificateurs, touches spéciales, flèches, F1 à F12 |
| **Médias** | Volume, lecture/pause, piste suivante/précédente, présentation (diapos, écran noir), contrôle vidéo |
| **Raccourcis** | Édition, Windows, navigateur, ouvrir une URL sur le PC, alimentation (verrouiller, veille, arrêt…) |
| **Réglages** | Vitesse du curseur, accélération, défilement (naturel, fluide, inertie), retour haptique… |

### Gestes du pavé tactile

| Geste | Action |
|---|---|
| 1 doigt glissé | Déplacer le curseur |
| Toucher / 2 touchers | Clic / double-clic |
| Toucher puis glisser | Sélectionner, glisser-déposer |
| 2 doigts glissés | Défiler (vertical et horizontal) |
| Toucher à 2 doigts | Clic droit |
| Pincer / écarter | Zoom (Ctrl + molette) |
| Toucher à 3 doigts | Clic milieu |
| 3 doigts ↑ / ↓ / ← → | Vue des tâches / Bureau / App précédente |
| Maintenir « Gauche » + glisser un autre doigt | Glisser-déposer |

**Modificateurs** (Ctrl, Alt, Maj, Win) : 1 toucher les active pour la prochaine touche ou le prochain clic (Ctrl + clic, Maj + flèches…), 2 touchers les verrouillent.

## Dépannage

- **L'iPhone ne se connecte pas**
  - Vérifiez que l'iPhone et le PC sont sur le **même Wi-Fi** (pas en 4G/5G, pas sur un réseau « invité »), et désactivez un éventuel VPN.
  - Lancez `Pare-feu_autoriser.bat` (il demande les droits administrateur). Il ouvre le port 8765 au réseau local uniquement.
  - Si vous aviez cliqué « Annuler » sur l'alerte du pare-feu, Windows a créé une règle qui **bloque** Python. Ouvrez *Pare-feu Windows Defender → Autoriser une application via le pare-feu* et cochez « Privé » pour `python.exe` / `pythonw.exe`.
- **L'adresse IP du PC a changé** (l'app de l'écran d'accueil ne s'ouvre plus) : relancez le serveur, scannez le nouveau QR code et ajoutez de nouveau l'app à l'écran d'accueil. Pour éviter cela, réservez une IP fixe au PC dans la box (réservation DHCP).
- **Les clics ne marchent pas dans certaines fenêtres** (Gestionnaire des tâches, apps « administrateur ») : Windows bloque la simulation vers une app plus privilégiée. Lancez `Demarrer_PadRemote.bat` en tant qu'administrateur.
- L'écran de verrouillage, l'écran UAC et Ctrl+Alt+Suppr ne peuvent pas être contrôlés : c'est une protection de Windows.
- **Le curseur est trop lent ou trop rapide** : onglet Réglages. La vitesse du pointeur Windows et l'option « Améliorer la précision du pointeur » s'appliquent aussi.

## Configuration (`server/config.json`, créé au premier lancement)

```json
{ "port": 8765, "pin": "123456", "allow_power": true }
```

- **Nouveau code PIN** : `Demarrer_PadRemote.bat --new-pin` (ou modifiez `pin`).
- **Désactiver veille, arrêt et redémarrage depuis l'iPhone** : `"allow_power": false`.
- Après avoir changé de port, mettez à jour la règle de pare-feu dans `Pare-feu_autoriser.bat`.

## Sécurité

- Le serveur n'accepte que les appareils qui connaissent le code PIN. Après 5 erreurs, l'adresse est bloquée pendant 60 secondes.
- La page QR code (qui affiche le PIN) n'est accessible que depuis le PC lui-même.
- La règle de pare-feu fournie n'autorise que le réseau local.
- Les échanges ne sont pas chiffrés (HTTP sur le réseau local). N'utilisez pas PadRemote sur un Wi-Fi public.

## Structure

```
Demarrer_PadRemote.bat        lance le serveur
Demarrage_auto_*.bat          démarrage automatique (raccourci dans shell:startup)
Pare-feu_autoriser.bat        règle de pare-feu (port 8765, réseau local)
server/padremote.py           serveur HTTP + WebSocket, PIN, alimentation
server/wininput.py            injection souris/clavier (SendInput via ctypes)
server/pair.html              page QR code affichée sur le PC
web/                          web app iPhone (HTML/CSS/JS, manifest, icônes)
tools/make_icons.py           régénère les icônes PNG
```
