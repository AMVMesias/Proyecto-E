# Macroactividad - Proyecto BI final

Esta carpeta amplía la Actividad 2 sin alterar sus archivos. El script
`scripts/macro_bi.R` carga el modelo depurado local, compara tres alternativas
de pronóstico con cuatro ventanas temporales, segmenta clientes y productos,
genera rankings comerciales, guarda evidencias gráficas y valida las salidas.

## Ejecución

1. Ejecutar `source("scripts/macro_bi.R")` desde RStudio, con este directorio
   como directorio de trabajo.
2. Ejecutar `source("iniciar_shiny.R")` para abrir el dashboard final con la
   codificación adecuada para los textos en español.

El script requiere los paquetes `data.table`, `ggplot2` y `cluster`. El modelo
de la Actividad 2 y la base depurada se encuentran en `data`, por lo que la
carpeta puede procesarse sin depender de una ruta externa.

## Salidas principales

- `data/modelo_macro.rds`: modelo final consumido por Shiny.
- `salidas/comparacion_modelos_pronostico.csv`: comparación de MAE, RMSE y WAPE.
- `salidas/ranking_productos_valor.csv`: impacto económico por producto.
- `salidas/ranking_productos_frecuencia.csv`: rotación por frecuencia de egresos.
- `salidas/ranking_clientes_valor.csv`: clientes ordenados por valor de ventas.
- `salidas/sensibilidad_segmentacion_productos.csv`: estabilidad de los segmentos temporales.
- `salidas/validacion_macro.csv`: controles automáticos de la ejecución.
- `evidencias`: gráficos generados directamente desde R y capturas finales del dashboard.
