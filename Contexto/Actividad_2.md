# Actividad 2 — Preparación de datos y prototipo del modelo BI

| Campo | Contenido |
| --- | --- |
| Institución | ISTE - Tecnológico Superior Universitario España |
| Vicerrectorado | VICERRECTORADO ACADÉMICO |
| Unidad | UNIDAD DE PLANIFICACIÓN Y GESTIÓN ACADÉMICA |
| Unidad de posgrados | UNIDAD DE POGRADOS |
| Programa | MAESTRIA TECNOLÓGICA EN DESARROLLO E INNOVACIÓN DIGITAL EN INTELIGENCIA DE NEGOCIOS |
| PAO | PAO I: MAY 2026– SEP 2026 |
| Nombre | WLADIMIR MARCELO NACIMBA OÑA |
| Asignatura | PROYECTOS DE INTELIGENCIA DE NEGOCIOS |
| Actividad | ACTIVIDAD 2 — PREPARACIÓN DE DATOS Y PROTOTIPO DEL MODELO BI |
| Código del formato | POS_ DOG _001 |
| Revisión | 01 |
| Fecha elaboración | 10/05/2024 |
| Fecha última actualización | 10/05/2024 |
| Versión del formato | 0.1 |
| Realizado por | Ing. Gerardo Villarreal T. Msc. Dirección de Posgrados |
| Revisado por | Lcdo. Víctor Teneda, Mg. Dirección Planfcacón Académica |
| Aprobado por | Ing. Diego Molina, Mg. – Vicerrector Académico |
| Control documental | Documento controlado por: Sistema de Gestión Documental |

---

<!-- Página 2 -->

## 1. Descripción de las fuentes de datos.

Para la preparación del modelo se utilizó el Egresos venta 2026, obtenido de la reportería del sistema Hanastek del Centro de Distribución de Hanaska. El archivo contiene el detalle de los egresos y los catálogos necesarios para identificar clientes, responsables operativos y productos.

**Figura 1. Consulta de la fuente de datos en el sistema Hanastek**

![Elemento visual de la página 2](assets/p02_img_65.jpeg)

**Figura 2. Configuración de la exportación de egresos**

![Elemento visual de la página 2](assets/p02_img_66.jpeg)

*Fuente de las figuras 1 y 2: sistema Hanastek, módulo de egresos.*

---

<!-- Página 3 -->

El periodo analizado comprende desde el 1 de enero hasta el 16 de agosto de 2026. La hoja Detalle Ventas contiene 1.028.304 líneas de producto y 12 variables originales. Las hojas Jefe Operativo y Catálogo se utilizaron para verificar la información descriptiva y la integridad de los códigos.

| Fuente | Registros | Campos | Uso en el modelo |
| --- | --- | --- | --- |
| Detalle Ventas | 1.028.304 | 12 | Egresos, fechas, clientes, responsables, productos, cantidad y precio cliente. |
| Jefe Operativo | 819 | 11 | Catálogo de clientes, empresas y responsables operativos. |
| Catálogo | 8.192 | 44 | Descripción, clasificación, unidad y atributos del producto. |
| Calendario | 228 | 7 | Dimensión generada en R desde FDespacho para análisis temporal. |

El archivo no contiene tablas de zonas ni metas comerciales. En consecuencia, la empresa se utilizó como dimensión organizativa disponible y el cumplimiento de metas se presentó como N/D.

## 2. Problemas de calidad encontrados.

Antes de realizar la limpieza se revisaron duplicados, campos vacíos, fechas, valores numéricos y correspondencia de códigos con los catálogos. No se encontraron filas duplicadas exactas, fechas inválidas, cantidades o precios no positivos, ni códigos de clientes o productos sin correspondencia. Sin embargo, se identificaron aspectos de estructura que debían corregirse para trabajar la información en R y utilizarla en el dashboard.

| Aspecto | Hallazgo | Tratamiento |
| --- | --- | --- |
| Encabezados y textos | Los nombres originales contienen separadores y espacios que dificultan programar transformaciones repetibles. | Normalizar nombres y textos. |
| Fórmulas de búsqueda | Jefe Operativo, Empresa, Clasificación y Precio Cliente dependen de búsquedas de Excel. | Materializar valores en el modelo R. |
| Valores atípicos | 134.047 cantidades y 43.763 precios superan el límite IQR. | Marcar; no borrar sin regla de negocio. |
| Mes incompleto | Agosto contiene información solamente hasta el día 16. | Advertir al interpretar la variación mensual. |
| Fuentes ausentes | No existen datos de zona, meta comercial ni costo interno. | No calcular metas ni rentabilidad real. |

---

<!-- Página 4 -->

La revisión inicial se realizó para conocer el estado real de la fuente antes de modificarla. Primero se importaron las tres hojas; después se comprobaron duplicados, campos vacíos, fechas y valores numéricos. También se contrastaron los códigos de clientes y productos con sus catálogos. Los valores extremos se identificaron mediante el rango intercuartílico, pero se conservaron porque pueden corresponder a operaciones válidas.

Los bloques incluidos en el informe presentan las operaciones centrales de cada apartado. La ejecución completa y reproducible se entrega en actividad2_bi.R.

**Importación de los datos.** Este es el punto exacto donde R abre el archivo Egresos venta 2026.xlsx. read_excel() lee cada hoja y as.data.table() la convierte en una tabla eficiente para trabajar con más de un millón de registros.

```r
# 2. PROBLEMAS DE CALIDAD ENCONTRADOS
# 2.1 Importación: se cargan las tres hojas necesarias del Excel.
detalle_original <- as.data.table(read_excel(
  archivo_excel, sheet = 'Detalle Ventas', .name_repair = 'minimal'))
jefes_original <- as.data.table(read_excel(
  archivo_excel, sheet = 'Jefe Operativo', .name_repair = 'minimal'))
catalogo_original <- as.data.table(read_excel(
  archivo_excel, sheet = 'Catalogo', .name_repair = 'minimal'))
```

El resultado de este bloque son tres objetos visibles en el panel Environment de RStudio: detalle_original, jefes_original y catalogo_original. Se mantienen separados porque la primera hoja contiene los movimientos y las otras dos permiten comprobar clientes y productos.

**Diagnóstico de calidad.** Después de importar, este bloque cuantifica problemas que podrían alterar el análisis. Se utiliza antes de limpiar para dejar evidencia del estado original de la fuente.

---

<!-- Página 5 -->

```r
# 2.2 Revisión: se cuentan duplicados, vacíos y fechas inválidas.
duplicados_antes <- sum(duplicated(detalle_original))
faltantes_antes <- sum(vapply(detalle_original, function(x)
  if (is.character(x)) sum(is.na(x) | trimws(x) == '') else sum(is.na(x)),
  numeric(1)))
fechas_despacho_revision <- as.IDate(detalle_original[['FDespacho']])
fechas_invalidas_antes <- sum(is.na(fechas_despacho_revision))
# Se convierten cantidad y precio para detectar valores no numéricos o extremos.
cantidad_revision <- as.numeric(detalle_original[['Cantidad']])
precio_revision <- as.numeric(detalle_original[['Precio cliente']])
# Se verifica que los códigos existan en los catálogos de apoyo.
productos_fuera_catalogo <- sum(!unique(detalle_original[['Item Producto']]) %in%
                                catalogo_original[['Item']])
clientes_fuera_catalogo <- sum(!unique(detalle_original[['Cod- Cliente']]) %in%
                               jefes_original[['ItemSubsitio']])
```

Las comprobaciones permiten decidir si un registro debe corregirse, marcarse o conservarse. En esta fuente no se encontraron duplicados exactos, vacíos ni fechas inválidas; los valores extremos se marcaron para revisión y no se eliminaron sin una regla de negocio.

