# ImmiFlow — MVP consultant en immigration

Prototype fonctionnel pour valider le workflow d'un cabinet de consultant en immigration.

## V0 actuelle

- tableau de bord des dossiers;
- gestion des clients et dossiers;
- pipeline Collecte → Révision → Prêt → Soumis;
- profil maître simplifié;
- checklist des documents;
- suivi des formulaires;
- progression automatique du dossier;
- création de nouveaux clients;
- sauvegarde locale via `localStorage`;
- interface responsive.

## Lancer le MVP

Ouvrir `index.html` dans un navigateur moderne.

## Important

Cette version est uniquement une maquette fonctionnelle. Elle ne doit pas contenir de vraies données clients sensibles.

Avant une utilisation réelle, ajouter au minimum : authentification, rôles, base de données sécurisée, stockage documentaire sécurisé, contrôle d'accès, journalisation, politique de conservation/suppression, sauvegardes et validation humaine avant toute utilisation de données produites ou extraites par IA.

## Étape suivante

Brancher Supabase et transformer le prototype en application multi-utilisateurs avec :

- comptes consultant / employé / client;
- profil maître complet;
- téléversement de documents;
- moteur de documents requis par type de dossier;
- mapping profil → formulaires;
- détection d'incohérences;
- rappels et échéances;
- assistant IA sous validation du consultant.

## Informations métier à recueillir

Pour les 5 types de dossiers les plus fréquents du cabinet, documenter : étapes, formulaires, documents requis, données nécessaires, contrôles, délais, modèles de courriel et tâches répétitives.