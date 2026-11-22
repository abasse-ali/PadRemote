# PadRemote : souris, clavier et télécommande iPhone pour PC Windows

Application **iOS native** (SwiftUI + UIKit) qui transforme l'iPhone en **pavé tactile multi-touch**, **clavier**, **télécommande multimédia**, **télécommande de présentation** et **panneau de raccourcis** pour un PC Windows, via le réseau local.

- **Sur l'iPhone** : l'app PadRemote (fichier `.ipa`), iOS 17 ou plus récent (testée pour iPhone 15 / iOS 26).
- **Sur le PC** : un petit serveur Python, sans dépendance, qui simule souris et clavier avec l'API Windows `SendInput`.

## 1. Lancer le serveur sur le PC

1. Double-cliquez sur `Demarrer_PadRemote.bat`. La fenêtre affiche le nom du PC, son adresse et le **code PIN**, et une page avec un **QR code d'appairage** s'ouvre.
2. Si Windows demande l'accès au réseau pour Python, cliquez sur **Autoriser**. Si l'iPhone ne trouve pas le PC, lancez `Pare-feu_autoriser.bat` : il ouvre TCP 8765 et UDP 5353 au réseau local uniquement.
3. Pour démarrer automatiquement avec Windows, en arrière-plan : `Demarrage_auto_activer.bat`.

## 2. Récupérer l'app (fichier IPA)

L'app est compilée automatiquement sur un Mac de GitHub Actions à chaque modification du dossier `ios/` :

- Page **Actions** du dépôt → dernière exécution « Compiler l'app iOS (IPA) » → artefact **PadRemote-ipa**.
- Ou en ligne de commande : `gh run download --repo abasse-ali/PadRemote -n PadRemote-ipa`.

Avec un Mac : `brew install xcodegen && cd ios && xcodegen generate`, puis ouvrez `PadRemote.xcodeproj` dans Xcode et lancez l'app sur l'iPhone.

## 3. Installer l'IPA sur l'iPhone (depuis Windows, avec Sideloadly)

Apple n'autorise l'installation d'une app hors App Store que si elle est **signée avec un identifiant Apple**. Sideloadly s'en charge.

1. Installez **Sideloadly** (sideloadly.io) et ses prérequis indiqués sur le site (iTunes et iCloud).
2. Branchez l'iPhone en USB, déverrouillez-le et touchez **Faire confiance** à cet ordinateur.
3. Dans Sideloadly : glissez `PadRemote.ipa`, entrez votre **identifiant Apple**, puis cliquez sur **Start**.
4. Sur l'iPhone :
   - **Réglages → Confidentialité et sécurité → Mode développeur** : activez-le. L'iPhone redémarre.
   - **Réglages → Général → VPN et gestion de l'appareil** : touchez votre identifiant Apple, puis **Faire confiance**.
5. Lancez PadRemote et **autorisez l'accès au réseau local** quand iOS le demande.

> **Durée de validité.** Avec un identifiant Apple gratuit, l'app fonctionne **7 jours**. Il suffit ensuite de la réinstaller avec Sideloadly (ses réglages permettent de la re-signer automatiquement). Avec un compte développeur Apple payant (99 €/an), la signature dure **1 an**.

## 4. Se connecter

- **Automatique** : le PC apparaît dans la liste « PC détectés » (Bonjour). Touchez-le, puis entrez le code PIN.
- **QR code** : scannez la page d'appairage du PC avec l'appareil photo, puis touchez « Ouvrir dans PadRemote ». La connexion est directe, sans PIN à taper.
- **Manuelle** : entrez l'adresse IP, le port (8765) et le PIN affichés dans la fenêtre du serveur.

Ensuite, l'app se reconnecte toute seule au dernier PC, y compris si son adresse IP change, tant que la détection Bonjour fonctionne.

## Utilisation

| Onglet | Contenu |
|---|---|
| **Souris** | Pavé tactile, molette sur le bord droit, boutons Gauche / Milieu / Droit, bouton ⌨ pour taper en direct avec le clavier iOS |
| **Clavier** | Zone de texte (idéale pour la dictée) + Envoyer, Ctrl/Alt/Maj/Win, touches spéciales, flèches, F1 à F12 |
| **Médias** | Volume, lecture/pause, piste suivante/précédente, présentation (diapos, écran noir), vidéo |
| **Raccourcis** | Édition, Windows, navigateur, ouvrir une URL sur le PC, verrouiller / veille / redémarrer / arrêter |
| **Réglages** | Vitesse du curseur, accélération, défilement (naturel, fluide, inertie), retour haptique, changer de PC |