**Figura 3. Código y resultado de la revisión inicial**

![Elemento visual de la página 5](assets/p05_img_80.png)

*Fuente: elaboración propia en RStudio; se observan el script actividad2_bi.R, la consola y el panel Environment.*

---

<!-- Página 6 -->

Los valores señalados como atípicos no se consideraron errores de forma automática. La base incluye productos vendidos por unidad, kilogramo o volumen, además de clientes con distintos niveles de consumo. Por ese motivo, los registros se conservaron y se añadieron banderas de control para facilitar una revisión posterior.

## 3. Acciones de limpieza aplicadas.

La limpieza se concentró en estandarizar la estructura sin modificar el significado comercial de los registros. Se ajustaron los nombres de las columnas, se normalizaron mayúsculas y espacios, se convirtieron las fechas y los campos numéricos, se verificaron las claves y se crearon las variables requeridas para el análisis.

La conversión de tipos permite que R trate correctamente las fechas y los valores numéricos. La normalización de textos evita categorías duplicadas por diferencias de mayúsculas o espacios. Posteriormente se calcula el valor de venta, se crean los campos de calendario y se añaden banderas para revisar cantidades o precios atípicos sin eliminarlos.

Primero se crea una copia de trabajo y se cambian los nombres de las columnas. De esta manera se conserva la fuente original y se utilizan nombres cortos, sin espacios ni guiones, que son más fáciles de escribir en R.

```r
# 3.1 Copia y nombres de columnas
detalle <- copy(detalle_original)
setnames(detalle,
  c('Numero Egreso','FRegistro','FDespacho','Cod- Cliente','Cliente',
    'Jefe Operativo','Empresa','Item Producto','Producto','Clasificacion',
    'Cantidad','Precio cliente'),
  c('numero_egreso','fecha_registro','fecha_despacho','cliente_id','cliente',
    'jefe_operativo','empresa','producto_id','producto','clasificacion',
    'cantidad','precio_cliente'))
```

copy() evita modificar detalle_original y setnames() renombra las columnas sin reconstruir la tabla. Este paso permite comparar la entrada con el resultado depurado.

Después se convierten los tipos de datos y se normalizan los textos. Esto es necesario porque una fecha guardada como texto no se puede agrupar correctamente y diferencias como espacios o mayúsculas pueden crear categorías duplicadas.

---

<!-- Página 7 -->

```r
# 3.2 Conversión de tipos y normalización de textos
detalle[, fecha_registro := as.POSIXct(fecha_registro,
                                       tz = 'America/Guayaquil')]
detalle[, fecha_despacho := as.IDate(fecha_despacho)]
detalle[, `:=`(numero_egreso = as.integer(numero_egreso),
               cliente_id = as.integer(cliente_id),
               producto_id = as.integer(producto_id),
               cantidad = as.numeric(cantidad),
               precio_cliente = as.numeric(precio_cliente))]
for (campo in c('cliente','jefe_operativo','empresa','producto','clasificacion'))
  set(detalle, j = campo, value = limpiar_texto(detalle[[campo]]))
detalle <- unique(detalle)
```

as.POSIXct() y as.IDate() convierten las fechas; as.integer() y as.numeric() preparan códigos y medidas. limpiar_texto() quita espacios repetidos y unifica mayúsculas. unique() solo elimina filas completamente iguales, no varias líneas válidas de un mismo egreso.

Finalmente se crean los campos analíticos que utilizan los KPI, los gráficos y los filtros del dashboard.

```r
# 3.3 Campos calculados para el análisis
detalle[, `:=`(
  valor_venta = cantidad * precio_cliente,
  fecha_id = as.integer(format(fecha_despacho, '%Y%m%d')),
  mes = as.IDate(format(fecha_despacho, '%Y-%m-01')),
  anio = as.integer(format(fecha_despacho, '%Y')),
  mes_num = as.integer(format(fecha_despacho, '%m')),
  cantidad_atipica = cantidad > limite_cantidad,
  precio_atipico = precio_cliente > limite_precio
)]
detalle[, mes_nombre := meses_es[mes_num]]
```

El operador := agrega columnas directamente en data.table. valor_venta alimenta los indicadores monetarios; fecha_id, mes y año permiten el análisis temporal; y las dos banderas identifican observaciones extremas sin eliminarlas.

---

<!-- Página 8 -->

**Figura 4. Código y resultado de la limpieza**

![Elemento visual de la página 8](assets/p08_img_87.jpeg)

*Fuente: elaboración propia en RStudio; la consola presenta los registros antes y después y los controles posteriores.*

No se eliminaron registros, debido a que los controles de duplicidad, campos vacíos, fechas inválidas y valores no positivos dieron como resultado cero. Se incorporaron siete campos de apoyo: valor de venta, identificador de fecha, mes, año, número de mes, nombre de mes y banderas de atipicidad.

## 4. Proceso ETL documentado.

El proceso ETL se organizó en tres etapas. En la extracción se importaron las tres hojas del archivo de Excel. En la transformación se normalizaron los campos, se validaron los tipos de datos y se calcularon las variables de análisis. Finalmente, en la carga se guardaron la base depurada, el modelo dimensional y las tablas de resultados utilizadas por Shiny.

---

<!-- Página 9 -->

| Etapa | Acción aplicada | Evidencia generada |
| --- | --- | --- |
| Extracción | Importar Detalle Ventas, Jefe Operativo y Catálogo desde Excel. | 1.028.304 líneas y dos catálogos cargados. |
| Transformación | Normalizar campos, validar tipos y claves, crear variables calculadas y banderas. | Base consistente y lista para análisis. |
| Carga | Guardar base depurada, modelo dimensional y tablas de resultados. | CSV.GZ, RDS, archivos CSV y Shiny. |

La extracción toma la información del libro de Excel y la transformación aplica las reglas descritas anteriormente. La carga conserva dos versiones: un CSV.GZ para intercambio y auditoría, y un RDS que mantiene los tipos y objetos de R, por lo que Shiny puede iniciar sin procesar nuevamente el archivo original. Además, se exportan los KPI y las validaciones en tablas CSV.

```r
# 4. PROCESO ETL DOCUMENTADO
# La carga guarda los productos reutilizables del proceso ETL.
fwrite(detalle, file.path(dir_data, 'base_depurada.csv.gz'),
       compress = 'gzip')
fwrite(registro_cambios,
       file.path(dir_salidas, 'registro_cambios.csv'))
# Cuando el modelo y los KPI están listos se guardan sus salidas.
saveRDS(modelo_bi, file.path(dir_data, 'modelo_bi.rds'),
        compress = 'gzip')
fwrite(medidas_kpi,
       file.path(dir_salidas, 'medidas_kpi.csv'))
fwrite(estadisticos,
       file.path(dir_salidas, 'estadisticos.csv'))
fwrite(ventas_mensuales,
       file.path(dir_salidas, 'ventas_mensuales.csv'))
```

Este bloque corresponde a la carga del ETL. Se utiliza para conservar una base comprimida, el modelo completo de R y tablas CSV que pueden revisarse sin ejecutar nuevamente toda la transformación.

---

<!-- Página 10 -->

### Evidencia de ejecución en RStudio

![Elemento visual de la página 10](assets/p10_img_92.png)

*Evidencia del script único durante la verificación de los archivos generados por el proceso ETL.*

El flujo se dibuja con funciones de grid. Cada bloque representa una etapa y las flechas muestran el orden de ejecución. Esta representación permite relacionar el código de carga con el proceso completo de extracción, transformación y carga.

