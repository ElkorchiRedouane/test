# Sauvegarde gratuite de Milou Ops

Le workflow `.github/workflows/milou-nightly-backup.yml` est planifié à **00:00 America/Toronto** (GitHub Actions). Il doit être exécuté une première fois manuellement après configuration.

## Ce qui est inclus

- Un dump PostgreSQL personnalisé (`database.dump`) contenant les schémas accessibles au rôle de connexion.
- Tous les fichiers Supabase Storage (actuellement photos et autres objets).
- Un manifeste des fichiers avec taille et SHA-256.
- Une archive TAR/GZIP chiffrée symétriquement avec **GPG AES-256**.
- Le dossier Drive cible est fixé par son identifiant dans le workflow via `RCLONE_CONFIG_MILOUDRIVE_ROOT_FOLDER_ID`; les chemins du remote partent directement de MilouBackups.
- Une copie datée dans `miloudrive:daily/`.
- Une copie remplaçable `miloudrive:latest/milou-backup-latest.tar.gz.gpg`, actualisée **uniquement après** la réussite du transfert daté.
- Conservation des archives datées des 8 derniers jours.

**Important :** aucune sauvegarde non chiffrée n'est téléversée dans les artefacts GitHub. Ne jamais y placer des données en clair.

## 1. Configurer GitHub Secrets

Dans le dépôt : **Settings > Secrets and variables > Actions > New repository secret**.

Créer les quatre secrets (ne jamais en envoyer les valeurs dans un chat) :

| Nom exact | Description |
|---|---|
| `MILOU_DATABASE_URL` | URI PostgreSQL de **Friperie Milou Ops** avec le rôle `postgres` ; récupérer dans Supabase > Connect. Le mot de passe est requis et doit rester confidentiel. Utiliser l'URL URI complète, avec les caractères spéciaux du mot de passe encodés. |
| `MILOU_SERVICE_ROLE_KEY` | Clé secrète Supabase du même projet (Settings > API keys) ; accès aux fichiers Storage. |
| `MILOU_BACKUP_PASSPHRASE` | Phrase aléatoire **d'au moins 24 caractères**. Conserver aussi une copie hors ligne dans un gestionnaire de mots de passe : sans elle, les sauvegardes chiffrées sont irrécupérables. |
| `MILOU_RCLONE_CONFIG_B64` | Contenu `rclone.conf` encodé en Base64, avec une connexion OAuth Google Drive nommée **miloudrive**. |

### Configurer rclone sur ton ordinateur personnel

1. Installer `rclone` depuis https://rclone.org/downloads/ .
2. Pour Google Drive, créer idéalement des identifiants OAuth personnels Google Cloud, comme indiqué dans https://rclone.org/drive/#making-your-own-client-id (le client partagé rclone doit être évité).
3. Dans ce remote, fixer `root_folder_id` au dossier MilouBackups fourni. Le workflow force également ce dossier par variable d'environnement. Ne pas ajouter un second niveau MilouBackups au chemin.
4. Lancer `rclone config`, choisir **n** (nouveau remote), nommer exactement `miloudrive`, type `drive`, autoriser ton compte Google dans le navigateur. Choisir ton Drive personnel, pas un Drive partagé.
4. Tester `rclone lsd miloudrive:` ; les dossiers de ton Google Drive doivent être listés.
5. Trouver le chemin du fichier local de configuration avec `rclone config file`.
6. Encoder **l'ensemble du fichier** au format Base64 et enregistrer la chaîne dans le secret GitHub `MILOU_RCLONE_CONFIG_B64`. Par exemple, dans PowerShell sous Windows :

```powershell
$path = "C:\Users\TON_UTILISATEUR\AppData\Roaming\rclone\rclone.conf"
[Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) | Set-Clipboard
```

Ne pas laisser de copie de la configuration ou du jeton OAuth dans le dépôt GitHub. Le secret GitHub est le seul lieu d'injection du fichier sur le runner temporaire.

## 2. Première sauvegarde manuelle

