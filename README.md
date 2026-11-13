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

## Varios registros a la vez, uno por pestaña

El equipo llena varias ventas o afiliaciones en paralelo, en pestañas del mismo
navegador. La pieza que lo hace posible es que **los borradores viven en
`localStorage`, que todas las pestañas comparten, pero cuál está llenando cada
pestaña vive en `sessionStorage`, que es de cada una y aguanta la recarga**. De
ahí sale todo el comportamiento:

- **Recargar o volver a una pestaña retoma SU registro**, sin menú: «Seguimos
  con …».
- **Una pestaña nueva pregunta una sola cosa**: «¿Cuál abres en esta pestaña?»,
  con la lista y «➕ Empezar uno nuevo aquí».
- **Dos pestañas no se pisan**, porque cada una sabe cuál es el suyo.

Cada pestaña **firma** su borrador (`pestana` + `visto`, refrescado cada 15 s).
Un borrador firmado por otra pestaña hace menos de 45 s sale marcado «abierto
en otra pestaña», y abrirlo igual pide confirmación: dos pestañas en el mismo
registro terminan pisándose. Esa misma firma protege el borrador vivo de otra
pestaña cuando el almacenamiento se llena y hay que soltar borradores viejos.
Un `storage` listener mantiene al día el contador del botón «⇄».

**Lo que se quitó del menú, a propósito**: «guardar este» (todo se guarda solo,
decirlo confunde) y «descartar los aparcados» (borraba en bloque, y con varias
pestañas eso se llevaba por delante el trabajo de otra sin que se notara).
Borrar quedó de a uno, con confirmación, detrás de «🗑️ Borrar alguno de la
lista». Y «➕ Hacer otro registro», al terminar uno, recarga con una marca
(`rw_otro_en_blanco`) para arrancar en blanco en vez de ofrecer la lista.

## Lo que el formulario ya no pregunta

Cuando el comprador se elige del desplegable, en vez de escribirlo, el
formulario trae lo que la base ya sabe y se salta esas preguntas:

| Se elige | Se trae | De dónde |
|---|---|---|
| un **cliente** de ventas anteriores | DNI, y las opciones de celular, correo, dirección, referencias, trabajo y RUC | `buscar_clientes` + `opciones_cliente` |
| un **asesor** | DNI, y su celular, correo y RUC como opción | `datos_asesor` + `opciones_cliente` |

**La dirección laboral del contrato es la misma que va al portal**: la de
trabajo, o la de la casa si no hay. En pensión mandaba la de la institución (la
UGEL, por ejemplo) y en «Alquila propiedades» la de la propiedad alquilada, así
que el contrato y el portal decían cosas distintas de la misma venta. Las dos
siguen guardadas en su campo; si se las quiere en los dos sitios, se escriben en
«dirección de trabajo», que es la que alimenta a ambos (`_laboral()`).

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

**También cuenta lo que compró por fuera.** Mucha gente compró antes sin pasar
por este formulario: esas órdenes viven en `crm_pedidos`, con la dirección a la
que Rena Ware entregó. `opciones_cliente` las engancha por la ficha de cliente
(`clientes.doc_clave`) y ofrece esa dirección, el celular y el correo como una
opción más, marcada «de su pedido del …». La ciudad viene como texto —«Majes,
Caylloma»— y el ubigeo lo resuelve el formulario con `resuelveCiudad()` contra
la lista de distritos del país, la misma del desplegable; si no calza, la
dirección se usa igual pero se sigue preguntando el distrito, porque de él
depende la zona de crédito. `buscar_cliente` también los reconoce, así que
escribir el DNI a mano encuentra a quien solo tiene pedidos.

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

**La fecha de nacimiento se pide al afiliar**, que es cuando está a la vista en
el sistema de Rena Ware, justo después del documento. Es **opcional** —de la
mayoría todavía no se sabe y nadie debería trabarse ahí—, se escribe como viene
(`24081985`, o con barras) y queda guardada en `eq_personas.nacimiento`, que es
la columna que el panel de asesores ya mostraba vacía. El camino es el
disparador `alta_asesor_desde_afiliacion`, que lee `detalle->>'nacimiento'`
**como fecha**: por eso el formulario la manda en ISO (`nacimientoISO()`) aunque
la muestre en DD/MM/AAAA. Si el formato no calza, el disparador la deja en
blanco sin avisar. En el panel de asesores se edita a mano y el filtro «Sin
fecha de nacimiento» muestra a quiénes les falta.