```r
# 4. PROCESO ETL DOCUMENTADO
# Función auxiliar que dibuja cada tarjeta del proceso.
etapa <- function(x, titulo, numero, texto, color) {
  grid.roundrect(x, 0.5, width = 0.25, height = 0.48,
    r = unit(0.03, 'snpc'),
    gp = gpar(fill = 'white', col = color, lwd = 2.5))
  grid.circle(x, 0.66, r = unit(0.035, 'snpc'),
    gp = gpar(fill = color, col = NA))
  grid.text(numero, x, 0.66,
    gp = gpar(col = 'white', fontsize = 15, fontface = 'bold'))
  grid.text(titulo, x, 0.57,
    gp = gpar(col = color, fontsize = 16, fontface = 'bold'))
  grid.text(texto, x, 0.42,
    gp = gpar(col = '#26364D', fontsize = 11, lineheight = 1.35))
}
```

---

<!-- Página 11 -->

```r
# 4. PROCESO ETL DOCUMENTADO
# Se genera la evidencia visual del flujo ETL desde el mismo script.
captura_etl <- function(archivo) {
  png(archivo, width = 1700, height = 850, res = 150)
  grid.newpage()
  etapa(0.18, 'EXTRACCIÓN', '1',
        'Excel\nDetalle Ventas\nJefe Operativo\nCatálogo', azul)
  etapa(0.50, 'TRANSFORMACIÓN', '2',
        'Tipos y fechas\nTextos normalizados\nCampos calculados', turquesa)
  etapa(0.82, 'CARGA', '3',
        'Base CSV.GZ\nModelo RDS\nTablas CSV\nShiny', naranja)
  grid.lines(x = unit(c(0.31, 0.37), 'npc'),
             y = unit(c(0.5, 0.5), 'npc'), arrow = arrow(type = 'closed'))
  grid.lines(x = unit(c(0.63, 0.69), 'npc'),
             y = unit(c(0.5, 0.5), 'npc'), arrow = arrow(type = 'closed'))
  dev.off()
}
captura_etl(file.path(dir_evidencias, '04_proceso_etl.png'))
```

La función abre un archivo PNG, coloca las tres etapas en el lienzo y al final cierra el dispositivo con dev.off(). Así la imagen no fue dibujada manualmente: se puede volver a crear al ejecutar actividad2_bi.R.

**Figura 5. Flujo ETL ejecutado**

![Elemento visual de la página 11](assets/p11_img_95.png)

*Fuente: elaboración propia en R.*

**Resultado de la carga.** La base depurada conserva 1.028.304 registros. El archivo CSV.GZ facilita el intercambio de la información y el formato RDS reduce el tiempo de inicio de la aplicación Shiny.

---

<!-- Página 12 -->

## 5. Modelo de datos.

Se construyó un modelo en estrella con una tabla de hechos y las dimensiones disponibles en el archivo. La tabla fact_ventas contiene una fila por producto registrado en cada egreso y almacena las medidas cantidad, precio cliente y valor de venta. Las dimensiones permiten filtrar la información por fecha, producto, cliente, jefe operativo y empresa.

| Tabla | Filas | Clave | Contenido |
| --- | --- | --- | --- |
| fact_ventas | 1.028.304 | numero_egreso, fecha_id, cliente_id, producto_id | cantidad, precio_cliente, valor_venta |
| dim_producto | 1.640 | producto_id | producto y clasificación |
| dim_cliente | 524 | cliente_id | cliente, empresa y jefe operativo |
| dim_jefe | Responsables | jefe_operativo | responsable de la gestión |
| dim_empresa | 2 | empresa | COALSE y TECFOOD |
| dim_calendario | 228 | fecha_id | fecha, mes, trimestre y día |

El modelo en estrella separa los movimientos de venta de la información descriptiva. Esto evita repetir atributos en las dimensiones y permite que los filtros de fecha, producto, cliente, responsable o empresa se propaguen hacia la tabla de hechos. Finalmente se comprueba que todas las claves utilizadas por fact_ventas existan en sus dimensiones.

La construcción comienza con las dimensiones. Cada dimensión conserva una fila por código o categoría y contiene los campos descriptivos que se utilizarán como filtros.

```r
# 5.1 Dimensiones del modelo
dim_producto <- detalle[, .N,
  by = .(producto_id, producto, clasificacion)][order(producto_id, -N)]
dim_producto <- dim_producto[, .SD[1], by = producto_id][, N := NULL]
dim_cliente <- detalle[, .N,
  by = .(cliente_id, cliente, empresa, jefe_operativo)][order(cliente_id, -N)]
dim_cliente <- dim_cliente[, .SD[1], by = cliente_id][, N := NULL]
dim_jefe <- data.table(
  jefe_operativo = sort(unique(detalle$jefe_operativo)))
dim_empresa <- data.table(
  empresa = sort(unique(detalle$empresa)))
dim_calendario <- data.table(fecha_despacho = seq(
  as.Date(min(detalle$fecha_despacho)),
  as.Date(max(detalle$fecha_despacho)), by = 'day'))
```

---

<!-- Página 13 -->

La opción by agrupa los registros por clave. .SD[1] conserva una sola descripción por código y unique() obtiene las categorías sin repetir. seq() construye el calendario completo entre la primera y la última fecha.

La tabla de hechos mantiene una fila por producto incluido en cada egreso. Allí se concentran las claves del modelo y las medidas que se sumarán en los indicadores.

```r
# 5.2 Tabla de hechos
fact_ventas <- detalle[, .(
  numero_egreso, fecha_id, fecha_despacho, mes,
  cliente_id, cliente, jefe_operativo, empresa,
  producto_id, producto, clasificacion,
  cantidad, precio_cliente, valor_venta,
  cantidad_atipica, precio_atipico
)]
```

La selección .() conserva solo los campos necesarios. Las claves conectan fact_ventas con las dimensiones y cantidad, precio_cliente y valor_venta funcionan como medidas del análisis.

Por último se comprueba que cada clave utilizada en la tabla de hechos exista en su dimensión correspondiente.

```r
# 5.3 Integridad de las relaciones
validacion_relaciones <- data.table(
  relacion = c('Hechos -> Productos','Hechos -> Clientes',
    'Hechos -> Jefes','Hechos -> Empresas','Hechos -> Calendario'),
  claves_sin_coincidencia = c(
    sum(!unique(fact_ventas$producto_id) %in% dim_producto$producto_id),
    sum(!unique(fact_ventas$cliente_id) %in% dim_cliente$cliente_id),
    sum(!unique(fact_ventas$jefe_operativo) %in% dim_jefe$jefe_operativo),
    sum(!unique(fact_ventas$empresa) %in% dim_empresa$empresa),
    sum(!unique(fact_ventas$fecha_id) %in% dim_calendario$fecha_id)
  )
)
```

%in% revisa si una clave existe y el signo ! identifica las que no coinciden. sum() cuenta esas diferencias. El resultado fue cero en las cinco relaciones, por lo que el modelo puede aplicar filtros sin dejar ventas desconectadas.

---

<!-- Página 14 -->

### Evidencia de ejecución en RStudio

![Elemento visual de la página 14](assets/p14_img_102.jpeg)

*Evidencia de ejecución en RStudio con la construcción del modelo y la verificación de sus relaciones.*

El diagrama del modelo también se genera desde R. La función caja() dibuja cada tabla, flecha() conecta las dimensiones con fact_ventas y los textos 1 y N indican que una fila de dimensión puede relacionarse con muchas filas de ventas.

