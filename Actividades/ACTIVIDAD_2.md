# Asignatura

**PROYECTOS DE INTELIGENCIA DE NEGOCIOS**

# Actividad 2: Preparación de datos y prototipo del modelo BI

<!-- Página 1 -->

## 1. Nombre de la actividad

**Datos, ETL y modelo BI**

## 2. Propósito de la actividad

La actividad tiene como finalidad que el estudiante prepare técnicamente los datos que serán usados en la macroactividad final. Para ello, deberá limpiar la base de datos, aplicar un proceso ETL básico, diseñar el modelo de datos y elaborar un prototipo inicial del dashboard.

Esta actividad es fundamental porque permite verificar si los datos son consistentes, si las relaciones entre tablas son correctas y si los indicadores definidos en la actividad anterior pueden calcularse de manera confiable.

## 3. Caso real

La empresa ya entregó al consultor BI varios archivos de datos: ventas, productos, clientes, vendedores, zonas y metas. Sin embargo, los archivos contienen errores frecuentes: campos vacíos, nombres duplicados, fechas con formatos distintos, códigos incompletos y valores inconsistentes.

El estudiante deberá limpiar, transformar e integrar los datos para dejarlos listos antes de construir el dashboard final.

## 4. Resultado de aprendizaje esperado

El estudiante prepara una base de datos estructurada mediante procesos de limpieza, transformación e integración, y diseña un modelo BI básico para el análisis de indicadores comerciales.

<!-- Página 2 -->

## 5. Instrucciones para el estudiante

El estudiante deberá trabajar con datos reales o simulados del caso empresarial. Puede utilizar Power BI, Rstudio, Excel Power Query, Tableau Prep, SQL, Python u otra herramienta equivalente.

### 5.1. Revisión inicial de datos

Analizar los archivos entregados e identificar problemas de calidad. Se debe revisar:

- Datos duplicados.
- Datos vacíos.
- Errores en fechas.
- Valores atípicos.
- Códigos incompletos.
- Categorías mal escritas.
- Campos innecesarios.
- Inconsistencias entre tablas.

### 5.2. Limpieza de datos

Aplicar acciones correctivas para mejorar la calidad de la información:

- Eliminar registros duplicados.
- Completar o justificar datos faltantes.
- Corregir formatos de fecha.
- Estandarizar nombres de productos, zonas y vendedores.
- Unificar categorías.
- Validar valores numéricos.
- Crear campos calculados cuando sea necesario.

### 5.3. Proceso ETL

Documentar el proceso de extracción, transformación y carga de datos.

| Etapa | Acción esperada | Evidencia |
|---|---|---|
| Extracción | Importar datos desde las fuentes disponibles | Captura o descripción |
| Transformación | Limpiar, ordenar y corregir datos | Tabla antes/después |
| Carga | Integrar datos en el modelo BI | Captura del modelo |

<!-- Página 3 -->

### 5.4. Diseño del modelo de datos

Construir un modelo simple que permita analizar ventas, productos, clientes, vendedores, zonas, fechas y metas.

Modelo sugerido:

- Tabla de hechos: ventas.
- Dimensión 1: productos.
- Dimensión 2: clientes.
- Dimensión 3: vendedores.
- Dimensión 4: zonas.
- Dimensión 5: calendario.
- Dimensión 6: metas.

El estudiante debe establecer relaciones correctas entre las tablas y justificar brevemente su estructura.

### 5.5. Creación de medidas o cálculos iniciales

Construir al menos seis medidas o cálculos, según la herramienta utilizada. Ejemplos:

- Ventas totales.
- Número de ventas.
- Ticket promedio.
- Cumplimiento de meta.
- Variación mensual.
- Ventas por vendedor.
- Ventas por zona.
- Margen de utilidad.
- Media y varianza
- Covarianza y correlación

### 5.6. Prototipo inicial del dashboard

Diseñar un bosquejo o primera versión del dashboard. No es necesario que sea el tablero final, pero debe evidenciar la estructura visual que tendrá la macroactividad.

El prototipo debe incluir:

- Área de KPI principales.
- Gráfico de tendencia mensual.

<!-- Página 4 -->

- Ranking de productos.
- Cumplimiento de metas.
- Filtros por fecha, zona, producto o vendedor.
- Espacio para conclusiones ejecutivas.

### 5.7. Validación técnica

Verificar que los datos cargados permitan responder las preguntas de negocio planteadas en la actividad previa 1. El estudiante debe comprobar que:

- Las relaciones entre tablas funcionan.
- Los filtros modifican los gráficos.
- Los KPI se calculan correctamente.
- No existen errores evidentes en los datos.
- Los resultados son coherentes con el caso.

## 6. Producto entregable

El estudiante deberá entregar:

1. Archivo de datos limpio.
2. Archivo de trabajo en la herramienta BI utilizada.
3. Captura o evidencia del proceso ETL.
4. Captura del modelo de datos.
5. Tabla de medidas o cálculos creados.
6. Prototipo inicial del dashboard.
7. Documento breve de explicación técnica.

## 7. Estructura del documento técnico

El documento debe contener:

1. Portada.
2. Descripción de las fuentes de datos.
3. Problemas de calidad encontrados.
4. Acciones de limpieza aplicadas.
5. Proceso ETL documentado.
6. Modelo de datos.
7. Medidas o cálculos creados.
8. Prototipo del dashboard.
9. Validación técnica.
10. Conclusión breve.

<!-- Página 5 -->

## 8. Evidencias mínimas

- Base depurada.
- Registro de cambios aplicados a los datos.
- Modelo de datos con relaciones.
- Medidas creadas.
- Prototipo visual del dashboard.
- Validación de KPI.

# Rúbrica de evaluación de la actividad 2

| Criterio de evaluación | Descripción del desempeño esperado | Puntaje |
|---|---|---:|
| Revisión de calidad de datos | Identifica errores, duplicados, vacíos, inconsistencias y problemas de formato en las bases utilizadas. | 15 |
| Limpieza y transformación de datos | Aplica correcciones técnicas adecuadas y deja los datos listos para el análisis BI. | 20 |
| Documentación del proceso ETL | Explica claramente las fases de extracción, transformación y carga, con evidencias suficientes. | 15 |
| Diseño del modelo de datos | Construye un modelo funcional con tablas relacionadas de manera lógica y coherente. | 15 |
| Creación de medidas o cálculos | Genera indicadores básicos correctamente calculados y alineados con las preguntas de negocio. | 10 |
| Prototipo inicial del dashboard | Presenta una estructura visual clara, ordenada y pertinente para la futura macroactividad. | 10 |
| Validación técnica | Comprueba que los datos, relaciones, filtros e indicadores funcionen correctamente. | 10 |
| Presentación técnica del entregable | Organiza los archivos y el documento con claridad, orden y redacción técnica. | 5 |
| **Total** |  | **100** |
