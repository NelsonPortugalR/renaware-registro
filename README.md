# Registro interno · Equipo Arequipa

Formulario de registro de **ventas** (contado y crédito, autocompra y a
terceros) y **afiliaciones** de Rena Ware, más el panel de administración.
Reemplaza al formulario de papel y al grupo de WhatsApp.

- `public/index.html` — el formulario, estilo chat, una pregunta a la vez
- `public/admin.html` — el panel por período: estados, datos crediticios,
  contrato y ficha en PDF, asesores, analistas, listas de precios
- `public/_headers`, `public/_redirects`, `public/404.html` — configuración
- `wrangler.toml` — dice que el sitio son los archivos de `public/`

## Cómo se publica

El sitio es estático: no hay build ni dependencias. Cloudflare está conectado
a este repositorio, así que **cada push a `main` publica**. No hay que subir
ningún archivo a mano.

La conexión se hace una sola vez, en Cloudflare → Workers &amp; Pages →
`renaware-registro` → Settings → Build → Connect to Git: este repo, rama
`main`, sin comando de build. El `wrangler.toml` se encarga del resto, y el
nombre que lleva es el del Worker que ya existe, así que **el link del equipo
no cambia**.

Si en algún momento se prefiere publicarlo como Pages —como
`renaware-reparaciones`— la configuración es: sin comando de build y
`public` como directorio de salida. El `wrangler.toml` sobra ahí, pero no
estorba. Eso sí, el link sería otro.

## Rutas

| Ruta | Para qué |
|---|---|
| `/` o `/registro` | el formulario, el link que usa el equipo |
| `/panel` o `/admin.html` | el panel de administración |

## De dónde salen los datos

Todo vive en Supabase (proyecto `kiexpdaaoegbtesqmaff`). El sitio no tiene
servidor propio: llama a la base directamente con la clave pública, y lo que
se puede leer o escribir lo deciden las políticas RLS de la base, no el
formulario. Las piezas principales:

- `registros` — una fila por venta o afiliación, con su `detalle` en JSON
- `clientes`, `cliente_direcciones`, `cliente_referencias` — la base única de
  clientes; un registro nuevo engancha solo a su cliente y acumula sus
  direcciones y referencias
- `eq_personas` — los asesores del equipo; un afiliado nuevo entra solo
- `productos`, `v_listas_vigentes` — el catálogo y las listas vigentes
- `factores_credito`, `reglas_credito` — el cálculo de cuotas

## Dos cosas que conviene saber antes de tocar el código

- **El orden de las preguntas es el valor del formulario.** No es un
  formulario abierto a propósito: preguntar de a uno es lo que evita errores.
  Para corregir sin perder el hilo está la pestaña «📋 Ver», no el desorden.
- **Un `node --check` no alcanza.** Varias veces pasó código sintácticamente
  válido que llamaba a una función inexistente y rompía el formulario en
  producción. Hay que abrirlo en un navegador y recorrerlo antes de publicar.