```r
# 5. MODELO DE DATOS
# Funciones auxiliares para dibujar tablas y relaciones.
caja <- function(x, y, titulo, campos, color) {
  grid.roundrect(x, y, width = 0.25, height = 0.23,
    r = unit(0.03, 'snpc'),
    gp = gpar(fill = 'white', col = color, lwd = 2.5))
  grid.rect(x, y + 0.085, width = 0.25, height = 0.06,
    gp = gpar(fill = color, col = color))
  grid.text(titulo, x, y + 0.085,
    gp = gpar(col = 'white', fontsize = 13, fontface = 'bold'))
  grid.text(paste(campos, collapse = '\n'), x - 0.105, y - 0.025,
    just = 'left', gp = gpar(col = '#243248', fontsize = 8.5))
}
flecha <- function(x0, y0, x1, y1) {
  grid.lines(x = unit(c(x0, x1), 'npc'),
    y = unit(c(y0, y1), 'npc'),
    arrow = arrow(length = unit(0.13, 'inches'), type = 'closed'))
}
```

---

<!-- Página 15 -->

```r
# 5. MODELO DE DATOS
# Código que genera el diagrama del modelo en estrella.
captura_modelo <- function(archivo) {
  png(archivo, width = 1700, height = 1050, res = 150)
  grid.newpage()
  caja(0.50, 0.50, 'FACT_VENTAS',
       c('numero_egreso', 'fecha_id', 'cliente_id', 'producto_id',
         'cantidad', 'precio_cliente', 'valor_venta'), azul)
  caja(0.18, 0.76, 'DIM_PRODUCTO',
       c('producto_id (PK)', 'producto', 'clasificacion'), turquesa)
  caja(0.82, 0.76, 'DIM_CLIENTE',
       c('cliente_id (PK)', 'cliente', 'empresa', 'jefe_operativo'), celeste)
  caja(0.18, 0.25, 'DIM_CALENDARIO',
       c('fecha_id (PK)', 'fecha', 'mes', 'trimestre'), naranja)
  caja(0.82, 0.25, 'DIM_JEFE / EMPRESA',
       c('jefe_operativo', 'empresa'), '#7C3AED')
  flecha(0.30, 0.70, 0.40, 0.58)
  flecha(0.70, 0.70, 0.60, 0.58)
  flecha(0.30, 0.31, 0.40, 0.43)
  flecha(0.70, 0.31, 0.60, 0.43)
  dev.off()
}
captura_modelo(file.path(dir_evidencias, '05_modelo_datos.png'))
```

El diagrama permite comprobar visualmente la arquitectura antes de trabajar el dashboard. La tabla de hechos queda en el centro porque recibe los filtros de producto, cliente, calendario, jefe y empresa.

---

<!-- Página 16 -->

**Figura 6. Modelo de datos y relaciones**

![Elemento visual de la página 16](assets/p16_img_107.png)

*Fuente: elaboración propia en R. Todas las relaciones obtuvieron cero claves sin coincidencia.*

La estructura separa las operaciones de venta de sus datos descriptivos y establece relaciones de uno a muchos. De esta manera, una fecha, un cliente o un producto puede filtrar varias líneas sin repetir información en las dimensiones. No se incluyeron dimensiones de zona ni de meta comercial porque esas fuentes no constan en el archivo entregado.

## 6. Medidas o cálculos creados.

| KPI | Fórmula | Resultado general |
| --- | --- | --- |
| Valor total de ventas | Σ(Cantidad × Precio Cliente) | $20,332,897 |
| Número de egresos | Conteo distinto de Numero Egreso | 56,814 |
| Ticket promedio | Ventas totales / Número de egresos | $357.89 |
| Variación mensual de ventas | (Mes actual / Mes anterior - 1) × 100 | -55.84% |
| Clientes atendidos | Conteo distinto de Cod-Cliente | 524 |
| Frecuencia de despacho por producto | Conteo distinto de egresos por producto | TOMATE RIÑON REGULAR PINTON AL GRANEL 1 KG (9,543) |
| Ventas por jefe operativo | Σ(Valor Venta) por jefe operativo | GABRIEL ROJAS ($2,112,349) |
| Participación por clasificación | Ventas de clase / Ventas totales × 100 | PERECIBLE (55.52%) |

---

<!-- Página 17 -->

Los indicadores se calculan a partir de fact_ventas para que todos utilicen una misma fuente depurada. Las sumas miden el valor comercial; uniqueN evita contar varias veces un egreso que contiene distintos productos; shift compara cada mes con el anterior; y las agrupaciones identifican los productos, responsables y clasificaciones con mayor participación.

Las medidas generales se calculan primero porque también son reutilizadas por los demás indicadores y por las tarjetas del dashboard.

```r
# 6. MEDIDAS GENERALES
ventas_totales <- sum(fact_ventas$valor_venta, na.rm = TRUE)
numero_egresos <- uniqueN(fact_ventas$numero_egreso)
ticket_promedio <- ventas_totales / numero_egresos
clientes_atendidos <- uniqueN(fact_ventas$cliente_id)
```

sum() acumula el valor de las líneas de venta. uniqueN() cuenta identificadores diferentes para no repetir un egreso o un cliente. El ticket promedio divide el valor total para el número de egresos distintos.

Después se agrupan las ventas por mes. shift() recupera el resultado anterior y permite calcular la variación porcentual de forma automática.

```r
# 6. TENDENCIA Y VARIACIÓN MENSUAL
ventas_mensuales <- fact_ventas[, .(
  ventas = sum(valor_venta),
  egresos = uniqueN(numero_egreso)
), by = mes][order(mes)]
ventas_mensuales[, variacion_mensual :=
  (ventas / shift(ventas) - 1) * 100]
```

by = mes crea una fila por periodo y order(mes) mantiene el orden cronológico. La primera variación queda vacía porque no existe un mes anterior con el cual compararla.

Las agrupaciones siguientes responden a las preguntas sobre productos, responsables y clasificaciones.

---

<!-- Página 18 -->

```r
# 6. RANKINGS Y PARTICIPACIÓN
productos_frecuencia <- fact_ventas[, .(
  frecuencia_despacho = uniqueN(numero_egreso),
  ventas = sum(valor_venta)
), by = .(producto_id, producto)][order(-frecuencia_despacho)]
top_productos_mayor <- head(productos_frecuencia, 10)
ventas_jefe <- fact_ventas[, .(ventas = sum(valor_venta)),
  by = jefe_operativo][order(-ventas)]
ventas_clasificacion <- fact_ventas[, .(ventas = sum(valor_venta)),
  by = clasificacion][order(-ventas)]
ventas_clasificacion[, participacion :=
  ventas / sum(ventas) * 100]
```

head(..., 10) conserva los diez productos con mayor frecuencia. order(-ventas) ordena de mayor a menor y la participación divide las ventas de cada clasificación para el total general.

Finalmente se calculan cuatro estadísticos complementarios para describir las líneas de venta y revisar la relación entre cantidad y precio.

```r
# 6. ESTADÍSTICOS COMPLEMENTARIOS
estadisticos <- data.table(
  medida = c('Media de valor por línea', 'Varianza de valor por línea',
             'Covarianza cantidad-precio', 'Correlación cantidad-precio'),
  resultado = c(
    mean(fact_ventas$valor_venta),
    var(fact_ventas$valor_venta),
    cov(fact_ventas$cantidad, fact_ventas$precio_cliente),
    cor(fact_ventas$cantidad, fact_ventas$precio_cliente)
  )
)
```

mean() obtiene el promedio, var() mide la dispersión, cov() indica si las variables cambian juntas y cor() expresa la intensidad de su relación en una escala de -1 a 1.

---

<!-- Página 19 -->

### Evidencia de ejecución en RStudio

![Elemento visual de la página 19](assets/p19_img_114.jpeg)

*Evidencia de ejecución en RStudio con el código de las medidas y los resultados mostrados en la consola.*

La tabla de KPI se creó con la función captura_tabla(). La función recibe los nombres, las fórmulas y el resultado calculado para que la evidencia se genere directamente desde los objetos de R y no desde valores escritos a mano.

