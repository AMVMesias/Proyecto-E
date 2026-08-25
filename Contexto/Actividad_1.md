# Actividad 1 — Diagnóstico del caso y diseño del plan BI

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
| Actividad | ACTIVIDAD 1 — DIAGNÓSTICO DEL CASO Y DISEÑO DEL PLAN BI |
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

## 1. Descripción del caso.

Hanaska es una empresa ecuatoriana que se dedica a servicios de alimentación colectiva, productos alimenticios y apoyo logístico. Su Centro de Distribución se encarga de mejorar el almacenamiento, el control y el despacho de productos a clientes en todo el país. Esto busca garantizar la trazabilidad y cumplir con los tiempos de entrega.

Para este proyecto, se usarán 1.028.304 registros y 12 variables, obtenidos de los informes del sistema interno Hanastek. La base incluye información sobre las ventas realizadas entre enero y agosto de 2026, abarcando clientes, productos, jefes operativos, cantidades y el precio unitario final cobrado al cliente. Actualmente, soy el jefe del Centro de Distribución, por lo que este análisis se relaciona directamente con las necesidades de información de mi área.

## 2. Problema identificado.

Aunque la organización tiene muchos registros, la información está guardada en hojas de cálculo con fórmulas de búsqueda y en catálogos separados. Este sistema permite ver casos específicos, pero no da una visión general, rápida y clara del comportamiento de las ventas o egresos comerciales del Centro de Distribución.

No hay un tablero que muestre de manera constante la evolución mensual, la distribución por cliente, el desempeño de cada jefe operativo, los productos más o menos vendidos, la distribución entre empresas y la participación que tienen productos Fruver, perecibles y no perecibles. La base permite calcular los ingresos por ventas porque el campo Costo Unitario representa el precio unitario cobrado al cliente. Sin embargo, no dispone de metas comerciales ni del costo interno de los productos, por lo que no es posible calcular el cumplimiento de metas ni la rentabilidad real.

Esto obliga a hacer búsquedas manuales, lo que consume más tiempo para crear reportes y puede provocar que diferentes personas entiendan de forma distinta las mismas métricas.

Como resultado, la jefatura del Centro de Distribución tiene menos capacidad para

---

<!-- Página 3 -->

identificar concentraciones, cambios en las tendencias, productos con mayor impacto en las ventas y oportunidades para mejorar la operación.

Problema central. La información existe, pero no está transformada en indicadores comparables y visualizaciones que apoyen decisiones periódicas sobre clientes, productos, responsables, ventas y tendencias de los egresos (ventas mensuales).

## 3. Usuarios de la solución BI.

Los usuarios que se mencionan aquí han sido seleccionados según el proceso que se ha observado. Los permisos del panel de control deben ajustarse según las responsabilidades dentro de la organización y la privacidad de la información.

| Usuario propuesto | Información que necesita | Decisión que apoyará |
| --- | --- | --- |
| Gerencia de operaciones | Resumen por empresa, clasificación, cliente y periodo. | Evaluar el comportamiento general del centro y definir prioridades de gestión. |
| Jefatura del Centro de Distribución | Volumen y valor de ventas de los egresos, tendencias, clientes y productos de mayor impacto. | Priorizar acciones operativas, revisar desviaciones y orientar recursos. |
| Jefatura de Catálogo | Precio unitario cobrado al cliente, valor total de ventas y variaciones por producto o cliente. | Controlar el impacto económico de los despachos y validar cambios de precio. |
| Abastecimiento y compras | Productos de alta y baja rotación, frecuencia de despacho y valor de ventas. | Ajustar abastecimiento y analizar concentración de demanda. |
| Analista de datos o BI | Calidad, estructura, relaciones y reglas de cálculo de las fuentes. | Mantener el modelo, actualizar el dashboard y asegurar consistencia. |

---

<!-- Página 4 -->

## 4. Preguntas de negocio.

