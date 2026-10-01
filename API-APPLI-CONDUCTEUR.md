# API JSON — application mobile du conducteur

Version du 2026-09-28, complétée le 2026-09-30 : formats JSON de la messagerie (§4.1 à §4.8), protocole temps réel (§4.9), énumérations (§7), inventaire des points appelés par l'appli (§8), manques connus (§9). Swagger : `/swagger-ui.html`, rubrique **« Appli conducteur »**.

Toutes les réponses sont en JSON (UTF-8). Les dates sans fuseau (`2026-09-28T08:30:00`) sont en heure locale du serveur ; les horodatages avec `Z` sont en UTC.

## 1. Mise en service d'un conducteur

1. Créer un utilisateur de rôle **Conducteur** (écran *Utilisateurs*).
2. Sur l'écran *Conducteurs*, menu de la ligne → **Compte de connexion…** → choisir ce compte.
   Un compte ne peut être relié qu'à une seule fiche.
3. Le conducteur se connecte dans l'appli avec l'email et le mot de passe du compte.

Retirer le compte de la fiche, ou désactiver le compte, coupe l'appli :

- désactivation : immédiatement (le jeton d'accès est refusé dès la requête suivante) ;
- lien retiré : immédiatement pour `/api/moi` (`403`), et le rafraîchissement suivant échoue (`401`).

## 2. Authentification

Deux jetons sont utilisés :

| Jeton | Durée | Où le garder | Usage |
|---|---|---|---|
| `jetonAcces` (JWT) | 60 min (`APP_JWT_EXPIRATION_MINUTES`) | mémoire | en-tête `Authorization: Bearer <jetonAcces>` sur chaque appel |
| `jetonRafraichissement` | 30 jours (`APP_MOBILE_DUREE_JETON_JOURS`) | stockage sécurisé du téléphone (Keychain / Keystore) | obtenir une nouvelle paire de jetons |

Le jeton de rafraîchissement **change à chaque usage** (rotation). L'ancien ne vaut plus rien. Si un jeton déjà utilisé est présenté une nouvelle fois (copie ou vol présumé), **toute la session du téléphone est révoquée** et l'événement est tracé dans le journal d'audit.

Conséquence pour l'appli : il ne faut jamais lancer deux rafraîchissements en parallèle. Mettez-les en file : un seul appel à la fois, les autres requêtes attendent son résultat.

### 2.1 Connexion — `POST /api/auth/mobile/connexion` (public)

```json
{ "email": "rakoto@parc.mg", "motDePasse": "••••••••", "appareil": "Samsung A14" }
```

`appareil` est facultatif (100 caractères au plus). Il sert à la traçabilité.

**Formats acceptés** par `/connexion`, `/rafraichir` et `/deconnexion` :

- **JSON**, recommandé : `Content-Type: application/json`.
- **Formulaire** : `multipart/form-data` (Postman « form-data ») ou `application/x-www-form-urlencoded`, avec des champs de même nom. Exemples : `email`, `motDePasse`, `appareil` ; `jetonRafraichissement`.

La réponse est toujours en JSON.

```bash
curl -X POST http://SERVEUR:8080/api/auth/mobile/connexion \
  -F email=rakoto@parc.mg -F motDePasse='••••••••' -F appareil="Samsung A14"
```

Réponse `200` :

```json
{
  "jetonAcces": "eyJhbGciOiJIUzI1NiJ9…",
  "typeJeton": "Bearer",
  "expireDans": 3600,
  "jetonRafraichissement": "q3Zt0x0pX8…(43 caractères)",
  "expirationRafraichissement": "2026-10-28T08:30:00Z",
  "role": "CONDUCTEUR",
  "idConducteur": 12,
  "nomComplet": "Jean Rakoto",
  "espace": "CONDUCTEUR",
  "urlPhoto": "/api/photos-profil/conducteurs/12?v=1790673826032"
}
```

`espace` (2026-09-29) : la même appli sert aussi l'équipe maintenance. `CONDUCTEUR` ouvre l'espace décrit ici (`/api/moi`) ; `MAINTENANCE` ouvre l'appli maintenance (`/api/atelier`, voir `API-APPLI-MAINTENANCE.md`), et `idConducteur` vaut alors `null`.

**Contenu du jeton d'accès** : le JWT porte les claims `sub` (email), `idUtilisateur`, `role`, `iat` et `exp`.

`idUtilisateur` est **distinct** de `idConducteur` (compte ≠ fiche). C'est `idUtilisateur` qui apparaît dans la messagerie (`auteur.idUtilisateur`, `interlocuteur.idUtilisateur`, `contacts[].idUtilisateur`) : l'appli en a besoin pour reconnaître ses propres messages. Il n'est renvoyé par aucun corps de réponse de `/api/auth/mobile/*` ; l'appli le lit donc dans le jeton, sans vérifier la signature. Pour éviter cette lecture, ajouter `idUtilisateur` à la réponse de connexion et de rafraîchissement (voir §9).

| Code | Cas | Message |
|---|---|---|
| 400 | champ manquant | `Un ou plusieurs champs sont invalides` |
| 401 | identifiants faux | `Email ou mot de passe incorrect` |
| 401 | compte désactivé (bon mot de passe) | `Compte désactivé` |
| 403 | rôle sans appli mobile (assistant parc, administrateur, comptable) | `L'application mobile est réservée aux conducteurs et à l'équipe maintenance` |
| 403 | compte non relié à une fiche | `Votre compte n'est relié à aucune fiche conducteur : contactez le responsable du parc` |
| 429 | 5 échecs sur ce compte, ou 20 depuis cette adresse, en 15 min | `Trop de tentatives de connexion. Réessayez dans 15 minutes.` |

### 2.2 Rafraîchissement — `POST /api/auth/mobile/rafraichir` (public)

```json
{ "jetonRafraichissement": "q3Zt0x0pX8…" }
```

Réponse `200` : même format que la connexion, avec de **nouveaux** jetons. Remplacez les deux.

Réponse `401` avec `Session expirée : reconnectez-vous` dans ces cas :

- jeton inconnu, expiré ou déjà utilisé ;
- compte désactivé ;
- lien avec la fiche retiré.

Dans tous ces cas, effacez les jetons et affichez l'écran de connexion.

### 2.3 Déconnexion — `POST /api/auth/mobile/deconnexion` (public)

Corps identique à `/rafraichir`. Réponse : toujours `204`, même pour un jeton inconnu. Effacez ensuite les jetons du téléphone.

### 2.4 Jeton d'accès expiré

Tout appel avec un jeton absent ou expiré répond `401` :

```json
{ "horodatage": "2026-09-28T09:31:02Z", "statut": 401, "erreur": "Authentification requise",
  "message": "Session absente ou expirée : reconnectez-vous", "details": [] }
```

Sur ce `401`, l'appli appelle `/rafraichir` une fois, puis rejoue la requête.

## 3. Espace conducteur — `/api/moi` (rôle CONDUCTEUR)

Aucun identifiant de conducteur n'apparaît dans les URL : le serveur sert toujours la fiche reliée au compte connecté.

**Véhicule du moment** : c'est le véhicule de la mission EN_COURS. Sans mission en cours, c'est celui de l'affectation ACTIVE la plus récente.

**Périmètre de saisie** (plein, incident) : les véhicules des affectations actives et des missions en cours. Une mission seulement planifiée ne donne pas ce droit : il faut d'abord la démarrer.

Les **niveaux d'échéance** (`niveau`) valent :

- `OK` ;
- `BIENTOT` : 30 jours ou moins ;
- `EXPIRE` ;
- `SANS_DATE`.

### 3.1 Accueil — `GET /api/moi`

Tout l'écran d'accueil en un seul appel :

```json
{
  "profil": {
    "idConducteur": 12, "matricule": "C-012", "nom": "Rakoto", "prenom": "Jean",
    "telephone": "034 00 000 00", "email": "rakoto@parc.mg",
    "categorie": "VEHICULE_ROUTIER", "statut": "EN_SERVICE",
    "qualification": { "type": "PERMIS", "numero": "B-778812", "categorie": "C",
                       "dateExpiration": "2026-10-15", "joursRestants": 17, "niveau": "BIENTOT" },
    "urlPhoto": "/api/photos-profil/conducteurs/12?v=1790673826032"
  },
  "vehicule": {
    "idEngin": 4, "identifiant": "1234 TAB", "libelle": "1234 TAB — Toyota Hilux",
    "marque": "Toyota", "modele": "Hilux", "categorie": "VEHICULE_ROUTIER", "statut": "EN_MISSION",
    "kilometrage": 84210.0, "compteurHeures": 0.0, "source": "MISSION"
  },
  "missionEnCours": {
    "idMission": 88, "motif": "Livraison chantier Ivato", "statut": "EN_COURS",
    "dateDebutPrevue": "2026-09-28T07:00:00", "dateFinPrevue": "2026-09-28T17:00:00",
    "dateDebutReelle": "2026-09-28T07:12:40", "dateFinReelle": null,
    "kilometrageDepart": 84150.0, "kilometrageRetour": null,
    "idEngin": 4, "vehicule": "1234 TAB — Toyota Hilux"
  },
  "prochainesMissions": [],
  "messagesNonLus": 3,
  "alertesVehicule": 1
}
```

`vehicule` et `missionEnCours` valent `null` quand il n'y en a pas. `qualification.type` vaut `CACES` pour un conducteur d'engin.

### 3.2 Profil — `GET /api/moi/profil`

Renvoie l'objet `profil` ci-dessus.

### 3.3 Mon véhicule — `GET /api/moi/vehicule`

```json
{
  "vehicule": { "idEngin": 4, "identifiant": "1234 TAB", "…": "…" },
  "energie": "GASOIL",
  "capaciteReservoirLitres": 80.0,
  "idMissionEnCours": 88,
  "documents": [
    { "type": "ASSURANCE", "numeroReference": "AS-2026-114", "dateExpiration": "2026-10-01",
      "joursRestants": 3, "niveau": "BIENTOT" }
  ],
  "alertes": [
    { "type": "PERTE_CONNEXION_GPS", "priorite": "ELEVEE", "description": "Aucune position reçue depuis 45 min",
      "nombreOccurrences": 12, "premiereOccurrence": "2026-09-28T06:00:00Z",
      "derniereOccurrence": "2026-09-28T09:00:00Z" }
  ],
  "dernierPlein": { "dateHeure": "2026-09-27T16:40:00", "kilometrageAuPlein": 84002.0, "quantiteLitres": 55.0,
                   "typeApprovisionnement": "PLEIN_COMPLET" }
}
```

Les alertes non traitées sont **regroupées par type**, comme sur le rapport du véhicule à l'écran web.

`documents` liste tous les documents de l'engin, y compris ceux sans date (`dateExpiration` et `joursRestants` à `null`, `niveau: "SANS_DATE"`) ; `joursRestants` est **négatif** pour un document expiré (ex. `-28`). Valeurs de `documents[].type`, de `alertes[].type` et de `alertes[].priorite` : voir §7. `energie`, `capaciteReservoirLitres`, `idMissionEnCours` et `dernierPlein` peuvent valoir `null`. `compteurHeures` vaut `0.0` pour un véhicule routier ; c'est le compteur utile pour un engin de chantier (dont `kilometrage` peut alors rester à `0.0`).

- Pas de véhicule en ce moment : `404`, message `Aucun véhicule ne vous est affecté actuellement`. Ce n'est pas une erreur pour l'appli : c'est l'état « aucun véhicule affecté » de l'écran.

### 3.4 Missions

- `GET /api/moi/missions` renvoie une liste de missions (format `missionEnCours`) dans cet ordre :
  1. en cours ;
  2. planifiées, de la plus proche à la plus lointaine ;
  3. les 30 dernières terminées ou annulées.
- `POST /api/moi/missions/{id}/demarrer` et `POST /api/moi/missions/{id}/terminer` prennent le corps suivant et renvoient la mission à jour :

```json
{ "kilometrage": 84150 }
```

`statut` vaut `PLANIFIEE`, `EN_COURS`, `TERMINEE` ou `ANNULEE`. Les deux actions renvoient `200` avec la mission à jour (même format que `missionEnCours`) : `demarrer` renseigne `dateDebutReelle` et `kilometrageDepart`, `terminer` renseigne `dateFinReelle` et `kilometrageRetour`.

Il n'existe **pas** de point « détail d'une mission » (`GET /api/moi/missions/{id}`) : l'écran de détail se construit avec l'élément déjà lu dans la liste.

Les règles de gestion s'appliquent comme à l'écran web :

- seule une mission PLANIFIEE peut démarrer ;
- le permis ou le CACES doit être valide ;
- l'engin doit avoir une assurance valide (règle 11.20) ;
- le kilométrage envoyé ne peut pas être inférieur au compteur actuel de l'engin ;
- le kilométrage de retour ne peut pas être inférieur à celui de départ.

| Code | Cas | Message |
|---|---|---|
| 400 | `kilometrage` absent | `Un ou plusieurs champs sont invalides`, `details` : `["kilometrage : ne doit pas être nul"]` |
| 403 | mission d'un autre conducteur | `Cette mission ne vous est pas attribuée` |
| 404 | mission inconnue | `Mission introuvable (id=91)` |
| 409 | mauvais statut | `Seule une mission PLANIFIEE peut démarrer (statut actuel : EN_COURS)` |
| 409 | assurance | `L'engin '1234 TAB — Toyota Hilux' n'a pas d'assurance valide, la mission ne peut pas démarrer (règle 11.20)` |
| 409 | compteur au démarrage | `Le kilométrage (84100,0) ne peut pas être inférieur au kilométrage actuel (84360,0)` |
| 409 | compteur au retour | `Le kilométrage de retour (84100,0) ne peut pas être inférieur au kilométrage de départ (84150,0)` |

### 3.5 Carburant (plein complet, appoint, bidon)

- `GET /api/moi/pleins` : mes 50 dernières saisies carburant.
- `POST /api/moi/pleins` :

```json
{ "typeApprovisionnement": "APPOINT", "kilometrageAuPlein": 84230, "quantiteLitres": 20,
  "prixUnitaire": 5200, "station": "Jovena Ivato" }
```

Valeurs de `typeApprovisionnement` :

- `PLEIN_COMPLET` : valeur par défaut si le champ est absent ;
- `APPOINT` : quelques litres, réservoir non plein ;
- `BIDON` : remplissage au jerrican.

Le kilométrage au compteur reste **obligatoire** pour les trois types.

La consommation se calcule **de plein complet à plein complet**. Les litres des appoints et des bidons entre les deux y sont additionnés.

**Contrôle au 100 km à chaque saisie** (plein complet, appoint ou bidon) :

- On compare les litres ajoutés depuis le dernier plein complet aux kilomètres parcourus depuis, en L/100 km.
- La référence est la consommation de la fiche du véhicule ; sans elle, c'est la moyenne habituelle du véhicule.
- Au-delà du seuil (réglable dans Paramètres, +20 % par défaut, avec une tolérance de 5 L), le serveur crée une alerte « consommation anormale » pour les responsables.
- La saisie est enregistrée quand même, et la réponse reste `201`.

**Qualité des saisies** (2026-09-29) :

- **Refus `409`** : plus de litres que le réservoir (+5 %) pour un plein ou un appoint, ou doublon (même véhicule, moins de 10 minutes d'écart, même quantité à 0,5 L près).
- **À confirmer `422`** : distance impossible depuis la saisie précédente (plus de 130 km/h de moyenne, 60 km/h pour un engin), compteur horaire plus rapide que le temps, ou kilométrage supérieur à celui d'une saisie plus récente. `details` liste les points à vérifier.
- Pour confirmer, renvoyer la même requête avec `?confirmer=true` : la saisie est enregistrée (`201`) et une alerte « Saisie à vérifier » est créée pour les responsables.

```json
{ "statut": 422, "erreur": "Saisie à confirmer", "message": "Saisie à vérifier : confirmez-la si elle est juste",
  "details": ["900 km en 2 h depuis la saisie du 28/09/2026 à 08:00, soit 450 km/h de moyenne (plus de 130 km/h) : distance impossible ?"] }
```

Champs facultatifs :

- `idEngin` : par défaut, le véhicule du moment ;
- `dateHeure` : par défaut, maintenant.

Le conducteur enregistré est toujours celui connecté.

Réponse `201` :

```json
{ "idCarburant": 301, "dateHeure": "2026-09-28T10:02:11", "kilometrageAuPlein": 84230.0,
  "quantiteLitres": 20.0, "prixUnitaire": 5200.0, "montantTotal": 104000.0,
  "station": "Jovena Ivato", "typeApprovisionnement": "APPOINT",
  "idEngin": 4, "vehicule": "1234 TAB — Toyota Hilux" }
```

`station` peut être omis : il vaut alors `null` dans la réponse (cas courant du `BIDON`). `montantTotal` est calculé par le serveur (`quantiteLitres × prixUnitaire`) : ne l'envoyez pas. `GET /api/moi/pleins` rend la liste **du plus récent au plus ancien**.

**Écart observé sur le backend de développement (2026-09-30)** : `typeApprovisionnement` est absent des réponses (liste et `201`), alors qu'il est documenté ici. L'appli le lit donc comme facultatif et affiche « Approvisionnement » à défaut. À confirmer côté serveur : soit le champ est ajouté aux réponses, soit il est retiré de cette documentation.

Codes :

- `403` : `Ce véhicule ne vous est pas affecté actuellement` ;
- `409` : aucun véhicule (`Aucun véhicule ne vous est affecté actuellement`), ou kilométrage inférieur au compteur (`Le kilométrage (84100,0) ne peut pas être inférieur au kilométrage actuel (84230,0)`) ;
- `400` : champ invalide (`details` : `["quantiteLitres : doit être supérieur à 0"]`) ou type inconnu (`Le corps de la requête est illisible (JSON attendu, encodé en UTF-8)`).

### 3.6 Incidents et photos

- `GET /api/moi/incidents` : mes 50 derniers incidents.
- `POST /api/moi/incidents` :

```json
{ "type": "PANNE", "gravite": "ELEVEE", "description": "Voyant moteur allumé, perte de puissance" }
```

Valeurs possibles :

- `type` : `ACCIDENT`, `PANNE`, `VOL`, `AUTRE` ;
- `gravite` : `FAIBLE`, `MOYENNE`, `ELEVEE`, `CRITIQUE`. `CRITIQUE` prévient immédiatement les responsables.

Champs facultatifs :

- `idEngin` : par défaut, le véhicule du moment ;
- `dateSurvenue` : par défaut, maintenant.

La mission en cours sur ce véhicule est rattachée automatiquement.

Réponse `201` :

```json
{ "idIncident": 57, "type": "PANNE", "gravite": "ELEVEE", "statut": "DECLARE",
  "description": "Voyant moteur allumé, perte de puissance", "dateSurvenue": "2026-09-28T10:05:00",
  "idEngin": 4, "vehicule": "1234 TAB — Toyota Hilux", "idMission": 88, "nombrePhotos": 0 }
```

- `POST /api/moi/incidents/{id}/photos` : envoi en `multipart/form-data`.
  - Partie `fichier` : JPEG, PNG ou WebP, 5 Mo au plus.
  - Paramètre `legende` : facultatif.
  - Limite : 10 photos par incident. Impossible sur un incident clôturé.

  Réponse `201` :

```json
{ "idPhoto": 140, "legende": "Tableau de bord", "dateAjout": "2026-09-28T07:06:12Z",
  "url": "/api/moi/incidents/photos/140/fichier" }
```

- `GET /api/moi/incidents/{id}/photos` : liste des photos d'un de mes incidents (`legende` peut valoir `null`).
- `GET /api/moi/incidents/photos/{idPhoto}/fichier` : l'image, avec l'en-tête `Authorization`. `Content-Type: image/jpeg` (ou le type d'origine). Photo inconnue : `404`, `IncidentPhoto introuvable (id=140)`.

`statut` d'un incident vaut `DECLARE`, `EN_TRAITEMENT` ou `CLOTURE` ; il est fixé par les responsables, l'appli ne peut pas le changer. `idMission` vaut `null` quand aucune mission n'était en cours ; l'appli tolère aussi `idEngin` et `vehicule` absents ou `null`. `nombrePhotos` évite un second appel pour afficher le compteur. La liste est rendue **du plus récent au plus ancien**, et il n'existe pas de point « détail d'un incident » : l'écran de détail réutilise l'élément de la liste, plus `GET …/photos`.

Le champ `url` renvoyé avec une photo est un **chemin relatif** à préfixer par l'URL du serveur ; il est déjà égal à `/api/moi/incidents/photos/{idPhoto}/fichier`.

Codes :

- `403` : `Cet incident n'a pas été déclaré par vous` (photos), `Ce véhicule ne vous est pas affecté actuellement` (déclaration) ;
- `400` : champ invalide (`details` : `["description : ne doit pas être vide"]`), ou valeur de `type` / `gravite` inconnue → `Le corps de la requête est illisible (JSON attendu, encodé en UTF-8)` ;
- `413` : fichier trop gros (`Le fichier envoyé dépasse la taille maximale autorisée (5 Mo)`) ;
- `409` : incident clôturé (`Cet incident est clôturé : on ne peut plus y ajouter de photo`), ou 10 photos déjà envoyées (`10 photos au plus par incident`).

Il n'y a pas de suppression de photo : une photo envoyée par erreur reste en place (voir §9).

### 3.7 Photo de profil (2026-09-29)

Chaque compte a une photo de profil (`null` = afficher les initiales). Pour un conducteur relié à un compte, la fiche et le compte partagent la même photo.

- **URL de la photo** : champ `urlPhoto` de la session (connexion et rafraîchissement) et `profil.urlPhoto` de `/api/moi` (photo de la fiche, à défaut celle du compte). Exemple : `/api/photos-profil/utilisateurs/7?v=1790673826032`. Chargez-la avec le même en-tête `Authorization` ; `v` change à chaque nouvelle photo, l'image peut donc rester en cache.
- **Mon profil** : `GET /api/mon-compte/profil` → `{ idUtilisateur, nom, prenom, nomComplet, email, role, idConducteur, urlPhoto }`.
- **Changer ma photo** : `PUT /api/mon-compte/photo`, multipart, champ `fichier` (JPEG ou PNG, 5 Mo au plus) → `{ "urlPhoto": "…" }`. Un renvoi remplace simplement la photo : il est sans risque.
- **Retirer ma photo** : `DELETE /api/mon-compte/photo` → `{ "urlPhoto": null }`.

Le serveur recadre l'image en carré centré, la réduit à 512 px, la redresse selon l'orientation EXIF du téléphone et la réencode en JPEG : aucune métadonnée n'est conservée (position GPS, appareil). Côté appli, proposez un recadrage carré avant l'envoi et convertissez les photos HEIC (iPhone) en JPEG.

| Code | Cas |
|---|---|
| 409 | format non accepté (ni JPEG ni PNG), photo trop petite (moins de 64 px de côté) ou trop grande (plus de 8 000 px), fichier vide |
| 413 | fichier au-delà de la limite du serveur |

## 4. Messagerie

L'appli utilise les points **existants** de la messagerie interne, avec le jeton d'accès :

| Appel | Rôle | Détail |
|---|---|---|
| `GET /api/messagerie/conversations` | mes conversations (privées, canaux de mon rôle) | §4.1 |
| `GET /api/messagerie/non-lus` | total non lus | §4.2 |
| `GET /api/messagerie/contacts` | destinataires possibles | §4.3 |
| `POST /api/messagerie/conversations/privee` | ouvrir une conversation privée | §4.4 |
| `GET /api/messagerie/conversations/{id}/messages?avant=&limite=` | messages (pagination vers le passé) | §4.5 |
| `POST /api/messagerie/conversations/{id}/messages` | envoyer (multipart : `contenu`, `fichiers` photos/PDF) | §4.6 |
| `POST /api/messagerie/conversations/{id}/lu` | marquer comme lu | §4.7 |
| `GET /api/messagerie/pieces-jointes/{id}` | télécharger une pièce jointe | §4.8 |
| `POST /api/messagerie/ticket-temps-reel` puis `wss://…/ws/messagerie?ticket=…` | temps réel (ticket à usage unique, 30 s) | §4.9 |

Les fils de discussion par véhicule ou par mission restent réservés aux profils de gestion.

Dans toute la messagerie, un utilisateur est décrit par le même objet :

```json
{ "idUtilisateur": 2, "nomComplet": "Hery RAKOTO", "role": "RESPONSABLE_PARC" }
```

`role` est le rôle du compte (`CONDUCTEUR`, `RESPONSABLE_PARC`, `CHEF_MAINTENANCE`, `ADMINISTRATEUR`, `COMPTABLE`, `DG`…) : traitez-le comme un texte libre, de nouveaux rôles peuvent apparaître.

### 4.1 Mes conversations — `GET /api/messagerie/conversations`

```json
[
  { "idConversation": 5, "type": "PRIVEE", "titre": "Hery RAKOTO",
    "objetType": null, "objetId": null,
    "interlocuteur": { "idUtilisateur": 2, "nomComplet": "Hery RAKOTO", "role": "RESPONSABLE_PARC" },
    "dateDernierMessage": "2026-09-28T08:15:30Z", "nonLus": 2 },
  { "idConversation": 3, "type": "CANAL", "titre": "Conducteurs",
    "objetType": null, "objetId": null, "interlocuteur": null,
    "dateDernierMessage": "2026-09-27T17:02:11Z", "nonLus": 1 }
]
```

- `type` : `PRIVEE`, `CANAL` ou `FIL`. Un conducteur ne voit que ses conversations privées et les canaux de son rôle ; les `FIL` (par véhicule ou par mission) ne lui sont pas servis.
- `interlocuteur` n'est renseigné que pour une conversation `PRIVEE` ; il vaut `null` pour un canal.
- `objetType` / `objetId` désignent l'objet rattaché à un `FIL` (`null` pour un conducteur).
- `dateDernierMessage` vaut `null` pour une conversation sans message. Trier dessus, du plus récent au plus ancien.
- `nonLus` est le nombre de messages non lus de cette conversation ; leur somme correspond au `total` de §4.2.

### 4.2 Total non lus — `GET /api/messagerie/non-lus`

```json
{ "total": 3 }
```

C'est la même valeur que `messagesNonLus` de `GET /api/moi` : gardez la plus récente des deux pour le badge.

### 4.3 Contacts — `GET /api/messagerie/contacts`

Liste des destinataires possibles, au format utilisateur ci-dessus :

```json
[ { "idUtilisateur": 5, "nomComplet": "Lova ANDRIA", "role": "CHEF_MAINTENANCE" },
  { "idUtilisateur": 2, "nomComplet": "Hery RAKOTO", "role": "RESPONSABLE_PARC" },
  { "idUtilisateur": 1, "nomComplet": "Nirina RAZAFY", "role": "DG" } ]
```

Le compte connecté n'y figure pas. La liste n'est ni paginée ni filtrable : le filtre par nom se fait côté appli.

### 4.4 Ouvrir une conversation privée — `POST /api/messagerie/conversations/privee`

```json
{ "idUtilisateur": 2 }
```

Réponse `200` : la conversation, au format de §4.1 (celle qui existe déjà, sinon une nouvelle). L'appel est donc **idempotent** : inutile de vérifier au préalable si la conversation existe.

| Code | Cas | Message |
|---|---|---|
| 404 | destinataire inconnu | `Utilisateur introuvable (id=99)` |
| 409 | destinataire = soi-même | `Impossible d'ouvrir une conversation avec soi-même` |

### 4.5 Messages — `GET /api/messagerie/conversations/{id}/messages?avant=&limite=`

```json
[
  { "idMessage": 410, "idConversation": 5,
    "auteur": { "idUtilisateur": 2, "nomComplet": "Hery RAKOTO", "role": "RESPONSABLE_PARC" },
    "contenu": "Bonjour Tiana, le chantier d'Ivato attend le ciment avant 10 h.",
    "dateEnvoi": "2026-09-28T06:40:02Z", "piecesJointes": [] },
  { "idMessage": 415, "idConversation": 5,
    "auteur": { "idUtilisateur": 2, "nomComplet": "Hery RAKOTO", "role": "RESPONSABLE_PARC" },
    "contenu": "Voici le bon de livraison.", "dateEnvoi": "2026-09-28T08:15:30Z",
    "piecesJointes": [ { "idPieceJointe": 31, "nom": "bon-livraison-ivato.pdf",
                         "typeContenu": "application/pdf", "taille": 184233, "image": false } ] }
]
```

- Les messages sont rendus **du plus ancien au plus récent** dans la page.
- `limite` : nombre de messages, 100 au plus (30 est un bon choix pour un téléphone).
- `avant` : `idMessage` du plus ancien message déjà affiché ; la pagination remonte donc vers le passé. Une page vide signifie « début de la conversation ».
- `contenu` peut valoir `null` (message composé uniquement de pièces jointes).
- `piecesJointes[].taille` est en octets ; `image` à `true` signale un aperçu affichable, `false` un document (PDF).
- L'auteur est identifié par `auteur.idUtilisateur` : comparez-le au claim `idUtilisateur` du jeton (§2.1) pour savoir si le message est le vôtre.

### 4.6 Envoyer — `POST /api/messagerie/conversations/{id}/messages`

`multipart/form-data` :

- `contenu` : texte, facultatif si au moins un fichier est joint ;
- `fichiers` : zéro, une ou plusieurs parties de même nom.

Types acceptés (observé) : JPEG, PNG, WebP et PDF. Réponse `201` : le message créé, au format de §4.5, pièces jointes comprises. Le même message revient aussi par le WebSocket (§4.9) : dédoublonnez sur `idMessage`.

### 4.7 Marquer comme lu — `POST /api/messagerie/conversations/{id}/lu`

Sans corps. Réponse `204`. Remet `nonLus` à `0` pour cette conversation et diminue d'autant le `total` de §4.2.

### 4.8 Pièce jointe — `GET /api/messagerie/pieces-jointes/{id}`

Le fichier lui-même, avec l'en-tête `Authorization` :

```
Content-Type: application/pdf
Content-Disposition: attachment; filename="bon-livraison-ivato.pdf"
```

Les erreurs de ce point restent au format JSON de §5, même si la réponse attendue est binaire : décodez le corps avant de l'afficher.

### 4.9 Temps réel — WebSocket

1. `POST /api/messagerie/ticket-temps-reel` (avec le jeton d'accès) :

```json
{ "ticket": "Vd3kQ9x2LmT7pR4sW8yB1nC6fH0jK5gA2zE9uX3oI7q", "expireDansSecondes": 30 }
```

2. Ouvrir `wss://SERVEUR/ws/messagerie?ticket=<ticket>` dans les 30 s. Le ticket est à **usage unique** : il faut en demander un nouveau à chaque connexion, y compris à chaque reconnexion.

Le jeton d'accès n'est pas transmis sur le WebSocket : le ticket sert d'authentification. Un client natif n'envoie pas d'en-tête `Origin` et est donc accepté ; si un en-tête `Origin` est envoyé, il doit figurer dans `APP_CORS_ALLOWED_ORIGINS`.

**Trames reçues** (texte JSON) :

```json
{ "type": "MESSAGE", "idConversation": 5,
  "message": { "idMessage": 418, "idConversation": 5,
    "auteur": { "idUtilisateur": 27, "nomComplet": "Tiana RABE", "role": "CONDUCTEUR" },
    "contenu": "Déchargement terminé.", "dateEnvoi": "2026-09-28T10:20:05Z",
    "piecesJointes": [ { "idPieceJointe": 32, "nom": "chargement.jpg",
                         "typeContenu": "image/jpeg", "taille": 412880, "image": true } ] } }
```

```json
{ "type": "PONG" }
```

`message` a exactement le format de §4.5. Un `type` inconnu doit être ignoré sans fermer la socket (des types pourront être ajoutés).

**Trames envoyées** : le texte `ping` (et rien d'autre), auquel le serveur répond `{"type":"PONG"}`.

Côté appli (valeurs retenues, non imposées par le serveur) : `ping` toutes les 25 s, socket considérée comme morte après 35 s sans aucune trame, reconnexion avec attente exponentielle (1 s → 30 s) et *jitter*, une seule socket ouverte à la fois. Sur un `401` ou un `403` au moment de demander le ticket, arrêter les tentatives : la session est à refaire.

Le WebSocket ne porte **que** les nouveaux messages. Les changements de mission, d'incident, de document ou d'alerte ne sont pas poussés : l'appli les détecte en comparant les réponses de `/api/moi`, `/api/moi/missions`, `/api/moi/incidents` et `/api/moi/vehicule` entre deux synchronisations (toutes les 5 min au premier plan, et au retour dans l'appli). Voir §9.

## 5. Format d'erreur commun

```json
{ "horodatage": "2026-09-28T09:31:02Z", "statut": 409, "erreur": "Règle de gestion violée",
  "message": "Le kilométrage de retour (84100,0) ne peut pas être inférieur au kilométrage de départ (84150,0)",
  "details": [] }
```

`details` liste les champs invalides quand le statut est `400`. Affichez `message` tel quel : il est rédigé pour l'utilisateur.

| Code | Sens | Action de l'appli |
|---|---|---|
| 400 | requête invalide | afficher `message` et `details` |
| 401 | session absente ou expirée | rafraîchir une fois, sinon écran de connexion |
| 403 | hors de votre périmètre | afficher `message` |
| 404 | introuvable, ou pas de véhicule | afficher `message` |
| 409 | règle de gestion | afficher `message` |
| 413 | fichier trop volumineux | proposer de réduire la photo |
| 422 | saisie à confirmer (carburant) | afficher `details`, proposer « Corriger » ou « Enregistrer quand même » (`?confirmer=true`) |
| 429 | trop de tentatives de connexion | attendre 15 min |

## 6. Sécurité

- **Transport** : HTTPS obligatoire en production. Le jeton de rafraîchissement ne doit apparaître dans aucun journal ni dans aucune URL.
- **Stockage** : la base ne garde que l'empreinte SHA-256 du jeton de rafraîchissement, jamais le jeton lui-même.
- **Périmètre** : les mêmes contrôles s'appliquent aux points communs de l'API web quand ils sont appelés avec un compte conducteur (plein, incident, kilométrage, démarrage et fin de mission).
- **Journal des connexions** (2026-09-29) : chaque tentative, web ou appli, réussie ou non, est journalisée (compte, adresse IP, en-tête `User-Agent`, motif du refus) et gardée 12 mois. Envoyez un `User-Agent` explicite, par exemple `ParkAutoConducteur/1.0 (Android 14)`. Le limiteur de tentatives est commun au web et à l'appli.
- **Limite actuelle** : le limiteur de tentatives et le verrou de rotation fonctionnent en mémoire et en base sur **un seul serveur**. Avec plusieurs instances, il faudra déplacer le limiteur, par exemple vers Redis.

## 7. Énumérations

Toutes ces valeurs arrivent en texte majuscule. **Une valeur inconnue ne doit jamais faire échouer l'affichage** : prévoyez un libellé de repli, la liste peut s'allonger côté serveur.

| Champ | Valeurs |
|---|---|
| `profil.categorie`, `vehicule.categorie` | `VEHICULE_ROUTIER`, `ENGIN_CHANTIER` |
| `profil.statut` | `EN_SERVICE`, `SUSPENDU`, `CONGE`, `INACTIF` |
| `qualification.type` | `PERMIS` (véhicule routier), `CACES` (engin de chantier) |
| `niveau` (qualification, document) | `OK`, `BIENTOT` (≤ 30 jours), `EXPIRE`, `SANS_DATE` |
| `vehicule.statut` | `DISPONIBLE`, `AFFECTE`, `EN_MISSION`, `EN_PANNE`, `EN_MAINTENANCE`, `REFORME`, `VENDU` |
| `vehicule.source` | `MISSION` (véhicule de la mission en cours), `AFFECTATION` |
| `energie` | `GASOIL`, `ESSENCE`, `ELECTRIQUE`, `HYBRIDE`, `AUTRE` |
| `documents[].type` | `CARTE_GRISE`, `ASSURANCE`, `VISITE_TECHNIQUE`, `PERMIS_CONDUIRE`, `CONFORMITE_FISCALE`, `LICENCE_TRANSPORT`, `CARTE_CARBURANT`, `AUTRE` |
| `alertes[].type` | `SURVITESSE`, `DEPLACEMENT_ANORMAL`, `ARRET_PROLONGE`, `ENTREE_ZONE_INTERDITE`, `SORTIE_ZONE_AUTORISEE`, `PERTE_CONNEXION_GPS`, `GPS_DESACTIVE_PENDANT_MISSION`, `STOCK_PIECE_BAS`, `MAINTENANCE_A_PREVOIR`, `CONSOMMATION_ANORMALE`, `BAISSE_CARBURANT_SUSPECTE`, `DOCUMENT_EXPIRE`, `DOCUMENT_A_EXPIRER`, `INCIDENT_CRITIQUE` |
| `alertes[].priorite`, `incident.gravite` | `FAIBLE`, `MOYENNE`, `ELEVEE`, `CRITIQUE` |
| `mission.statut` | `PLANIFIEE`, `EN_COURS`, `TERMINEE`, `ANNULEE` |
| `typeApprovisionnement` | `PLEIN_COMPLET`, `APPOINT`, `BIDON` |
| `incident.type` | `ACCIDENT`, `PANNE`, `VOL`, `AUTRE` |
| `incident.statut` | `DECLARE`, `EN_TRAITEMENT`, `CLOTURE` |
| `conversation.type` | `PRIVEE`, `CANAL`, `FIL` (les `FIL` ne sont pas servis à un conducteur) |
| `role`, `espace` | `role` : texte libre (`CONDUCTEUR`, `RESPONSABLE_PARC`, `CHEF_MAINTENANCE`, `ADMINISTRATEUR`, `COMPTABLE`, `DG`…) ; `espace` : `CONDUCTEUR`, `MAINTENANCE` |

## 8. Inventaire des points appelés par l'appli conducteur

État au 2026-09-30 de l'appli Flutter (`ParkAuto` conducteur).

| Point | Écran / usage dans l'appli |
|---|---|
| `POST /api/auth/mobile/connexion` | écran de connexion (envoie `appareil`) |
| `POST /api/auth/mobile/rafraichir` | intercepteur HTTP, un seul rafraîchissement à la fois, les autres requêtes attendent |
| `POST /api/auth/mobile/deconnexion` | déconnexion, puis effacement du stockage sécurisé |
| `GET /api/moi` | accueil, et synchronisation périodique |
| `GET /api/moi/profil` | écran profil |
| `GET /api/moi/vehicule` | écran « Mon véhicule » (documents, alertes, dernier plein) ; `404` = état « aucun véhicule » |
| `GET /api/moi/missions` | liste et détail des missions |
| `POST /api/moi/missions/{id}/demarrer` · `/terminer` | feuille d'action « Démarrer » / « Terminer » avec saisie du kilométrage |
| `GET /api/moi/pleins` · `POST /api/moi/pleins` | historique carburant groupé par mois, formulaire de saisie |
| `GET /api/moi/incidents` · `POST /api/moi/incidents` | liste et déclaration d'incident (appareil photo intégré) |
| `POST /api/moi/incidents/{id}/photos` | envoi des photos après la déclaration, une par une, avec barre de progression |
| `GET /api/moi/incidents/{id}/photos` · `GET …/photos/{idPhoto}/fichier` | galerie de l'incident |
| Messagerie §4.1 à §4.8 | liste des conversations, écran de discussion, contacts, pièces jointes |
| `POST /api/messagerie/ticket-temps-reel` + `wss://…/ws/messagerie` | réception immédiate des messages, ticket renouvelé à chaque connexion |

**Points documentés ici que l'appli n'utilise pas encore** — à traiter côté appli, pas côté serveur :

| Point / champ | Conséquence actuelle |
|---|---|
| `espace` de la réponse de connexion | l'appli suppose `CONDUCTEUR` ; un compte de maintenance arrive sur l'espace conducteur au lieu de `/api/atelier` |
| `urlPhoto`, `GET /api/mon-compte/profil`, `PUT`/`DELETE /api/mon-compte/photo` (§3.7) | pas de photo de profil : seules les initiales sont affichées, et la photo n'est pas modifiable depuis le téléphone |
| `422` carburant et `?confirmer=true` (§3.5) | une saisie « à confirmer » est présentée comme une erreur, sans le choix « Enregistrer quand même » |
| `User-Agent` explicite (§6) | le journal des connexions enregistre l'agent par défaut de la plateforme, moins lisible que `ParkAutoConducteur/1.0 (Android 14)` |

## 9. Manques connus, du point de vue de l'appli

Rien de bloquant : l'appli fonctionne avec les points ci-dessus. Ces demandes réduiraient le trafic, ou lèveraient une limite visible par le conducteur.

**Notifications**

- Aucun point d'enregistrement d'un jeton d'appareil (FCM / APNs), du genre `POST /api/moi/appareils` puis `DELETE` à la déconnexion. Sans lui, rien n'est notifié quand l'appli est fermée : l'appli ne peut afficher une notification locale qu'en tournant au premier plan.
- Aucun fil de notifications côté serveur : l'appli déduit les nouveautés (mission ajoutée ou annulée, incident traité, document qui expire, nouvelle alerte) en comparant deux synchronisations. Une notification lue sur un téléphone reste donc non lue sur un autre, et rien n'est détecté pendant que l'appli est fermée. Un `GET /api/moi/notifications` avec un `POST …/lu` remplacerait toute cette mécanique.
- Le WebSocket ne transporte que les messages (§4.9). Y ajouter les événements de mission, d'incident et d'alerte supprimerait l'essentiel de la synchronisation périodique.

**Trafic et pagination**

- Pas de requête conditionnelle (`ETag` / `If-None-Match`, `If-Modified-Since`) ni de paramètre `depuis=` sur `/api/moi`, `/api/moi/missions`, `/api/moi/incidents` et `/api/moi/vehicule` : toutes les 5 minutes, l'appli télécharge à nouveau l'ensemble, même sans changement. Coûteux en données mobiles.
- `GET /api/moi/pleins` et `GET /api/moi/incidents` sont figés aux 50 derniers éléments, sans pagination ni filtre par période : l'historique plus ancien est inaccessible depuis le téléphone.

**Saisies**

- Pas d'en-tête d'idempotence (`Idempotency-Key`) sur les `POST`. Une requête coupée par une perte de réseau ne peut pas être rejouée sans risque de doublon, ce qui empêche une vraie file d'envoi hors ligne. Le contrôle de doublon existe pour le carburant (même véhicule, < 10 min, même quantité à 0,5 L près), mais pas pour les incidents ni les messages.
- Pas de suppression de photo d'incident (`DELETE /api/moi/incidents/photos/{idPhoto}`) : une photo floue ou envoyée par erreur reste attachée au dossier.
- Pas de correction ni d'annulation d'une saisie carburant par le conducteur, même juste après l'enregistrement.
- Pas de détail unitaire (`GET /api/moi/missions/{id}`, `GET /api/moi/incidents/{id}`) : après l'action sur une mission, l'appli doit recharger toute la liste pour rafraîchir l'écran de détail.

**Compte**

- `idUtilisateur` n'est pas renvoyé par `/connexion` ni par `/rafraichir` (§2.1), alors qu'il est nécessaire pour reconnaître ses propres messages ; l'appli le lit dans le JWT, sans vérifier la signature.
- Pas de changement de mot de passe ni de mot de passe oublié depuis l'appli : il faut passer par le responsable du parc.
- Pas de point de version minimale acceptée (par exemple `GET /api/mobile/version`) : impossible d'imposer une mise à jour à un téléphone qui garde une ancienne version.