```r
# 6. MEDIDAS O CÁLCULOS CREADOS
tabla_kpi_evidencia <- medidas_kpi[, .(
  KPI = kpi, Formula = formula, Resultado = resultado)]
setnames(tabla_kpi_evidencia, c('KPI', 'Fórmula', 'Resultado'))
captura_tabla(
  file.path(dir_evidencias, '06_medidas_kpi.png'),
  'Medidas y cálculos implementados',
  tabla_kpi_evidencia,
  anchos = c(0.31, 0.37, 0.32), fontsize = 8.5
)
```

Este bloque sirve para dejar una evidencia resumida de las ocho medidas. Si un KPI cambia por una corrección en la base, la tabla se vuelve a generar con el nuevo resultado al ejecutar el script.

---

<!-- Página 20 -->

**Figura 7. Resumen de los ocho KPI**

![Elemento visual de la página 20](assets/p20_img_117.png)

*Fuente: elaboración propia; cálculos reproducibles en R.*

El cálculo general obtuvo USD 20.332.897 en ventas, 56.814 egresos, un ticket promedio de USD 357,89 y 524 clientes atendidos. El producto con mayor frecuencia fue TOMATE RIÑÓN REGULAR PINTÓN AL GRANEL 1 KG, registrado en 9.543 egresos. Gabriel Rojas presentó el mayor valor gestionado, con USD 2.112.349.

La clasificación Perecible concentró el 55,52 % del valor de ventas, seguida por No perecible con el 27,54 % y Fruver con el 16,94 %. La variación de agosto respecto de julio fue de -55,84 %. Este resultado corresponde a un mes incompleto, ya que la información de agosto llega únicamente hasta el día 16.

### Cálculos estadísticos complementarios.

| Cálculo | Resultado |
| --- | --- |
| Media de valor por línea | 19.7732 |
| Varianza de valor por línea | 3,838.9650 |
| Covarianza cantidad-precio | -17.5579 |
| Correlación cantidad-precio | -0.0696 |

---

<!-- Página 21 -->

La correlación entre cantidad y precio fue de -0,0696, lo que representa una relación lineal negativa muy débil. Por lo tanto, la cantidad despachada no explica por sí sola el precio unitario, debido a la variedad de productos, presentaciones y unidades del catálogo.

### 6.1. Tendencia mensual del valor de ventas.

La primera visualización resume el valor de ventas por mes. Se utiliza para identificar variaciones temporales y reconocer que agosto debe interpretarse con cautela porque la fuente llega hasta el día 16.

```r
# 6.1 Tendencia mensual: gráfico estático del análisis
grafico_mensual <- ggplot(ventas_mensuales,
  aes(x = as.Date(mes), y = ventas)) +
  geom_area(fill = celeste, alpha = 0.18) +
  geom_line(color = azul, linewidth = 1.25) +
  geom_point(color = turquesa, size = 3) +
  scale_x_date(date_labels = '%b', date_breaks = '1 month') +
  labs(title = 'Tendencia mensual del valor de ventas',
       x = NULL, y = 'Valor de ventas') + theme_minimal()
ggsave(file.path(dir_evidencias, 'resultado_tendencia_mensual.png'),
       grafico_mensual, width = 11, height = 6.2, dpi = 170)
mostrar_grafico('06. Gráfico: tendencia mensual', grafico_mensual)
```

ggplot() crea el gráfico desde ventas_mensuales; geom_line() une los meses y geom_point() hace visible cada resultado. ggsave() guarda la evidencia y mostrar_grafico() envía el mismo gráfico al panel Plots de RStudio.

**Figura 8. Tendencia mensual del valor de ventas**

![Elemento visual de la página 21](assets/p21_img_120.png)

*Fuente: elaboración propia en R.*

---

<!-- Página 22 -->

### 6.2. Productos con mayor frecuencia de despacho.

Este gráfico compara los diez productos con mayor frecuencia de despacho. La frecuencia se calcula por egresos distintos y no por líneas, para no contar dos veces un mismo producto dentro del mismo egreso.

```r
# 6.2 Productos: se usan los diez primeros del resumen calculado
grafico_productos <- ggplot(
  top_productos_mayor[order(frecuencia_despacho)],
  aes(x = reorder(producto, frecuencia_despacho),
      y = frecuencia_despacho)) +
  geom_col(fill = turquesa, width = 0.68) +
  coord_flip() +
  labs(title = 'Top 10 productos por frecuencia de despacho',
       x = NULL, y = 'Egresos distintos') + theme_minimal()
ggsave(file.path(dir_evidencias, 'resultado_top_productos.png'),
       grafico_productos, width = 11, height = 7, dpi = 170)
mostrar_grafico('06. Gráfico: productos con mayor frecuencia',
                grafico_productos)
```

reorder() ordena las barras por frecuencia y coord_flip() permite leer los nombres extensos de los productos. Así se puede reconocer rápidamente qué artículos se despachan con mayor recurrencia.

**Figura 9. Productos con mayor frecuencia de despacho**

![Elemento visual de la página 22](assets/p22_img_123.png)

*Fuente: elaboración propia en R.*

---

<!-- Página 23 -->

### 6.3. Representación de clientes.

Esta visualización representa a cada cliente según su comportamiento de compra. Para no comparar valores en escalas distintas, se estandarizan ventas, egresos, ticket promedio, cantidad total y productos diferentes. Los dos ejes son componentes principales calculados con esas variables; el color identifica la empresa real del cliente.

El primer bloque resume todas las compras de cada cliente en cinco características comparables.

```r
# Perfil de compra por cliente
perfil_clientes_pca <- fact_ventas[, .(
  ventas = sum(valor_venta),
  egresos = uniqueN(numero_egreso),
  ticket_promedio = sum(valor_venta) / uniqueN(numero_egreso),
  cantidad_total = sum(cantidad),
  productos_diferentes = uniqueN(producto_id)
), by = .(cliente_id, cliente, empresa)]
```

La agrupación by = cliente_id genera una fila por cliente. Las cinco medidas describen su volumen, frecuencia, ticket, cantidad y variedad de productos; no se crean observaciones nuevas.

El segundo bloque prepara las variables y calcula los componentes principales que se utilizan como ejes.

```r
# Estandarización y componentes principales
matriz_clientes <- scale(as.matrix(perfil_clientes_pca[, .(
  ventas, egresos, ticket_promedio,
  cantidad_total, productos_diferentes
)]))
pca_clientes <- prcomp(
  matriz_clientes, center = FALSE, scale. = FALSE)
perfil_clientes_pca[, `:=`(
  componente_1 = pca_clientes$x[, 1],
  componente_2 = pca_clientes$x[, 2]
)]
```

scale() estandariza las variables para que ventas no domine por manejar cifras más grandes. prcomp() resume la información en dos componentes: valores cercanos representan clientes con comportamientos parecidos.

El último bloque dibuja los clientes y guarda la evidencia que también se muestra en el panel Plots de RStudio.

---

<!-- Página 24 -->

```r
# Gráfico y evidencia
grafico_clientes_pca <- ggplot(perfil_clientes_pca,
  aes(componente_1, componente_2, color = empresa)) +
  geom_point(alpha = 0.72, size = 2.4) +
  theme_minimal()
ggsave(file.path(dir_evidencias,
  'resultado_representacion_clientes.png'),
  grafico_clientes_pca, width = 11, height = 6.5, dpi = 170)
mostrar_grafico('06. Gráfico: representación de clientes',
                grafico_clientes_pca)
```

ggplot() asigna los componentes a los ejes; geom_point() dibuja un punto por cliente y el color diferencia las empresas. No se crean grupos artificiales: cada punto procede de la base depurada.

**Figura 10. Representación de clientes según su comportamiento de compra**

