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

## Lo que el formulario ya no pregunta

Cuando el comprador se elige del desplegable, en vez de escribirlo, el
formulario trae lo que la base ya sabe y se salta esas preguntas:

| Se elige | Se trae | De dónde |
|---|---|---|
| un **cliente** de ventas anteriores | DNI, y las opciones de celular, correo, dirección, referencias, trabajo y RUC | `buscar_clientes` + `opciones_cliente` |
| un **asesor** | DNI, y su celular, correo y RUC como opción | `datos_asesor` + `opciones_cliente` |

Las dos listas salen juntas en la misma pregunta y en cualquier tipo de venta:
un asesor del equipo también compra, y no siempre para sí mismo. La misma
persona aparece **una sola vez** (`mismaPersona()`, dos palabras largas
compartidas, igual que `mismo_nombre()` en la base): si el asesor ya compró, su
fila trae el código y el historial juntos. El código del asesor solo se toma
como propio en la **autocompra**; en una venta a terceros ese campo es de quien
vende.

`datos_asesor` trae la ficha de a uno, cuando la eligen: la lista del
desplegable sigue siendo solo código y nombre, así ningún navegador se lleva
512 DNI de golpe.

Si la ficha del asesor **no** tiene DNI, se pregunta como siempre y el que se
escriba queda guardado en su ficha (`completa_dni_asesor`). Nunca pisa un DNI
ya cargado y exige que el nombre calce, para que un código mal elegido no
escriba sobre otra persona. Es lo que mantiene la base al día sin que nadie la
llene a mano; el panel de asesores tiene el filtro «Sin RUC / Sin DNI» para ver
cuánto falta.

**Los documentos también se reusan.** Un recibo de servicios o un sustento de
ingreso que ya subió en otra compra sigue en el bucket, así que se ofrece con
su fecha y viaja con el registro nuevo **por su ruta, sin volver a subirlo**: el
mismo archivo queda referenciado por los dos registros. Las **constancias de
pago quedan fuera a propósito** —`opciones_cliente` ni las devuelve—: un
voucher sustenta un solo pago y reusarlo sería declarar dos veces el mismo
dinero. Del recibo se dice de cuándo es, y se marca si pasa de tres meses, que
es el límite de Rena Ware; decidir es del asesor, no del sistema.

Si el documento se escribe a mano en vez de elegirlo del desplegable, el
formulario igual reconoce a quien ya está en la base (`buscar_cliente`,
afiliaciones incluidas) y ofrece usar sus datos. Al aceptar **no se salta hasta
el pedido**: sigue el orden normal y cada pregunta ofrece su dato para
confirmarlo de un toque o cambiarlo.

Un afiliado nuevo queda disponible en los tres lados el mismo día: en
`clientes` y en el buscador de clientes (lo hace `engancha_cliente`, que corre
para todo registro), y en la base de asesores con su ficha llena
(`alta_asesor_desde_afiliacion`). Si la persona ya existía, esa función
**completa los campos en blanco** y no pisa ninguno cargado; el candado contra
duplicados mira nombre, código y DNI, porque «Helen Coska» y «HELEN KOSKA» son
la misma señora.

## El panel desde el celular

El panel se usa tanto desde el teléfono como desde la laptop, así que las dos
listas largas tienen dos formatos: **tabla** en pantalla ancha y **tarjetas**
por debajo de 640 px (`pantallaChica()`). Los registros usan `filaTarjeta()` y
los asesores `asFicha()`; en los dos casos los campos conservan las mismas
marcas (`data-id`, y `.as-f` con `data-c` en asesores), así que abrir la ficha,
avanzar el estado, guardar y el aviso de «cambios sin guardar» funcionan igual
en los dos formatos. Al cruzar el umbral se repinta una sola vez —no en cada
píxel—, para no borrar el campo que se está escribiendo.

En el celular, además: la barra superior y los filtros dejan de estar fijos y
se van con el scroll; los filtros van en una tira que se desliza de lado; la
banda del período se compacta (la tira de 14 cuadritos no se muestra: la misma
información va escrita al lado); y todo campo escribible llega a 16 px, que es
lo que evita que iOS haga zoom al enfocarlo.

## Lo que no está aquí

La **bienvenida por WhatsApp** vive en su propio módulo
(`renaware-bienvenida.pages.dev`), con los 5 días de mensajes, los archivos de
cada día y el seguimiento de Nivel Cero y de clientes. El panel tenía una
versión vieja —un solo mensaje, tablas `wa_secuencias` y `wa_mensajes`— que se
quitó; las tablas siguen en la base, sin uso. En la ficha de un afiliado queda
el enlace al módulo.

## Dos cosas que conviene saber antes de tocar el código

- **El orden de las preguntas es el valor del formulario.** No es un
  formulario abierto a propósito: preguntar de a uno es lo que evita errores.
  Para corregir sin perder el hilo está la pestaña «📋 Ver», no el desorden.
- **Un `node --check` no alcanza.** Varias veces pasó código sintácticamente
  válido que llamaba a una función inexistente y rompía el formulario en
  producción. Hay que abrirlo en un navegador y recorrerlo antes de publicar.
- **El formulario entra como `anon`.** Toda función que llame necesita
  `grant execute … to anon`, y un `drop`+`create` para cambiarle la firma se
  lleva el permiso por delante. Cuando pase, no hay error visible: `rpc()`
  traga el 403 y el desplegable sale vacío, como si no hubiera nadie. Así
  estuvo `buscar_clientes`. Para comprobarlo de una:

  ```sql
  select p.proname, has_function_privilege('anon', p.oid, 'execute')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('buscar_clientes','buscar_cliente','opciones_cliente',
                      'listar_asesores','datos_asesor','completa_dni_asesor',
                      'buscar_asesor','crear_registro','zc_claves_inei');
  ```
