# Milou × Square Terminal — intégration caisse

## Architecture décidée
- Milou Ops : source de vérité pour articles, consignateurs, prix, rabais et ventes.
- Square Terminal : collecte des paiements par carte, sans données de carte transitant par Milou.
- Supabase : transactions de caisse, statuts de paiement, audit et solde consignateur.

## Condition matérielle
L'API Terminal concerne un **Square Terminal appairé** (device_id).
Ne pas supposer qu'un Square Reader ou l'application Square POS supporte cette API.

## Flux de paiement
1. Scan des SKU → panier unique, validé côté serveur.
2. Verrouillage des articles et création d'une caisse transaction `pending` avec snapshot immuable des lignes, rabais, taxes et commission.
3. Appel POST Square /v2/terminals/checkouts avec clé d'idempotence stable, montant en cents CAD, et référence interne.
4. Stocker le checkout_id, ne PAS considérer la transaction payée.
5. Réception webhook terminal.checkout.updated (signature vérifiée), plus lecture GET checkout en récupération après interruptions.
6. Récupération via Payments API de tous les payment_ids, vérification status COMPLETED, devise CAD, location_id et total encaissé.
7. Transaction SQL atomique : verrouillage des lignes, contrôle absence de vente, création de sales par article, référence paiement Square unique, statut sold; le trigger existant calcule la part consignateur.
8. Échec/annulation/paiement incomplet : aucune vente; maintenir panier pour reprise.
9. En cas d'erreur SQL après paiement : mettre transaction `paid_needs_reconciliation` et bloquer toute nouvelle tentative de débit; reprise manuelle/automatisée d'abord.

## Règles non négociables
- Ne jamais faire confiance aux prix ou au total envoyés par le navigateur.
- Pas de secret Square dans HTML/JS client, GitHub ou logs.
- Éviter double paiement avec Square idempotency_key stable; double vente avec contrainte unique sales.item_id déjà existante.
- Décompter les commissions **sur les prix nets par article hors taxes**; les taxes et rabais doivent être traités explicitement et testés (TPS/TVQ selon la situation fiscale).
- Ne pas mettre à jour directement un 'solde' : montant dû = ventes unpaid moins versements et avoirs.
- Encaissement comptant séparé avec journal de caisse, employé et montant reçu/rendu.
- Retour/remboursement : flux dédié cohérent Square + inventaire + consignateur.
- Test sandbox avec valeurs Square fictives; matériel réel impossible en sandbox.

## Configuration nécessaire (non fournie actuellement)
1. Compte marchand Square Canada.
2. Application dans https://developer.squareup.com/apps et accès Sandbox.
3. Square Terminal (physique) appairé pour la production, Square location_id et device_id.
4. Secrets configurés dans Supabase Edge Function : SQUARE_ACCESS_TOKEN, SQUARE_LOCATION_ID, SQUARE_DEVICE_ID, SQUARE_ENV, SQUARE_WEBHOOK_SIGNATURE_KEY.
5. URL webhook publique et permission PAYMENTS_READ / PAYMENTS_WRITE.
6. Politique de taxes de la boutique et définition commerciale des rabais/retours.

## Livraison par étapes
- A : panier multiarticles et impression étiquettes.
- B : modèle de transaction persistée, Edge Functions et simulation Square Sandbox, tests d'idempotence.
- C : appairage terminal, paiement réel contrôlé de faible montant, remboursement et rapprochement.
- D : passage en production surveillé.

## Documentation Square
- https://developer.squareup.com/docs/terminal-api/quickstart
- https://developer.squareup.com/docs/terminal-api/square-terminal-payments
- https://developer.squareup.com/reference/square/terminal-api/create-terminal-checkout
