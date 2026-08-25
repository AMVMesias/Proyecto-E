# Macroactividad - Proyecto BI final

Esta carpeta amplía la Actividad 2 sin alterar sus archivos. El script
`scripts/macro_bi.R` carga el modelo depurado, calcula la predicción diaria,
segmenta clientes y productos, guarda resultados y valida las salidas.

## Ejecución

1. Ejecutar `source("scripts/macro_bi.R")` desde RStudio, con este directorio
   como directorio de trabajo.
2. Ejecutar `shiny::runApp()` para abrir el dashboard final.

El script requiere los paquetes `data.table`, `ggplot2` y `cluster`. El modelo
de la Actividad 2 se localiza automáticamente en la estructura del proyecto.
