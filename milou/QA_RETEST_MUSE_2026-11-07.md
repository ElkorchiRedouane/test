# Milou Ops — Retest Muse après QA du 7 novembre 2026

Branche `feature/milou-scan-ventes`. URL de preview corrigée : https://milou-2hgc7oslk-elkorchiredouane.vercel.app

## Cas prioritaires
- MILOU-QA-001 : ajouter 3 articles dans le panier, appuyer sur « Vider le panier », vérifier total 0,00 $ et compteur 0, sans dialogue de confirmation bloquant. Réessayer après un doublon.
- MILOU-QA-006 : provoquer un doublon et un message « article déjà présent », enlever le dernier article puis vérifier la disparition du message et une monnaie de « — »; tester ensuite « Vider le panier ».
- MILOU-QA-003 : Accueil → Dépôts → bouton Retour du navigateur. L'application doit revenir sur Accueil, sans naviguer vers GitHub.
- MILOU-QA-008 : recharger avec session active. Un écran de chargement doit s'afficher jusqu'à la validation de session; pas de formulaire de connexion fugace ni de données obsolètes.
- MILOU-QA-002 : après chargement, les comptes 6 dépôts et les noms réels de Supabase doivent être cohérents. Les noms fictifs « Cheyenne Laurendeau », « Sarah Samson », « Bianca Chakkal » ne figurent ni dans le code de la branche ni dans les consignateurs / titres Supabase. Si réapparition, enregistrer l'URL exacte, l'heure, le DOM/capture et l'état du service worker avant de conclure à l'origine.
- MILOU-QA-004 : vérifier la nouvelle légende « À envoyer Shopify = articles » et les statuts du dépôt. Règle métier : un article en brouillon Shopify reste disponible pour la vente locale lorsque son état Milou autorise la vente; ne pas assimiler « brouillon Shopify » à « non vendable en boutique ».
- MILOU-QA-005 : vérifier l'affichage « taux par défaut non défini » sur le consignateur et la commission au dépôt, sans déduire le taux du dépôt à partir du taux par défaut du client.
- MILOU-QA-007 : tous les consignateurs actifs s'affichent dans le sélecteur; en l'absence de ventes réelles, leur montant demeure zéro et la création d'un versement est refusée proprement.
- MILOU-QA-009 : compteur d'emplacements explicitement réservé aux articles actifs; comparer à la liste en excluant supprimés/archivés.
- MILOU-QA-010 : les dépôts 000001 et 000002 contenant des articles doivent apparaître dans le sélecteur, même avec zéro étiquette imprimable; un bouton « Aperçu code-barres » doit afficher un Code128 sans impression.
- MILOU-QA-011 : bouton « Détails » de chaque ligne de stock ouvre une fiche article en lecture seule. Ne pas inventer le titre manquant.
- MILOU-QA-012 : tester le calculateur de monnaie fictif 19,99 $ reçus 20,00 $ → 0,01 $, sans écriture en base.

## Contraintes
Aucune vente, paiement ou remboursement réel. Ne pas modifier le contenu existant. Ne pas déployer en production. Documenter Réussi/Échoué/Bloqué, avec captures et URL exacte.

## Restant ouvert
- MILOU-QA-000 : Vercel SSO impose une connexion sur les URL de preview; ne pas retirer la protection sans stratégie d'accès commerciale.
- MILOU-QA-002 : source originale de l'aperçu avec noms étrangers non identifiée; masque initial ajouté, mais cause non prouvée.
- Tests imprimante, caméra physique, Square, taxes, versements réels : non réalisés.
