-- El regalo o complemento que trae un especial (productos.regalo) vivía solo en
-- el catálogo: no se veía al vender y no llegaba al contrato. Se guarda con la
-- venta porque el catálogo cambia de campaña y el contrato debe decir lo que se
-- prometió ese día.
alter table registro_items add column if not exists regalo text;

comment on column registro_items.regalo is
  'El regalo o complemento que traía el especial cuando se vendió (productos.regalo). Se guarda con la venta porque el catálogo cambia de campaña y el contrato debe decir lo que se prometió.';

-- crear_registro() pasa a guardarlo. Es create or replace con la misma firma,
-- así que conserva el grant a anon (un drop+create se lo llevaría por delante).
-- La definición completa y vigente está en la base; aquí queda el cambio:
--   insert into registro_items (..., regalo)
--   values (..., nullif(left(coalesce(it->>'regalo',''),300),''));