**Todo campo nuevo de `datos` va declarado en el molde inicial.** `DATOS_VACIOS`
es una copia del objeto `datos` tal como se declara, y es lo que vacía los
datos al cambiar de registro. `restauraBorrador()` mezcla el molde sobre lo que
haya en memoria y después el borrador: una clave que no esté en el molde **no
se borra**, así que el dato de una persona se cuela en el borrador de otra —y
el formulario deja aparcar varios registros a la vez—. Pasó con `nacimiento`.

Un afiliado nuevo queda disponible en los tres lados el mismo día: en
`clientes` y en el buscador de clientes (lo hace `engancha_cliente`, que corre
para todo registro), y en la base de asesores con su ficha llena
(`alta_asesor_desde_afiliacion`). Si la persona ya existía, esa función
**completa los campos en blanco** y no pisa ninguno cargado; el candado contra
duplicados mira nombre, código y DNI, porque «Helen Coska» y «HELEN KOSKA» son
la misma señora.

## Para qué sirve el panel (y para qué dejó de servir)

El panel hace dos cosas: **genera los PDF** (contrato, reescrito, ficha) y
**guarda la información estructurada** para el próximo ingreso y para cargarla
al portal de Rena Ware. No es un sistema de seguimiento.

Lo tuvo: un flujo de estados (por revisar → revisado → ingresado → procesado),
la evaluación crediticia (aprobado, observado, rechazado con su plazo de 15
días), el despacho y la devolución de la inicial. Obligaba a estar todo el día
actualizándolo y existía para saber la producción, que ahora se mira
directamente en el portal de Rena Ware. Se quitó de la vista en noviembre de
2026.

**No se borró nada.** Las columnas `estado` y `resultado` y las tablas `hitos`
y `observaciones` siguen en la base con todo lo que tenían, el Excel las sigue
exportando, y en la ficha de un registro que tenga algo anotado aparece un
bloque plegado, «Seguimiento anterior», con su línea de tiempo y sus
observaciones. Si alguna vez hace falta volver a llevarlo, la data está.

Lo único que se conservó vivo es el **analista de Rena Ware**, en el bloque
«Vía de ingreso»: es opcional y sirve para que el reescrito le llegue por
correo.

## Buscar un pedido, no recordar su período

El panel se organizaba por quincena: para encontrar un pedido —por ejemplo para
hacerle un reescrito— había que acordarse de en cuál se ingresó. Ahora la lista
son **todos los registros**, del más nuevo al más viejo, y el buscador es la
puerta de entrada: encuentra por nombre, apellido, DNI, **número de pedido**,
código del registro, asesor, producto, celular, correo o distrito, con las
palabras en cualquier orden.

El período no desapareció: va como sello (`P23`) en cada fila y como un filtro
más al lado del asesor, con los períodos que de verdad tienen registros. En la
ficha se sigue pudiendo cambiar el período de un pedido, y el desplegable
**incluye siempre el período propio del registro**: antes ofrecía solo los cinco
alrededor de hoy, así que abrir un pedido viejo mostraba otro período y guardar
lo movía de quincena sin avisar.

Se cargan todos los registros de una vez (son unos cientos) y el filtrado ocurre
en el navegador. Si algún día son miles, el sitio donde paginar es
`cargarPeriodo()`.

## Pasar una venta de crédito a contado

Cuando Créditos observa un pedido y la venta se cierra al contado, el cambio se
hace desde la ficha, en **Modalidad**. Antes ese campo era solo texto
(«Autocompra o venta a terceros»), así que los montos se dejaban en cero a mano
pero `registros.tipo` seguía en `credito` y el contrato seguía marcando la
casilla CRÉDITO: el PDF lee el tipo real, no el texto.

Ahora el selector cambia el tipo de verdad, con una confirmación antes. Al pasar
a contado deja en cero cuotas, cuota mensual, intereses y gastos, borra la
evaluación (`resultado`), y el contrato o reescrito marca **CONTADO** con el
precio en su casilla y CRÉDITO vacío. Al volver a crédito reaparece el campo de
cuotas y la evaluación vuelve a `pendiente`. En los dos sentidos queda anotado
en la bitácora del registro, porque un reescrito tiene que poder explicarse.

