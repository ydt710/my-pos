-- Grant execute permissions for stock management functions

GRANT EXECUTE ON FUNCTION public.confirm_production_done(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_stock_transfer(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_stock_transfer(uuid, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_transfers_count() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_shop_transfers_count() TO authenticated; 