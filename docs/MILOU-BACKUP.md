# Sauvegarde gratuite de Milou Ops

Le workflow `.github/workflows/milou-nightly-backup.yml` est planifié à **00:00 America/Toronto** (GitHub Actions). Il doit être exécuté une première fois manuellement après configuration.

## Ce qui est inclus

- Un dump PostgreSQL personnalisé (`database.dump`) contenant les schémas accessibles au rôle de connexion.
- Tous les fichiers Supabase Storage (actuellement photos et autres objets).
- Un manifeste des fichiers avec taille et SHA-256.
- Une archive TAR/GZIP chiffrée symétriquement avec **GPG AES-256**.
- Une copie datée dans `miloudrive:MilouBackups/daily/`.
- Une copie remplaçable `miloudrive:MilouBackups/latest/milou-backup-latest.tar.gz.gpg`, actualisée **uniquement après** la réussite du transfert daté.
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
3. Lancer `rclone config`, choisir **n** (nouveau remote), nommer exactement `miloudrive`, type `drive`, autoriser ton compte Google dans le navigateur. Choisir ton Drive personnel, pas un Drive partagé.
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

Vérifier les sommes SHA-256 du manifeste. Tester la restauration dans **une base PostgreSQL de test distincte**, jamais directement sur la production.

Les photos sont dans `storage/<nom_bucket>/`. Pour restaurer sur Supabase Storage, réimporter les objets via l'API de Storage ou un outil dédié après avoir restauré la base.

Les sauvegardes peuvent contenir des informations personnelles sur des consignateurs et des secrets applicatifs présents en base. Les conserver privées.

## 4. Contrôle quotidien

- Une exécution GitHub Actions peut être retardée sous charge : la planification `00:00` n'est pas une garantie à la minute.
- Les sauvegardes anciennes sont purgées seulement après que l'archive du jour et `latest` sont validées.
- Si un job échoue, **l'ancienne archive n'est pas écrasée**. Surveiller les échecs dans GitHub Actions.
- Les imports photos et la structure des tables peuvent évoluer ; refaire un test de restauration après une modification majeure.
- Google Sheets reste un registre opérationnel séparé, synchronisé à 00:15 dans Supabase.
