# ImmiFlow AI — MVP consultant immigration IA

ImmiFlow AI est un prototype de copilote pour consultant en immigration. L'objectif n'est pas de remplacer le professionnel autorisé, mais d'automatiser la collecte, l'analyse, la préparation documentaire et le préremplissage avant validation humaine.

## V2 actuelle

Le MVP GitHub Pages contient maintenant :

- assistant conversationnel de démonstration;
- analyse de complétude du profil;
- profil maître réutilisable;
- détection des informations manquantes;
- checklist automatique de documents;
- simulation de lecture/extraction de documents;
- catalogue de formulaires suggérés;
- écran de synchronisation des formulaires officiels;
- mapping profil maître → champs formulaire;
- préremplissage simulé des champs connus;
- blocage des champs non confirmés;
- export d'une fiche de préremplissage JSON;
- liens directs vers les sources officielles IRCC et Québec;
- validation professionnelle explicitement requise.

## Important : ce qui est simulé dans GitHub Pages

GitHub Pages est une application statique. Dans cette V2, le comportement IA est simulé dans le navigateur pour valider l'expérience utilisateur et le workflow métier.

Ne sont pas encore connectés :

- un vrai modèle IA;
- OCR/vision réelle des pièces;
- récupération serveur automatique des derniers PDF IRCC/MIFI;
- remplissage fiable des PDF officiels;
- base de données multi-utilisateurs;
- authentification;
- stockage sécurisé de documents sensibles.

## Architecture cible

1. **Profil maître** : identité, famille, études, emplois, voyages, antécédents et historique d'immigration.
2. **Assistant IA** : interroge le dossier, pose les questions manquantes et prépare l'analyse.
3. **Documents** : extraction, rapprochement avec le profil et détection d'incohérences.
4. **Moteur de formulaires** : identifie les formulaires applicables, vérifie leur source/version officielle et mappe les données du profil.
5. **Validation consultant** : aucune recommandation ou donnée critique n'est finalisée sans validation humaine.

## Prochaine étape technique

Transformer la maquette en vraie application avec un backend sécurisé :

- Supabase pour authentification, base et stockage;
- service IA côté serveur;
- catalogue officiel versionné IRCC/MIFI;
- moteur de mapping des formulaires;
- génération/préremplissage des fichiers;
- journal d'audit;
- rôles consultant / employé / client.

## Données métier à recueillir auprès du consultant

Pour les 5 types de dossiers qu'il traite le plus souvent :

- étapes réelles;
- formulaires officiels utilisés;
- documents requis;
- champs vérifiés manuellement;
- incohérences fréquentes;
- décisions qui nécessitent son jugement professionnel;
- délais et rappels;
- modèles de messages envoyés aux clients.

Ces données permettront de passer d'un prototype générique à un outil réellement utilisable dans son cabinet.