| N.º | Pregunta | Enfoque |
| --- | --- | --- |
| 1 | ¿Cuál es el valor total de las ventas por mes? | Seguimiento mensual |
| 2 | ¿Cuáles son los diez clientes que generan el mayor valor de ventas? | Gestión de clientes |
| 3 | ¿Cuáles son los diez productos con mayor frecuencia de despacho? | Productos de alta rotación |
| 4 | ¿Cuáles son los diez productos con menor frecuencia de despacho? | Productos de baja rotación |
| 5 | ¿Qué jefe operativo registra el mayor valor de ventas? | Gestión de responsables |
| 6 | ¿Cuál es el valor total de las ventas por clasificación: ¿perecibles, no perecibles y Fruver? | Composición de ventas |

---

<!-- Página 5 -->

## 5. KPI propuestos.

| KPI | Fórmula | Fuente | Uso |
| --- | --- | --- | --- |
| Valor total de ventas | Σ (Cantidad × Precio Cliente) | Detalle Ventas | Conocer el ingreso total generado por las ventas. |
| Número de egresos | Conteo distinto de Numero Egreso | Detalle Ventas | Medir la cantidad de egresos o ventas realizadas. |
| Ticket promedio | Valor total de ventas ÷ Número de egresos | Detalle Ventas | Conocer el valor promedio de cada egreso. |
| Variación mensual de ventas | (Ventas del mes actual − Ventas del mes anterior) ÷ Ventas del mes anterior × 100 | Detalle Ventas | Identificar aumentos o disminuciones mensuales. |
| Clientes atendidos | Conteo distinto de Cod-Cliente | Detalle Ventas | Conocer cuántos clientes realizaron compras durante el periodo. |
| Frecuencia de despacho por producto | Conteo distinto de egresos por producto | Detalle Ventas | Identificar productos con mayor y menor frecuencia de despacho. |
| Ventas por jefe operativo | Σ Valor de ventas agrupado por jefe operativo | Detalle Ventas | Comparar los resultados gestionados por cada responsable. |
| Participación por clasificación | Ventas de la clasificación ÷ Ventas totales × 100 | Detalle Ventas | Comparar las ventas de perecibles, no perecibles y Fruver. |

## 6. Fuentes de datos requeridas.

Para desarrollar el proyecto BI se utilizará el archivo de Excel obtenido de la reportería del sistema interno Hanastek. El archivo contiene las siguientes fuentes de información:

| Fuente de datos | Información disponible | Uso en el proyecto |
| --- | --- | --- |
| Detalle Ventas | Número de egreso, fechas, clientes, jefe operativo, empresa, productos, clasificación, cantidad y valor unitario cobrado al cliente. | Calcular las ventas, ingresos, egresos, ticket promedio y variaciones mensuales. |
| Jefe Operativo | Información de clientes, empresas y jefes operativos responsables. | Analizar y comparar las ventas gestionadas por cada jefe operativo. |
| Catálogo | Código, descripción, unidad y clasificación de los productos. | Identificar los productos y clasificarlos como perecibles, no perecibles y Fruver. |
| Calendario | Año, mes y fecha de los egresos. | Analizar las ventas por mes y calcular su variación. Esta tabla se generará en RStudio a partir de FDespacho. |

---

<!-- Página 6 -->

No se utilizarán tablas de zonas o metas, debido a que no forman parte del archivo disponible ni de las preguntas de negocio seleccionadas para este proyecto.

## 7. Diccionario inicial de datos.

