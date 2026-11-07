-- Migration applied to Friperie Milou Ops on 2026-11-06.
CREATE OR REPLACE FUNCTION public.milou_record_sale(p_item_id uuid, p_gross_amount numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_item public.items%ROWTYPE;
  v_mode text;
  v_pct numeric;
  v_owner uuid;
  v_sale public.sales%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_milou_user() THEN
    RAISE EXCEPTION 'Compte Milou non autorisé';
  END IF;
  IF p_gross_amount IS NULL OR p_gross_amount < 0 OR p_gross_amount > 100000
     OR round(p_gross_amount, 2) <> p_gross_amount THEN
    RAISE EXCEPTION 'Prix de vente invalide';
  END IF;
  SELECT * INTO v_item FROM public.items WHERE id = p_item_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Article introuvable'; END IF;
  IF v_item.status NOT IN ('validated','shopify_draft','online') OR v_item.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Article non vendable (statut %)', v_item.status;
  END IF;
  IF EXISTS (SELECT 1 FROM public.sales WHERE item_id = p_item_id) THEN
    RAISE EXCEPTION 'Cet article a déjà une vente enregistrée';
  END IF;
  SELECT COALESCE(v_item.acquisition_mode,d.acquisition_mode,'own_stock'),
         COALESCE(v_item.consignor_id,d.consignor_id),
         COALESCE(v_item.commission_pct,d.commission_pct,c.default_commission_pct)
    INTO v_mode,v_owner,v_pct
  FROM (SELECT 1) x
  LEFT JOIN public.deposits d ON d.id = v_item.deposit_id
  LEFT JOIN public.consignors c ON c.id = COALESCE(v_item.consignor_id,d.consignor_id);
  IF v_mode = 'consignment' THEN
    IF v_owner IS NULL THEN RAISE EXCEPTION 'Consignateur manquant'; END IF;
    IF v_pct IS NULL OR v_pct < 0 OR v_pct > 100 THEN
      RAISE EXCEPTION 'Pourcentage de consignation manquant ou invalide';
    END IF;
  ELSE
    v_owner := NULL;
    v_pct := 0;
  END IF;
  INSERT INTO public.sales(item_id,consignor_id,sold_at,gross_amount,commission_pct,payout_status)
  VALUES (p_item_id,v_owner,now(),p_gross_amount,v_pct,
     CASE WHEN v_owner IS NULL THEN 'not_applicable' ELSE 'unpaid' END)
  RETURNING * INTO v_sale;
  -- The existing sales triggers calculate the split and mark the item sold.
  RETURN jsonb_build_object(
    'sale_id',v_sale.id,'sku',v_item.sku,
    'gross_amount',v_sale.gross_amount,
    'consignor_amount',v_sale.consignor_amount,
    'store_amount',v_sale.store_amount);
END;
$function$
;
REVOKE ALL ON FUNCTION public.milou_record_sale(uuid,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.milou_record_sale(uuid,numeric) TO authenticated;