## El regalo de los especiales

Un especial trae un complemento de regalo —la Joyita y el juego de servir en
Compartir, la tetera con infusor en Navidad— y vive en `productos.regalo`.
Estaba en la base y no se veía en ninguna parte: ni al vender, ni en la ficha,
ni en el contrato.

Ahora se ve al elegir el producto (debajo del nombre, en verde), en el pedido
en curso, en el resumen de la venta como «Incluye de regalo» y en la ficha del
panel. **No se mete dentro del nombre**: el nombre va tal cual a
`registro_items.nombre` y al contrato, y meterlo ahí lo repetiría en todos
lados. Viaja en su propia columna, `registro_items.regalo`, que se guarda con
la venta: el catálogo cambia de campaña y el contrato debe decir lo que se
prometió ese día.

En el PDF el regalo va en **su propia línea de mercadería**, al 75% del tamaño.
Se probó ponerlo detrás del producto en la misma línea y no entra: el nombre de
un especial ya ocupa la caja entera (268 pt) y los dos quedaban en 4 pt,
ilegibles. En línea aparte el producto conserva su tamaño. Si las cuatro líneas
están ocupadas por productos, el regalo se pega al final de la última, chico,
que es mejor que perderlo. Nada de emojis en el PDF: la Helvetica incrustada no
los tiene y revienta al dibujar.

SQL: `sql/20261112_regalo_en_los_items.sql`.

## Cumpleaños del equipo

En **Asesores** hay dos pestañas: la **Base** de siempre y **🎂 Cumpleaños**.
La segunda sirve para dos cosas distintas y por eso es una sola lista ordenada
por día: saludar a cada quien el día que cumple, y una vez al mes celebrar a
todos los del mes.

En el mes de hoy la lista se parte en **Hoy · Lo que viene · Ya pasaron**, con
el de hoy resaltado; en cualquier otro mes va de corrido. Cada fila trae el día,
los años que cumple, el código, la zona y un botón **Saludar** que abre WhatsApp
con el mensaje ya escrito (solo si el celular es un 9 de nueve dígitos). El
botón **Copiar la lista del mes** la deja en texto para pegarla en el grupo.

La etiqueta **NUEVO** pide dos condiciones: que la ficha venga de una
**afiliación** y que tenga menos de 90 días. Las dos, a propósito: la mayoría de
las fichas entró por carga masiva de la lista de Rena Ware, y ahí `ingreso_fecha`
es el día en que se subió el archivo, no el día en que la persona entró al
equipo. Mirando solo la fecha, una carga marcaba de golpe 30 de los 36 del mes
y la etiqueta no distinguía nada.

Quien no tiene `nacimiento` no aparece en ningún mes: el pie de la pestaña dice
cuántos son y manda al filtro «Sin fecha de nacimiento» de la Base. Las fechas
se leen partiendo el texto `AAAA-MM-DD`, nunca con `new Date()`: eso las
interpreta en UTC y en Lima retrocede un día, así que un cumpleaños del 1 salía
el último del mes anterior. Un 29 de febrero se muestra tal cual en los años no
bisiestos; no se construye ninguna fecha con él, así que no revienta.

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
- **Un toque, una respuesta.** Mientras la siguiente burbuja se escribe, los
  botones de la pregunta anterior siguen en pantalla. Un segundo toque
  respondía dos veces y el formulario saltaba un paso: de ahí salían las
  respuestas duplicadas y la sensación de que «se traba». El dock se cierra
  con el primer toque (`tomaDock()`) y se abre cuando se pinta el siguiente
  (`dockLimpiar()`); los botones que abren el selector de archivos llevan
  `noBloquea:true`, y hay un reloj de 6 s por si algún camino no repinta.
- **Las fotos viven en localStorage y ahí caben unos 5 MB.** Cuando no entran,
  `escribeBorradores()` aligera primero los borradores parados, después los
  suelta enteros del más viejo al más nuevo, y **solo al final** guarda el
  activo sin fotos, avisando en pantalla. El activo nunca pierde sus fotos en
  silencio: eso era lo que obligaba a volver a subir el recibo tras recargar.
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