Dans GitHub, **Actions > Milou — sauvegarde chiffrée de nuit > Run workflow**, sur la branche `main`.

Vérifier l'état **success** de toutes les étapes et ouvrir le dossier **MilouBackups** dans Google Drive. Contrôler la présence de l'archive datée et du fichier `latest`.

**Ne considérer la sauvegarde comme opérationnelle qu'après un test réel de restauration.**

## 3. Comment vérifier une archive et restaurer

Télécharger une archive `.tar.gz.gpg` depuis Google Drive vers un ordinateur sécurisé.

```bash
gpg --decrypt --output milou-backup.tar.gz milou-backup-latest.tar.gz.gpg
tar -tzf milou-backup.tar.gz | head
tar -xzf milou-backup.tar.gz -C dossier-temporaire
pg_restore --list dossier-temporaire/database.dump
```

Exécuter `python3 scripts/milou_verify_backup.py milou-backup.tar.gz` pour vérifier la couverture complète du manifeste, les tailles et les SHA-256 sans extraire les fichiers. Le workflow effectue aussi ce contrôle sur une copie retéléchargée depuis Drive et compare les empreintes chiffrées de daily et latest. Tester la restauration dans **une base PostgreSQL de test distincte**, jamais directement sur la production.

Les photos sont dans `storage/<nom_bucket>/`. Pour restaurer sur Supabase Storage, réimporter les objets via l'API de Storage ou un outil dédié après avoir restauré la base.

Les sauvegardes peuvent contenir des informations personnelles sur des consignateurs et des secrets applicatifs présents en base. Les conserver privées.

## 4. Contrôle quotidien

- Une exécution GitHub Actions peut être retardée sous charge : la planification `00:00` n'est pas une garantie à la minute.
- Les sauvegardes anciennes sont purgées seulement après que l'archive du jour et `latest` sont validées.
- Si un job échoue, **l'ancienne archive n'est pas écrasée**. Surveiller les échecs dans GitHub Actions.
- Les imports photos et la structure des tables peuvent évoluer ; refaire un test de restauration après une modification majeure.
- Google Sheets reste un registre opérationnel séparé, synchronisé à 00:15 dans Supabase.

## État de validation — 16 novembre 2026

La configuration reste **non opérationnelle tant que les secrets manquants et la restauration réelle ne sont pas validés**.

- Le projet Supabase a été vérifié actif sur PostgreSQL 17.
- Le dossier Drive et ses sous-dossiers daily/latest ont été vérifiés privés et vides avant le premier essai.
- MILOU_SERVICE_ROLE_KEY a été ajouté dans les secrets GitHub Actions par l'interface sécurisée. MILOU_DATABASE_URL est aussi présent, mais le test du 16 novembre à 10h40 refuse l'authentification PostgreSQL.
- Le ciblage Drive par identifiant et la vérification du téléchargement par SHA-256, déchiffrement et manifeste ont été ajoutés. Les diagnostics PostgreSQL et Storage potentiellement privés sont gardés dans les fichiers temporaires du runner, jamais publiés comme artefacts.
- Les cinq tests synthétiques du vérificateur passent (archive valide, corruption de même taille, fichier manquant, ajout hors manifeste, chemin dangereux); la syntaxe du script Bash a été vérifiée. Ces tests ne constituent pas un test réel de sauvegarde ou restauration.
- Le mot de passe PostgreSQL existant doit être saisi uniquement dans l'URI du secret GitHub; ne pas le réinitialiser sans vérifier les dépendances existantes. Utiliser le Session pooler sur le port 5432 si le runner ne dispose pas d'IPv6.
- L'autorisation OAuth Google Drive dédiée et la conservation indépendante de la phrase de déchiffrement restent à terminer. Ne pas considérer le connecteur Drive comme une autorisation rclone exportable.
- Le moteur Docker local était inaccessible lors du contrôle. Aucun essai de restauration n'a encore eu lieu.

### Limites de reprise à traiter