| Campo | Descripción | Tipo de dato | Tabla |
| --- | --- | --- | --- |
| Numero Egreso | Código que identifica cada venta. Puede repetirse cuando contiene varios productos. | Numérico/identificador | Detalle Ventas |
| FRegistro | Fecha y hora en que la operación fue registrada en Hanastek. | Fecha y hora | Detalle Ventas |
| FDespacho | Fecha o periodo en que se realizó el despacho. | Fecha | Detalle Ventas |
| Cod- Cliente | Código que identifica al cliente. | Numérico/identificador | Detalle Ventas |
| Cliente | Nombre del cliente que realizó la compra. | Texto | Detalle Ventas |
| Jefe Operativo | Responsable de la gestión del cliente. En el archivo original corresponde al campo Vendedor. | Texto | Detalle Ventas |
| Empresa | Empresa relacionada con el cliente y el egreso. | Texto | Detalle Ventas |
| Item Producto | Código que identifica al producto. | Numérico/identificador | Detalle Ventas |
| Producto | Nombre o descripción del producto vendido. | Texto | Detalle Ventas |
| Clasificación | Clasificación del producto como perecible, no perecible o Fruver. | Texto | Detalle Ventas |
| Cantidad | Cantidad vendida o despachada del producto. | Decimal | Detalle Ventas |
| Precio Cliente | Valor unitario final cobrado al cliente | Decimal/moneda | Detalle Ventas |
| Valor Venta | Ingreso calculado mediante Cantidad × Precio Cliente. | Decimal/moneda | Campo calculado en RStudio |
| Mes | Mes obtenido a partir de FDespacho para realizar el análisis mensual. | Texto | Campo calculado en RStudio |

---

<!-- Página 7 -->

## 8. Alcance del proyecto.

El proyecto consiste en limpiar y analizar los 1.028.304 registros que se obtuvieron del sistema Hanastek. Estos registros corresponden al periodo que va desde enero hasta el 16 de agosto de 2026. Para realizar este análisis, se utilizará RStudio.

En RStudio, se calculará el valor total de las ventas y se desarrollarán ocho indicadores clave de rendimiento, que son los KPI. Además, se prepararán tablas y gráficos para responder a seis preguntas relacionadas con el negocio. Estas preguntas tienen que ver con las ventas mensuales, los clientes, los productos, los jefes operativos y la clasificación de los productos.

El dashboard nos permitirá visualizar varios datos importantes. Por ejemplo, podremos ver el valor total de las ventas por mes. También podremos identificar a los clientes que generan las mayores ventas. Además, se podrán ver los productos que tienen mayor y menor frecuencia de despacho. Otro dato que se podrá visualizar es el total de ventas que cada jefe operativo gestiona.

Asimismo, se podrán ver las ventas de los productos perecibles, no perecibles y Fruver. Y se podrán ver algunos indicadores generales, como el número total de egresos, el ticket promedio y el número de clientes atendidos.

El proyecto no tendrá conexión automática con Hanastek, ni análisis de inventarios, ni predicciones de ventas, ni datos de otros periodos. Además, no se podrá calcular la rentabilidad real de los productos porque el informe que se descarga de Hanastek no incluye el costo interno de cada producto y no hay acceso a esa información.

---

<!-- Página 8 -->

## 9. Plan de trabajo.

El proyecto se desarrollará en cuatro semanas, desde el diagnóstico inicial hasta la presentación de resultados.

| Fase | Actividad | Producto | Semana |
| --- | --- | --- | --- |
| 1 | Diagnóstico del caso y definición de preguntas de negocio, KPI y alcance. | Documento de requisitos del proyecto BI. | 1 |
| 2 | Limpieza y preparación de la base descargada de Hanastek en RStudio. | Base de datos depurada con campos calculados. | 1 y 2 |
| 3 | Organización de las tablas y creación de variables para el análisis, como valor de venta y mes. | Modelo de datos para el análisis. | 2 |
| 4 | Diseño y elaboración del dashboard con gráficos e indicadores. | Tablero ejecutivo en RStudio. | 3 |
| 5 | Análisis de resultados, conclusiones y recomendaciones. | Informe final y presentación del proyecto. | 4 |

---

<!-- Página 9 -->

## 10. Conclusión breve.

El proyecto de inteligencia de negocios permitirá transformar los 1.028.304 registros obtenidos de Hanastek en información clara para el Centro de Distribución de Hanaska.

Mediante RStudio se elaborará un dashboard que facilitará el seguimiento de las ventas, los clientes, los productos, los jefes operativos y las clasificaciones de productos.

Esta solución reducirá el uso de filtros y cálculos manuales, mejorando el tiempo de análisis y apoyando la toma de decisiones del gerente y jefe de Operaciones. Aunque no se calculará la rentabilidad real por falta de información sobre costos internos, el proyecto permitirá conocer los ingresos generados y detectar aspectos relevantes para la gestión comercial y operativa.