![Elemento visual de la página 24](assets/p24_img_128.png)

*Fuente: elaboración propia en R; cada punto corresponde a un cliente real.*

### 6.4. Mapa de calor por mes y clasificación.

El mapa de calor resume el valor de ventas por mes y clasificación. Su objetivo es comparar visualmente qué categorías concentran mayor valor en cada periodo.

---

<!-- Página 25 -->

```r
# 6.4 Mapa de calor: ventas agrupadas por mes y clasificación
mapa_calor <- detalle[, .(ventas = sum(valor_venta)),
  by = .(mes, clasificacion)]
mapa_calor[, mes_etiqueta := factor(format(as.Date(mes), '%b'),
  levels = unique(format(as.Date(sort(unique(mes))), '%b')))]
grafico_calor <- ggplot(mapa_calor,
  aes(x = mes_etiqueta, y = clasificacion, fill = ventas)) +
  geom_tile(color = 'white', linewidth = 1.2) +
  geom_text(aes(label = paste0('$', round(ventas / 1e6, 2), ' M')),
            color = 'white', fontface = 'bold') +
  labs(title = 'Mapa de calor de ventas por mes y clasificación',
       x = 'Mes', y = NULL, fill = 'Ventas') + theme_minimal()
ggsave(file.path(dir_evidencias, 'resultado_mapa_calor.png'),
       grafico_calor, width = 11, height = 5.8, dpi = 170)
mostrar_grafico('06. Gráfico: mapa de calor', grafico_calor)
```

Cada celda muestra la suma de valor_venta y el color permite comparar la intensidad entre grupos. Este gráfico complementa los KPI porque permite ver simultáneamente el comportamiento mensual y la composición por clasificación.

**Figura 11. Mapa de calor de ventas por mes y clasificación**

![Elemento visual de la página 25](assets/p25_img_131.png)

*Fuente: elaboración propia en R.*

## 7. Prototipo del dashboard.

El dashboard se desarrolló con Shiny y bslib. La interfaz se distribuyó en cinco pestañas que contienen indicadores, gráficos de tendencia, rankings, controles de calidad y conclusiones. En la parte superior se incorporaron filtros por periodo, empresa, jefe operativo, clasificación y producto. Al modificar una selección, los indicadores y gráficos se calculan nuevamente con los registros filtrados.

---

<!-- Página 26 -->

| Pestaña | Contenido |
| --- | --- |
| Resumen ejecutivo | Ventas, egresos, ticket, meta N/D, tendencia y composición. |
| Tendencias y responsables | Variación mensual y ranking de jefes operativos. |
| Productos y clientes | Productos de mayor/menor frecuencia y clientes por valor. |
| Modelo y calidad | Relaciones 1:N, representación de clientes, mapa de calor y limpieza. |
| Conclusiones | Hallazgos recalculados y descarga del CSV filtrado. |

La reactividad se utiliza para que una selección modifique todo el dashboard sin volver a ejecutar manualmente el análisis. La función datos_filtrados aplica el periodo y los filtros comerciales; los objetos renderText y renderPlot consumen esa misma tabla; y downloadHandler permite descargar exactamente el subconjunto que se observa en pantalla.

La función reactiva central recibe las opciones seleccionadas por el usuario y devuelve únicamente las filas que cumplen los filtros.

```r
# 7. FILTROS REACTIVOS
datos_filtrados <- reactive({
  req(input$fechas)
  d <- ventas[fecha_despacho >= as.IDate(input$fechas[1]) &
              fecha_despacho <= as.IDate(input$fechas[2])]
  if (input$empresa != 'TODAS')
    d <- d[empresa == input$empresa]
  if (input$jefe != 'TODOS')
    d <- d[jefe_operativo == input$jefe]
  if (input$clasificacion != 'TODAS')
    d <- d[clasificacion == input$clasificacion]
  if (input$producto != 'TODOS')
    d <- d[producto == input$producto]
  d
})
```

reactive() vuelve a ejecutar el bloque cuando cambia un input. req() espera que exista el periodo y los if aplican únicamente los filtros distintos de TODAS o TODOS. El resultado d es la fuente común de las pestañas.

La descarga utiliza esa misma tabla reactiva para que el archivo exportado coincida con lo que se observa en pantalla.

---

<!-- Página 27 -->

```r
# 7. DESCARGA DE LA SELECCIÓN
output$descargar <- downloadHandler(
  filename = function()
    paste0('ventas_filtradas_', Sys.Date(), '.csv'),
  content = function(file)
    fwrite(datos_filtrados(), file)
)
```

downloadHandler() prepara la descarga; filename asigna un nombre con la fecha y fwrite() guarda los registros filtrados en formato CSV.

### Evidencia de ejecución en RStudio

![Elemento visual de la página 27](assets/p27_img_136.jpeg)

*Evidencia de ejecución del prototipo mediante RStudio y Shiny.*

### 7.1. Resumen ejecutivo.

Las tarjetas principales se calculan directamente con la base filtrada para que respondan a cualquier selección del usuario.

---

<!-- Página 28 -->

```r
# 7.1 TARJETAS DE INDICADORES
output$kpi_ventas <- renderText(
  moneda_ui(sum(datos_filtrados()$valor_venta)))
output$kpi_egresos <- renderText(
  format(uniqueN(datos_filtrados()$numero_egreso), big.mark = ','))
output$kpi_ticket <- renderText({
  d <- datos_filtrados()
  n <- uniqueN(d$numero_egreso)
  if (n == 0) '$0' else moneda_ui(sum(d$valor_venta) / n)
})
```

renderText() envía un valor de texto a cada tarjeta de Shiny. sum() obtiene las ventas, uniqueN() cuenta egresos sin repetir y format() agrega el separador de miles. Para el ticket se divide la venta para los egresos distintos; la condición if evita una división para cero cuando el filtro no devuelve registros.

La tendencia mensual se prepara una sola vez como objeto reactivo y luego se utiliza para construir el gráfico.

```r
# 7.1 TENDENCIA MENSUAL
tendencia <- reactive(
  datos_filtrados()[, .(
    ventas = sum(valor_venta),
    egresos = uniqueN(numero_egreso)
  ), by = mes][order(mes)]
)
output$grafico_tendencia <- renderPlot(
  grafico_linea(copy(tendencia()))
)
```

reactive() recalcula el resumen cuando cambian los filtros. by = mes agrupa los registros, order() organiza el resultado cronológicamente y renderPlot() presenta en la sección Plots de Shiny el gráfico creado por grafico_linea(). copy() evita modificar accidentalmente el resumen original.

La composición de ventas compara la participación de las tres clasificaciones de producto.

```r
# 7.1 COMPOSICIÓN POR CLASIFICACIÓN
output$grafico_clasificacion <- renderPlot({
  d <- datos_filtrados()[,
    .(ventas = sum(valor_venta)), by = clasificacion]
  ggplot(d, aes(x = 2, y = ventas, fill = clasificacion)) +
    geom_col(width = 0.72, color = 'white') +
    coord_polar(theta = 'y') +
    xlim(0.5, 2.5) + theme_void()
})
```

ggplot() relaciona las ventas con el color de cada clasificación. geom_col() construye las proporciones y coord_polar() transforma las barras en un gráfico circular. theme_void() elimina ejes que no aportan a esta visualización.

---

<!-- Página 29 -->

**Figura 12. Pestaña Resumen ejecutivo de Shiny**

![Elemento visual de la página 29](assets/p29_img_141.jpeg)

*Fuente: elaboración propia en Shiny; se observan la barra de navegación, los filtros, los KPI y los gráficos generados con la*

*base depurada.*