### Gestes du pavé tactile

| Geste | Action |
|---|---|
| 1 doigt glissé | Déplacer le curseur |
| Toucher / 2 touchers | Clic / double-clic |
| Toucher puis glisser | Sélectionner, glisser-déposer |
| 2 doigts glissés | Défiler (vertical et horizontal, avec inertie) |
| Toucher à 2 doigts | Clic droit |
| Pincer / écarter | Zoom (Ctrl + molette) |
| Toucher à 3 doigts | Clic milieu |
| 3 doigts ↑ / ↓ / ← → | Vue des tâches / Bureau / App précédente |
| Maintenir « Gauche » + glisser un autre doigt | Glisser-déposer |

**Modificateurs** (Ctrl, Alt, Maj, Win) : 1 toucher les active pour la prochaine touche ou le prochain clic (Ctrl + clic, Maj + flèches…), 2 touchers les verrouillent.

## Dépannage

- **Le PC n'apparaît pas dans l'app**
  - Vérifiez que le serveur tourne et que l'iPhone et le PC sont sur le même réseau.
  - Vérifiez que l'accès au réseau local est autorisé : *Réglages → Confidentialité et sécurité → Réseau local → PadRemote*.
  - Lancez `Pare-feu_autoriser.bat`, ou utilisez le QR code ou la connexion manuelle.
- **Partage de connexion de l'iPhone** (PC branché en USB ou connecté au point d'accès de l'iPhone) : la détection automatique peut ne pas fonctionner. Utilisez le QR code ou l'adresse IP affichée (172.20.10.x).
- **Si vous aviez cliqué « Annuler » sur l'alerte du pare-feu**, Windows a créé une règle qui **bloque** Python. Ouvrez *Pare-feu Windows Defender → Autoriser une application* et cochez `python.exe` / `pythonw.exe`.
- **Clics sans effet dans certaines fenêtres** (Gestionnaire des tâches, apps administrateur) : lancez `Demarrer_PadRemote.bat` en tant qu'administrateur. L'écran de verrouillage, l'écran UAC et Ctrl+Alt+Suppr ne sont jamais contrôlables : c'est une protection de Windows.
- **« L'app n'est plus disponible »** après 7 jours : la signature gratuite a expiré, réinstallez-la avec Sideloadly.

## Configuration du serveur (`server/config.json`, créé au premier lancement, non publié)

```json
{ "port": 8765, "pin": "123456", "allow_power": true }
```

- **Nouveau code PIN** : `Demarrer_PadRemote.bat --new-pin`.
- **Interdire veille, arrêt et redémarrage depuis l'iPhone** : `"allow_power": false`.

## Sécurité

- Code PIN obligatoire. Après 5 erreurs, l'adresse est bloquée 60 secondes.
- La page QR code (qui contient le PIN) n'est accessible que depuis le PC lui-même.
- Les règles de pare-feu fournies n'autorisent que le réseau local.
- Les échanges ne sont pas chiffrés (réseau local). N'utilisez pas PadRemote sur un Wi-Fi public.

## Structure

```
ios/                          app iPhone (SwiftUI + UIKit), projet XcodeGen (project.yml)
  PadRemote/Model/            connexion WebSocket (Network.framework), Bonjour, réglages
  PadRemote/Touch/            pavé multi-touch, molette, boutons souris, clavier iOS (UIKit)
  PadRemote/Views/            écrans : connexion, souris, clavier, médias, raccourcis, réglages
.github/workflows/ios.yml     compilation de l'IPA sur macOS (GitHub Actions)
server/padremote.py           serveur HTTP + WebSocket, PIN, alimentation
server/wininput.py            injection souris/clavier (SendInput via ctypes)
server/bonjour.py             annonce Bonjour/mDNS (détection automatique par l'app)
server/pair.html              page QR code d'appairage
web/                          version web de secours (Safari, sans installation)
Demarrer_PadRemote.bat        lance le serveur
```
