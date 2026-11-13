-- 13/11/2026 · «En la web» por lista de precios
--
-- Una lista de especiales puede seguir vigente (se vende, sale en el formulario y en el
-- portal de precios) y no mostrarse en la web pública (ollasarequipa.com). Lo pidió Nelson:
-- Rena Ware deja pasar pedidos de una lista unos días después de su cierre, pero en la web
-- quiere mostrar solo la lista nueva.
--
-- El interruptor está en el panel → Listas de precios → «En la web». El generador de la
-- web (repo equipo-arequipa-web, build.py) lee esta columna con la clave pública y no
-- publica los especiales de las listas apagadas. La Lista General, la Tienda en Línea y
-- los Repuestos salen siempre: no llevan interruptor.
--
-- Columna nueva con valor por defecto: nada de lo que ya existía cambia.

alter table public.listas_precios add column if not exists web boolean not null default true;

comment on column public.listas_precios.web is
  'Si los especiales de esta lista salen en la web pública (ollasarequipa.com). No afecta al registro de ventas ni al portal de precios.';

-- Estado al 13/11/2026: «Especiales para Compartir» sigue vigente hasta el 18/11 para vender,
-- pero ya no se muestra en la web (solo Navidad Mágica).
update public.listas_precios set web = false where id = 'compartir';