La vista general presenta USD 20.332.897 en ventas, 56.814 egresos y un ticket promedio aproximado de USD 358. El cumplimiento de metas se muestra como N/D porque el archivo analizado no contiene una tabla de metas comerciales.

### 7.2. Tendencias y responsables.

El gráfico detallado reutiliza el resumen mensual ya calculado para no duplicar el procesamiento.

```r
# 7.2 TENDENCIA CON VARIACIÓN
output$grafico_tendencia_detalle <- renderPlot(
  grafico_linea(copy(tendencia()), TRUE)
)
```

El argumento TRUE solicita a grafico_linea() que incluya la variación porcentual entre meses. renderPlot() vuelve a dibujar la salida cada vez que cambia tendencia().

El segundo gráfico identifica a los diez jefes operativos con mayor valor de ventas.

---

<!-- Página 30 -->

```r
# 7.2 RANKING DE RESPONSABLES
output$grafico_jefes <- renderPlot({
  d <- datos_filtrados()[,
    .(ventas = sum(valor_venta)),
    by = jefe_operativo
  ][order(-ventas)][1:10]
  validate(need(nrow(d) > 0,
    'No existen datos para la selección.'))
  ggplot(d[order(ventas)],
    aes(reorder(jefe_operativo, ventas), ventas)) +
    geom_col(fill = azul, width = 0.65) +
    coord_flip() +
    scale_y_continuous(labels = function(x)
      paste0('$', round(x / 1e6, 1), ' M')) +
    labs(x = NULL, y = 'Ventas') +
    theme_minimal(base_size = 11)
})
```

by = jefe_operativo agrupa los registros y order(-ventas) coloca primero los valores más altos. validate(need()) presenta un mensaje comprensible si el filtro queda sin datos. scale_y_continuous() expresa el eje en millones y coord_flip() mejora la lectura de los nombres.

**Figura 13. Pestaña Tendencias y responsables**

![Elemento visual de la página 30](assets/p30_img_144.jpeg)

*Fuente: elaboración propia en Shiny; se muestra el contenido de la pestaña Tendencias y responsables.*

---

<!-- Página 31 -->

### 7.3. Productos y clientes.

Primero se crean dos resúmenes reactivos. Así, una misma agrupación puede alimentar gráficos o tablas sin repetir el cálculo.

```r
# 7.3 RESÚMENES REACTIVOS
resumen_productos <- reactive(
  datos_filtrados()[, .(
    frecuencia = uniqueN(numero_egreso),
    ventas = sum(valor_venta)
  ), by = producto]
)
resumen_clientes <- reactive(
  datos_filtrados()[,
    .(ventas = sum(valor_venta)), by = cliente]
)
```

En productos, uniqueN() cuenta en cuántos egresos distintos aparece cada artículo y sum() acumula su valor de venta. En clientes se suma el valor comprado. reactive() mantiene ambos resultados actualizados con los filtros superiores.

Después se ordenan los productos por frecuencia y se muestran los diez primeros.

```r
# 7.3 PRODUCTOS DE MAYOR FRECUENCIA
output$grafico_productos <- renderPlot({
  d <- resumen_productos()[order(-frecuencia)][1:10]
  ggplot(d[order(frecuencia)],
    aes(reorder(producto, frecuencia), frecuencia)) +
    geom_col(fill = turquesa, width = 0.68) +
    coord_flip() +
    labs(x = NULL, y = 'Egresos distintos') +
    theme_minimal()
})
```

order(-frecuencia) organiza de mayor a menor y [1:10] conserva el top diez. reorder() acomoda las categorías según su resultado y coord_flip() coloca los nombres en sentido horizontal para facilitar su lectura.

El mismo criterio se aplica para reconocer los clientes con mayor valor acumulado.

```r
# 7.3 CLIENTES CON MAYOR VALOR
output$grafico_clientes <- renderPlot({
  d <- resumen_clientes()[order(-ventas)][1:10]
  ggplot(d[order(ventas)],
    aes(reorder(cliente, ventas), ventas)) +
    geom_col(fill = naranja, width = 0.68) +
    coord_flip() +
    labs(x = NULL, y = 'Valor de ventas') +
    theme_minimal()
})
```

En este caso el orden se basa en ventas. geom_col() representa el valor de cada cliente y renderPlot() actualiza la salida cuando se modifica una selección del dashboard.

---

<!-- Página 32 -->

**Figura 14. Pestaña Productos y clientes**

![Elemento visual de la página 32](assets/p32_img_149.jpeg)

*Fuente: elaboración propia en Shiny; se presentan los gráficos y las tablas de productos y clientes.*

### 7.4. Modelo y calidad.

La primera salida presenta la validación de las relaciones del modelo.

```r
# 7.4 VALIDACIÓN DE RELACIONES
output$tabla_relaciones <- renderTable({
  d <- copy(modelo$validacion_relaciones)
  d[, Estado := ifelse(claves_sin_coincidencia == 0,
                       'APROBADO', 'REVISAR')]
  d
})
```

renderTable() convierte el objeto en una tabla visible en Shiny. ifelse() asigna APROBADO cuando la cantidad de claves sin coincidencia es cero y REVISAR si existe alguna diferencia.

La representación se recalcula con los filtros activos. El primer paso resume el comportamiento de cada cliente mediante cinco variables reales.

---

<!-- Página 33 -->

```r
# 7.4 PERFIL DE CADA CLIENTE
# Este fragmento se ejecuta dentro de reactive().
d <- datos_filtrados()
perfil <- d[, .(
  ventas = sum(valor_venta),
  egresos = uniqueN(numero_egreso),
  ticket_promedio = sum(valor_venta) /
    uniqueN(numero_egreso),
  cantidad_total = sum(cantidad),
  productos_diferentes = uniqueN(producto_id)
), by = .(cliente_id, cliente, empresa)]
```

by agrupa por cliente y empresa. sum() calcula sus ventas y cantidad total, mientras uniqueN() cuenta egresos y productos diferentes. El ticket promedio relaciona las ventas con el número de egresos del cliente.

Luego se estandarizan las variables y se reducen a dos componentes para poder observarlas en un plano.

```r
# 7.4 CÁLCULO DE LOS COMPONENTES
variables <- as.matrix(perfil[, .(
  ventas, egresos, ticket_promedio,
  cantidad_total, productos_diferentes
)])
pca <- prcomp(scale(variables),
  center = FALSE, scale. = FALSE)
perfil[, `:=`(
  componente_1 = pca$x[, 1],
  componente_2 = pca$x[, 2]
)]
```

as.matrix() prepara las variables numéricas; scale() evita que una medida domine por utilizar valores más grandes; y prcomp() calcula los componentes principales. El operador := añade las dos coordenadas al perfil sin crear otra copia completa de la tabla.

Finalmente, cada cliente se presenta como un punto y el color permite distinguir la empresa a la que pertenece.

```r
# 7.4 GRÁFICO DE CLIENTES
output$grafico_clientes_pca <- renderPlot({
  ggplot(perfil_clientes_pca(),
    aes(componente_1, componente_2, color = empresa)) +
    geom_point(alpha = 0.72, size = 2.4) +
    theme_minimal()
})
```

renderPlot() dibuja el resultado actualizado. geom_point() representa a cada cliente y alpha aplica transparencia para que las zonas con varios puntos continúen siendo visibles.

El mapa de calor utiliza todos los registros filtrados y resume las ventas por mes y clasificación.

---

<!-- Página 34 -->

```r
# 7.4 MAPA DE CALOR REACTIVO
output$grafico_calor <- renderPlot({
  d <- datos_filtrados()[, .(ventas = sum(valor_venta)),
                         by = .(mes, clasificacion)]
  ggplot(d, aes(mes, clasificacion, fill = ventas)) +
    geom_tile(color = 'white', linewidth = 1.1) +
    theme_minimal()
})
```

