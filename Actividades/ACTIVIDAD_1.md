# Asignatura

**PROYECTOS DE INTELIGENCIA DE NEGOCIOS**

# Actividad 1: Diagnóstico del caso y diseño del plan BI

<!-- Página 1 -->

## 1. Nombre de la actividad

**Diagnóstico del caso y plan BI**

## 2. Propósito de la actividad

La actividad tiene como finalidad que el estudiante comprenda el problema real de una empresa, identifique sus necesidades de información y diseñe el plan inicial del proyecto de inteligencia de negocios. Esta actividad prepara la macroactividad final, porque permite definir qué datos se necesitan, qué preguntas debe responder el dashboard y qué indicadores serán usados para la toma de decisiones.

## 3. Caso real

Una empresa comercial registra sus ventas en hojas de cálculo separadas por vendedor, producto, zona y mes. Sin embargo, la gerencia no cuenta con una visión clara del desempeño general del negocio. Existen dudas sobre el cumplimiento de metas, los productos con mayor rotación, las zonas con bajo rendimiento y los vendedores con mejores resultados.

Frente a esta situación, el estudiante deberá actuar como consultor BI y elaborar un diagnóstico inicial del caso. El propósito es definir el problema, los usuarios, las preguntas de negocio, los datos requeridos, los KPI y el plan básico de trabajo para desarrollar posteriormente la solución BI.

## 4. Resultado de aprendizaje esperado

El estudiante define el alcance inicial de un proyecto BI mediante el análisis del problema empresarial, la identificación de requisitos de información y la selección de indicadores clave para la toma de decisiones.

## 5. Instrucciones para el estudiante

El estudiante deberá elaborar un documento técnico breve que contenga los siguientes apartados:

<!-- Página 2 -->

### 5.1. Descripción del problema

Redactar una explicación clara del problema que enfrenta la empresa. Debe indicar qué información no está disponible, qué decisiones no pueden tomarse con precisión y qué consecuencias genera la falta de un sistema BI.

### 5.2. Identificación de usuarios

Determinar quiénes utilizarán la solución BI. Por ejemplo:

- Gerente general.
- Jefe comercial.
- Coordinador de ventas.
- Analista de datos.
- Supervisores de zona.

Para cada usuario, se debe explicar qué información necesita y para qué decisión la utilizará.

### 5.3. Preguntas de negocio

Formular al menos seis preguntas que el dashboard deberá responder. Ejemplos:

- ¿Cuáles son las ventas totales por mes?
- ¿Qué vendedor cumple mejor sus metas?
- ¿Qué productos generan mayor ingreso?
- ¿Qué zona tiene menor desempeño?
- ¿Qué canal de venta aporta más ingresos?
- ¿Cuál es la variación mensual de ventas?
- ¿De qué tipo de variables se compone el dataset?
- ¿Qué tipo de relación (+ o -) tiene el total de ventas?
- ¿Qué tan estrecha es esta relación?
- ¿Qué tipo de información aporta la media y varianza?
- ¿Cuáles son los productos más vendidos? Generar Top
- ¿Cuáles son los productos menos vendidos? Generar Top

### 5.4. Definición de KPI

Seleccionar al menos ocho indicadores clave. Cada KPI debe incluir:

- Nombre del indicador.
- Fórmula básica.
- Fuente de datos necesaria.
- Uso para la toma de decisiones.

<!-- Página 3 -->

Ejemplo:

| KPI | Fórmula | Fuente | Uso |
|---|---|---|---|
| Ventas totales | Suma de ventas | Tabla ventas | Medir ingreso general |
| Cumplimiento de meta | Ventas / Meta x 100 | Ventas y metas | Evaluar desempeño comercial |
| Ticket promedio | Ventas / Número de ventas | Tabla ventas | Analizar valor medio de compra |

### 5.5. Fuentes de datos requeridas

Definir las tablas o archivos necesarios para construir el proyecto BI. Se recomienda incluir:

- Ventas.
- Productos.
- Clientes.
- Vendedores.
- Zonas.
- Metas.
- Calendario.

### 5.6. Diccionario inicial de datos

Construir una tabla con los campos principales que se utilizarán en el proyecto.

Ejemplo:

| Campo | Descripción | Tipo de dato | Tabla |
|---|---|---|---|
| id_venta | Código único de venta | Numérico | Ventas |
| fecha | Fecha de la venta | Fecha | Ventas |
| producto | Nombre del producto | Texto | Productos |
| vendedor | Nombre del vendedor | Texto | Vendedores |
| valor_venta | Monto vendido | Decimal | Ventas |

### 5.7. Alcance del proyecto BI

Explicar qué incluirá y qué no incluirá el proyecto. El alcance debe ser realista y posible de ejecutar.

### 5.8. Plan de trabajo

Diseñar un cronograma breve con las fases del proyecto:

<!-- Página 4 -->

| Fase | Actividad | Producto |
|---:|---|---|
| 1 | Diagnóstico del caso | Documento de requisitos |
| 2 | Limpieza de datos | Base depurada |
| 3 | Modelo de datos | Relaciones entre tablas |
| 4 | Dashboard | Tablero ejecutivo |
| 5 | Informe | Hallazgos y recomendaciones |

## 6. Producto entregable

El estudiante deberá entregar un documento en formato Word o PDF con la siguiente estructura:

1. Portada.
2. Descripción del caso.
3. Problema identificado.
4. Usuarios de la solución BI.
5. Preguntas de negocio.
6. KPI propuestos.
7. Fuentes de datos requeridas.
8. Diccionario inicial de datos.
9. Alcance del proyecto.
10. Plan de trabajo.
11. Conclusión breve.

## 7. Evidencias mínimas

- Documento técnico completo.
- Tabla de preguntas de negocio.
- Matriz de KPI.
- Diccionario inicial de datos.
- Cronograma básico del proyecto.

<!-- Página 5 -->

# Rúbrica de evaluación de la actividad 1

| Criterio de evaluación | Descripción del desempeño esperado | Puntaje |
|---|---|---:|
| Comprensión del caso real | Describe con claridad el problema empresarial, sus causas y sus efectos en la toma de decisiones. | 15 |
| Identificación de usuarios y necesidades | Reconoce los usuarios clave del dashboard y explica qué información requiere cada uno. | 10 |
| Formulación de preguntas de negocio | Plantea preguntas claras, pertinentes y alineadas con la gestión comercial de la empresa. | 15 |
| Definición de KPI | Selecciona indicadores útiles, formula correctamente su cálculo y explica su uso gerencial. | 20 |
| Identificación de fuentes de datos | Determina las tablas o archivos necesarios para construir la solución BI. | 10 |
| Diccionario inicial de datos | Presenta campos claros, tipos de datos adecuados y relación con las tablas del proyecto. | 10 |
| Alcance y plan de trabajo | Define un alcance viable y organiza las fases del proyecto de forma lógica. | 10 |
| Presentación técnica del documento | El documento tiene orden, coherencia, redacción clara y formato académico. | 10 |
| **Total** |  | **100** |