Un dump brut Supabase inclut des références aux rôles et extensions de la plateforme. PostgreSQL standard seul n'est pas nécessairement une cible compatible. Préparer une instance Supabase isolée et compatible avec PostgreSQL 17, pg_cron, pg_net et supabase_vault, puis restaurer et vérifier les objets réellement utiles. Ne pas lancer de restauration dans le projet de production.

Les clés API, paramètres Auth, fonctions Edge, secrets externes et configuration de chiffrement Vault ne sont pas tous reconstitués par ce dump. Documenter leur reprise dans un emplacement privé et vérifier que les secrets Vault restent utilisables dans la cible d'essai sans exposer leurs valeurs. Les fichiers Storage doivent également être réimportés et relus dans une cible séparée.

Preuves finales à consigner ici uniquement sous forme non sensible : URL d'exécution Actions réussie, date/heure, présence et taille des archives, égalité des empreintes, résultat du manifeste, résultat de restauration et première exécution planifiée observée. Ne jamais publier de dump, jeton, phrase secrète, requête contenant des données privées ou ligne de consignateur.

### Contrôle d'accès du 16 novembre, 10h40 (America/Toronto)

Le workflow manuel `milou-backup-access-check.yml` teste PostgreSQL avec `SELECT 1` et l'accès à la liste des buckets Storage sans publier le résultat ni les diagnostics privés.

- [Exécution de contrôle](https://github.com/ElkorchiRedouane/test/actions/runs/43898894862) : accès Storage réussi; authentification PostgreSQL refusée. Ce résultat n'est pas une sauvegarde réussie.
- Le propriétaire indique ne plus connaître le mot de passe PostgreSQL. La réinitialisation doit être effectuée par lui dans l'interface Supabase; les connexions PostgreSQL directes existantes nécessiteront ensuite la mise à jour de leurs identifiants. Aucun changement du mot de passe n'a été effectué par l'agent.
- Le propriétaire a explicitement autorisé la création d'un projet Google Cloud dédié sans facturation. Le projet « Milou Backups » a été créé (identifiant `inspired-parsec-514915-h4`). Aucun service payant n'a été activé dans cette session. L'API Drive, le client OAuth et le jeton rclone restent à configurer.
- La phrase de chiffrement reste à enregistrer dans GitHub et dans un gestionnaire de mots de passe indépendant. Sans copie indépendante, elle ne sera pas récupérable depuis le secret GitHub.

### Avancement complémentaire — 16 novembre, 10h56 (America/Toronto)

- L'API Google Drive est activée dans le projet dédié. L'application OAuth Milou Backups et son client de bureau « Milou Backups rclone » sont créés. Le propriétaire a explicitement approuvé l'acceptation du règlement Google relatif aux données utilisateur. Le client est encore en mode test; le jeton rclone n'est pas obtenu et la durée de validité de son autorisation reste à traiter avant de déclarer la planification durable.
- Le propriétaire a retrouvé un mot de passe et l'a saisi directement dans le formulaire GitHub. L'URI a été reconstruite en mémoire avec encodage des caractères spéciaux et SSL requis, puis enregistrée dans MILOU_DATABASE_URL. [Le contrôle suivant](https://github.com/ElkorchiRedouane/test/actions/runs/43901754700) refuse toujours l'authentification PostgreSQL; l'accès Storage réussit. Aucun mot de passe n'a été réinitialisé.
- Le téléchargement automatisé du JSON OAuth n'a pas abouti. Le propriétaire doit sauvegarder ce fichier localement; ne pas le publier dans le dépôt ni dans le chat. Le secret ne sera plus affichable après fermeture de la fenêtre Google.
- Les secrets MILOU_BACKUP_PASSPHRASE et MILOU_RCLONE_CONFIG_B64 sont toujours absents lors du dernier contrôle. Aucune archive réelle n'a été créée et aucun test de restauration réel n'a été effectué.
- Le démarrage de Docker Desktop a été demandé, mais l'accès au moteur n'a pas été confirmé. La restauration locale demeure non validée.