by agrupa las ventas y geom_tile() convierte cada combinación de mes y clasificación en una celda. El color permite reconocer rápidamente los periodos con mayor valor.

**Figura 15. Pestaña Modelo y calidad**

![Elemento visual de la página 34](assets/p34_img_154.jpeg)

*Fuente: elaboración propia en Shiny; se observan el modelo en estrella, la validación, la representación PCA de clientes y el*

*mapa de calor.*

### 7.5. Conclusiones dinámicas.

Las conclusiones se calculan con el mismo subconjunto que se observa en las demás pestañas.

---

<!-- Página 35 -->

```r
# 7.5 HALLAZGOS DEL FILTRO ACTIVO
# Este fragmento se ejecuta dentro de renderUI().
d <- datos_filtrados()
validate(need(nrow(d) > 0,
  'No existen datos para elaborar conclusiones.'))
prod <- d[, .(frecuencia = uniqueN(numero_egreso)),
  by = producto][order(-frecuencia)][1]
cli <- d[, .(ventas = sum(valor_venta)),
  by = cliente][order(-ventas)][1]
jefe <- d[, .(ventas = sum(valor_venta)),
  by = jefe_operativo][order(-ventas)][1]
clase <- d[, .(ventas = sum(valor_venta)),
  by = clasificacion][order(-ventas)][1]
```

validate(need()) comprueba que existan filas. Las agrupaciones identifican el primer producto, cliente, jefe y clasificación después de ordenar cada resultado de mayor a menor; por eso los hallazgos cambian cuando se modifica el filtro.

Los resultados obtenidos se convierten en elementos visibles dentro de la interfaz.

```r
# 7.5 TARJETAS DE CONCLUSIONES
tagList(
  div(class = 'insight',
    p(paste('Producto principal:', prod$producto))),
  div(class = 'insight',
    p(paste('Cliente principal:', cli$cliente))),
  div(class = 'insight',
    p(paste('Jefe principal:', jefe$jefe_operativo))),
  div(class = 'insight',
    p(paste('Clasificación principal:',
      clase$clasificacion)))
)
```

renderUI() permite generar contenido de interfaz desde el servidor. tagList() reúne las cuatro tarjetas, div() asigna su estilo visual y paste() une la etiqueta con el resultado calculado.

---

<!-- Página 36 -->

**Figura 16. Pestaña Conclusiones ejecutivas**

![Elemento visual de la página 36](assets/p36_img_159.jpeg)

*Fuente: elaboración propia en Shiny; los hallazgos se generan con los filtros activos.*

## 8. Validación técnica.

Para comprobar el funcionamiento del modelo se ejecutaron ocho pruebas automáticas. Se verificaron la cantidad de registros, la integridad de las relaciones, la ausencia de duplicados y fechas inválidas, la estandarización de las clasificaciones, la respuesta de los filtros y la coincidencia entre la suma mensual y el total general. Todas las pruebas obtuvieron el estado APROBADO.

| Prueba | Estado | Cumple |
| --- | --- | --- |
| Registros cargados | APROBADO | Sí |
| Claves del modelo relacionadas | APROBADO | Sí |
| KPI con resultado finito | APROBADO | Sí |
| Filtro por fecha y empresa responde | APROBADO | Sí |
| Duplicados exactos posteriores | APROBADO | Sí |
| Fechas inválidas posteriores | APROBADO | Sí |
| Clasificaciones estandarizadas | APROBADO | Sí |
| Coherencia del total general | APROBADO | Sí |

---

<!-- Página 37 -->

La validación se ejecuta al final para impedir que un modelo inconsistente sea utilizado por Shiny. Cada condición produce un valor lógico; si alguna resulta falsa, el script se detiene y solicita revisión. Las ocho comprobaciones aprobadas confirman la carga, las relaciones, los KPI, los filtros, la limpieza y la conciliación del total general.

Primero se genera una muestra que simula una selección real del dashboard.

```r
# 8. PRUEBA DE RESPUESTA DEL FILTRO
muestra_filtro <- fact_ventas[
  fecha_despacho >= min(fecha_despacho) &
  fecha_despacho <= min(fecha_despacho) + 30 &
  empresa == fact_ventas$empresa[1]
]
```

Los corchetes de data.table conservan solamente un mes y una empresa. La prueba será correcta si la muestra contiene registros, pero tiene menos filas que la tabla completa; así se confirma que el filtro realmente modifica el conjunto de datos.

Después se registran las condiciones que comprueban la carga, el modelo, los KPI y la limpieza.

---

<!-- Página 38 -->

```r
# 8. COMPROBACIONES AUTOMÁTICAS
validacion_tecnica <- data.table(
  prueba = c(
    'Registros cargados', 'Relaciones del modelo',
    'KPI finitos', 'Filtro responde',
    'Sin duplicados', 'Fechas válidas',
    'Clasificaciones correctas',
    'Total general coherente'
  ),
  resultado = c(
    nrow(fact_ventas) == 1028304,
    all(validacion_relaciones$claves_sin_coincidencia == 0),
    all(is.finite(c(ventas_totales, numero_egresos,
                    ticket_promedio))),
    nrow(muestra_filtro) > 0 &&
      nrow(muestra_filtro) < nrow(fact_ventas),
    duplicados_despues == 0,
    fechas_invalidas_despues == 0,
    setequal(sort(unique(fact_ventas$clasificacion)),
      c('FRUVER', 'NO PERECIBLE', 'PERECIBLE')),
    isTRUE(all.equal(
      sum(ventas_mensuales$ventas), ventas_totales
    ))
  )
)
```

nrow() verifica la cantidad de filas; all() exige que todas las relaciones sean correctas; is.finite() descarta KPI indefinidos; setequal() compara las clasificaciones sin depender de su orden; y all.equal() concilia la suma mensual con el total, considerando la precisión numérica de R.

Por último, cada resultado lógico se convierte en un estado legible y se detiene la ejecución si existe un error.

```r
# 8. ESTADO FINAL DE LAS PRUEBAS
validacion_tecnica[, estado := ifelse(
  resultado, 'APROBADO', 'REVISAR'
)]
if (!all(validacion_tecnica$resultado)) {
  stop('La validación técnica requiere revisión.')
}
```

ifelse() asigna APROBADO a las condiciones verdaderas y REVISAR a las falsas. El if utiliza all() para revisar el conjunto completo; stop() interrumpe el script cuando alguna prueba no cumple, evitando que Shiny trabaje con un modelo inconsistente.

---

<!-- Página 39 -->

**Figura 17. Código y resultado de la validación técnica**

![Elemento visual de la página 39](assets/p39_img_166.jpeg)

*Fuente: elaboración propia en RStudio; ocho de ocho pruebas aprobadas.*

**Prueba interactiva de filtros.** Con el alcance completo, Shiny mostró USD 20.332.897. Al seleccionar la empresa TECFOOD, el valor cambió a USD 9.096.216; al presionar Limpiar, regresó al total original. Esto confirma que los filtros modifican los KPI y gráficos.

## 9. Conclusión breve.

El procesamiento permitió obtener una base depurada con 1.028.304 registros, un modelo dimensional con relaciones verificadas y un dashboard funcional en Shiny. Los indicadores calculados permiten revisar la evolución mensual de las ventas, los clientes, los productos, los responsables operativos y la participación de cada clasificación.

En el periodo analizado se registraron USD 20,33 millones en ventas, 56.814 egresos y un ticket promedio de USD 357,89. Las pruebas realizadas confirmaron la coherencia de los cálculos y el funcionamiento de los filtros. No fue posible calcular metas, rentabilidad ni resultados por zona, debido a que el archivo no contiene metas comerciales, costos internos ni una dimensión geográfica.
