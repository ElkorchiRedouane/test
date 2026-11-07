# Milou Ops — Rapport de tests SQL intégrés — 2026-11-07

## Périmètre
Projet Supabase actuel, sans base supplémentaire, avec transaction PostgreSQL test annulée par sous-transaction / exception contrôlée. Aucun paiement externe ni appel Shopify.

## Résultats
- Création fictive (réversible) de 1 consignateur, 1 dépôt et 2 articles : OK
- Préparation POS 2 articles : 100,00 $ consigné à 50 %, 19,99 $ stock propre, total 119,99 $ : OK
- Refus doublons : OK
- Blocage de l'encaissement tant que tax_mode=unconfirmed / cash_live_enabled=false : OK
- Test transactionnel temporaire du chemin comptant avec configuration modifiée uniquement dans la sous-transaction annulée : 120,00 $ reçus, monnaie 0,01 $ : OK
- Refus paiement insuffisant : OK
- Enregistrement atomique 2 ventes et statut stock vendu : OK
- Répartition consigné : 50,00 $ consignateur / 50,00 $ boutique ; stock propre 19,99 $ boutique : OK
- Idempotence deuxième confirmation paiement : OK
- Proposition de versement partiel de 20,00 $ sur solde 50,00 $ ; solde théorique 30,00 $ ; pas de paiement réalisé ni d'altération du statut vente : OK
- Refus versement 60,00 $ : OK
- Annulation de proposition : OK
- Demande retour en attente (ni remboursement ni remise en stock) : OK
- Blocage de nouvelle proposition quand retour en attente : OK

## Contrôle de non-persistance
- Consignateurs / dépôts / articles QA restants : 0
- Ventes QA restantes : 0
- Ventes réelles totales : 0
- Propositions et demandes retour : 0
- Brouillons POS préexistants : 3
- Configuration restaurée : tax_mode=unconfirmed, cash_live_enabled=false.

## Limites
Il s'agit d'un test intégré PostgreSQL utilisant un contexte JWT de test et une transaction annulée. Cela ne constitue pas une validation utilisateur de bout en bout, ni un encaissement opérationnel, et ne couvre pas Square, le scanner physique, l'impression, les remboursements exécutés ni un versement réellement payé. La politique fiscale doit être validée avant l'activation d'une caisse réelle.

## Prochaines vérifications
1. Test fonctionnel complet en navigateur avec données fictives persistantes (en prévenant les synchronisations Shopify et Google Sheet).
2. Tester imprimante, caméra, lecteur HID et reçu.
3. Valider traitement fiscal, comptabilisation de versements et procédure de remboursement.
4. Avant ouverture, sauvegarder et nettoyer les jeux de données fictifs avec cohérence entre Shopify et Milou.
