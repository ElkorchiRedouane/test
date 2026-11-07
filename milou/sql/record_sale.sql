-- À appliquer et valider sur Supabase Friperie Milou Ops AVANT d'utiliser l'écran de scan.
-- À vérifier avec le schéma réel (connexion SQL indisponible lors de la préparation).
-- Une vente est unique par article et le solde est dérivé de public.sales.
CREATE OR REPLACE FUNCTION public.milou_record_sale(p_item_id uuid, p_gross_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_item public.items%ROWTYPE;
  v_deposit public.deposits%ROWTYPE;
  v_consignor public.consignors%ROWTYPE;
  v_pct numeric := 0;
  v_share numeric := 0;
  v_store numeric := 0;
  v_sale_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_milou_user() THEN
    RAISE EXCEPTION 'Compte Milou non autorisé';
  END IF;
  IF p_gross_amount IS NULL OR p_gross_amount < 0 OR p_gross_amount > 100000 THEN
    RAISE EXCEPTION 'Montant de vente invalide';
  END IF;
  SELECT * INTO v_item FROM public.items WHERE id=p_item_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Article introuvable'; END IF;
  IF v_item.status IN ('sold','returned','rejected','archived','deleted_shopify','deleted_milou') THEN
    RAISE EXCEPTION 'Article non vendable ou déjà vendu (%)', v_item.status;
  END IF;
  IF EXISTS (SELECT 1 FROM public.sales WHERE item_id=p_item_id) THEN
    RAISE EXCEPTION 'Vente déjà enregistrée pour cet article';
  END IF;
  IF v_item.deposit_id IS NOT NULL THEN
    SELECT * INTO v_deposit FROM public.deposits WHERE id=v_item.deposit_id;
  END IF;
  IF v_item.consignor_id IS NOT NULL THEN
    SELECT * INTO v_consignor FROM public.consignors WHERE id=v_item.consignor_id;
  END IF;
  IF v_item.consignor_id IS NOT NULL AND v_item.acquisition_mode = 'consignment' THEN
    v_pct := COALESCE(v_item.commission_pct,v_deposit.commission_pct,v_consignor.default_commission_pct);
    IF v_pct IS NULL OR v_pct < 0 OR v_pct > 100 THEN
      RAISE EXCEPTION 'Pourcentage de consignation absent ou invalide';
    END IF;
    v_share := round(p_gross_amount*v_pct/100,2);
  END IF;
  v_store := p_gross_amount-v_share;
  INSERT INTO public.sales(item_id,consignor_id,sold_at,gross_amount,commission_pct,consignor_amount,store_amount,payout_status)
  VALUES(p_item_id,v_item.consignor_id,now(),p_gross_amount,v_pct,v_share,v_store,'pending')
  RETURNING id INTO v_sale_id;
  UPDATE public.items SET status='sold' WHERE id=p_item_id;
  RETURN jsonb_build_object('sale_id',v_sale_id,'sku',v_item.sku,'gross_amount',p_gross_amount,'consignor_amount',v_share,'store_amount',v_store);
END;
$$;
REVOKE ALL ON FUNCTION public.milou_record_sale(uuid,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.milou_record_sale(uuid,numeric) TO authenticated;
-- Recommandé, après vérification des doublons existants :
-- CREATE UNIQUE INDEX IF NOT EXISTS sales_one_per_item ON public.sales(item_id);
