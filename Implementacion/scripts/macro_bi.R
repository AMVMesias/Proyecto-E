# =============================================================================
# MACROACTIVIDAD - ANALISIS COMERCIAL FINAL
# Proyectos de Inteligencia de Negocios
#
# Este script reutiliza el modelo depurado de la Actividad 2 y añade tres
# componentes de la Macroactividad: prediccion diaria, segmentacion de clientes
# y segmentacion temporal de productos. Las salidas quedan guardadas para el
# dashboard, el informe y la validacion tecnica.
# =============================================================================

paquetes_requeridos <- c("data.table", "ggplot2", "cluster")
paquetes_faltantes <- paquetes_requeridos[
  !vapply(paquetes_requeridos, requireNamespace, logical(1), quietly = TRUE)
]
if (length(paquetes_faltantes)) {
  stop(
    "Faltan paquetes de R: ", paste(paquetes_faltantes, collapse = ", "),
    ". Instálelos antes de ejecutar la Macroactividad.",
    call. = FALSE
  )
}

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(cluster)
})

# -----------------------------------------------------------------------------
# 1. CONFIGURACION Y CARGA DEL MODELO BASE
# -----------------------------------------------------------------------------
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
if (length(script_arg)) {
  script_path <- sub("^--file=", "", script_arg[1])
  project_dir <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
} else {
  project_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}
workspace_dir <- normalizePath(file.path(project_dir, "..", ".."), winslash = "/", mustWork = TRUE)

ruta_configurada <- Sys.getenv("MACRO_MODELO_BI", unset = "")
candidatos_modelo <- c(
  if (nzchar(ruta_configurada)) ruta_configurada,
  file.path(project_dir, "data", "modelo_bi.rds"),
  file.path(workspace_dir, "002 Deberes", "Actividad 2 - R y Shiny", "data", "modelo_bi.rds")
)
candidatos_modelo <- unique(candidatos_modelo[nzchar(candidatos_modelo)])
coincidencias_modelo <- candidatos_modelo[file.exists(candidatos_modelo)]
if (!length(coincidencias_modelo)) {
  stop("No se encontró el modelo_bi.rds de la Actividad 2.", call. = FALSE)
}

ruta_modelo <- normalizePath(coincidencias_modelo[1], winslash = "/", mustWork = TRUE)
dir_data <- file.path(project_dir, "data")
dir_salidas <- file.path(project_dir, "salidas")
dir_evidencias <- file.path(project_dir, "evidencias")
dir.create(dir_data, recursive = TRUE, showWarnings = FALSE)
dir.create(dir_salidas, recursive = TRUE, showWarnings = FALSE)
dir.create(dir_evidencias, recursive = TRUE, showWarnings = FALSE)

modelo_base <- readRDS(ruta_modelo)
ventas <- as.data.table(copy(modelo_base$fact_ventas))
setorder(ventas, fecha_despacho)
fecha_corte <- max(ventas$fecha_despacho)
fecha_inicio <- min(ventas$fecha_despacho)

azul <- "#082E6D"
celeste <- "#00A6D6"
turquesa <- "#10B8A6"
naranja <- "#F59E0B"
gris <- "#475569"

moneda <- function(x, decimales = 0) {
  paste0("$", format(round(x, decimales), big.mark = ",", nsmall = decimales, scientific = FALSE))
}

guardar_csv <- function(datos, nombre) {
  fwrite(datos, file.path(dir_salidas, nombre), sep = ";", bom = TRUE)
}

# -----------------------------------------------------------------------------
# 2. CALENDARIO DIARIO Y CONTROL DEL PERIODO PARCIAL
# -----------------------------------------------------------------------------
calendario_diario <- data.table(
  fecha_despacho = as.IDate(seq(as.Date(fecha_inicio), as.Date(fecha_corte), by = "day"))
)
ventas_diarias_observadas <- ventas[, .(
  ventas = sum(valor_venta),
  egresos = uniqueN(numero_egreso),
  clientes = uniqueN(cliente_id)
), by = fecha_despacho]
ventas_diarias <- merge(calendario_diario, ventas_diarias_observadas,
                         by = "fecha_despacho", all.x = TRUE)
for (campo in c("ventas", "egresos", "clientes")) {
  set(ventas_diarias, which(is.na(ventas_diarias[[campo]])), campo, 0)
}

dias_es <- c("DOMINGO", "LUNES", "MARTES", "MIERCOLES", "JUEVES", "VIERNES", "SABADO")
ventas_diarias[, `:=`(
  indice = .I,
  mes = as.IDate(format(fecha_despacho, "%Y-%m-01")),
  dia_semana = factor(dias_es[as.integer(format(fecha_despacho, "%w")) + 1],
                      levels = c("LUNES", "MARTES", "MIERCOLES", "JUEVES", "VIERNES", "SABADO", "DOMINGO")),
  actividad_registrada = ventas > 0
)]

ventas_mensuales_macro <- ventas_diarias[, .(
  ventas = sum(ventas),
  egresos = sum(egresos),
  dias_observados = .N,
  dias_con_actividad = sum(actividad_registrada)
), by = mes][order(mes)]
# El inicio del mes siguiente menos el inicio del mes actual entrega sus días.
dias_mes <- function(fecha_mes) {
  inicio <- as.IDate(format(fecha_mes, "%Y-%m-01"))
  inicio_siguiente <- as.IDate(format(inicio + 32, "%Y-%m-01"))
  as.integer(inicio_siguiente - inicio)
}
ventas_mensuales_macro[, dias_del_mes := dias_mes(mes)]
ventas_mensuales_macro[, estado_periodo := fifelse(
  mes == as.IDate(format(fecha_corte, "%Y-%m-01")) & dias_observados < dias_del_mes,
  "PARCIAL", "COMPLETO"
)]
ventas_mensuales_macro[, variacion_mensual := fifelse(
  estado_periodo == "COMPLETO" & shift(estado_periodo) == "COMPLETO",
  (ventas / shift(ventas) - 1) * 100,
  NA_real_
)]

meses_completos <- ventas_mensuales_macro[estado_periodo == "COMPLETO", mes]
guardar_csv(ventas_mensuales_macro, "ventas_mensuales_macro.csv")

# -----------------------------------------------------------------------------
# 3. PREDICCION DIARIA DE VENTAS
#
# Se utiliza una regresion sobre log(ventas + 1) con tendencia y dia de semana.
# El componente semanal representa el calendario operativo identificado en los
# registros. La evaluacion se realiza sobre los ultimos 28 dias observados.
# -----------------------------------------------------------------------------
horizonte_pronostico <- 30L
n_prueba <- 28L
if (nrow(ventas_diarias) <= n_prueba + 30L) {
  stop("No hay suficientes dias para validar la prediccion.", call. = FALSE)
}

indice_entrenamiento <- seq_len(nrow(ventas_diarias) - n_prueba)
indice_prueba <- (max(indice_entrenamiento) + 1L):nrow(ventas_diarias)
entrenamiento <- copy(ventas_diarias[indice_entrenamiento])
prueba <- copy(ventas_diarias[indice_prueba])

modelo_pronostico_validacion <- lm(log1p(ventas) ~ indice + dia_semana, data = entrenamiento)
pred_prueba <- predict(modelo_pronostico_validacion, newdata = prueba, interval = "prediction", level = 0.80)
prueba[, `:=`(
  ventas_proyectadas = pmax(0, exp(pred_prueba[, "fit"]) - 1),
  limite_inferior = pmax(0, exp(pred_prueba[, "lwr"]) - 1),
  limite_superior = pmax(0, exp(pred_prueba[, "upr"]) - 1)
)]

metricas_pronostico <- data.table(
  metrica = c("MAE", "RMSE", "WAPE", "Cobertura del intervalo al 80%"),
  resultado = c(
    mean(abs(prueba$ventas - prueba$ventas_proyectadas)),
    sqrt(mean((prueba$ventas - prueba$ventas_proyectadas)^2)),
    sum(abs(prueba$ventas - prueba$ventas_proyectadas)) / sum(prueba$ventas),
    mean(prueba$ventas >= prueba$limite_inferior & prueba$ventas <= prueba$limite_superior) * 100
  )
)

modelo_pronostico_final <- lm(log1p(ventas) ~ indice + dia_semana, data = ventas_diarias)
fechas_futuras <- data.table(
  fecha_despacho = as.IDate(seq(as.Date(fecha_corte) + 1, by = "day", length.out = horizonte_pronostico))
)
fechas_futuras[, `:=`(
  indice = max(ventas_diarias$indice) + .I,
  dia_semana = factor(dias_es[as.integer(format(fecha_despacho, "%w")) + 1],
                      levels = levels(ventas_diarias$dia_semana))
)]
pred_futuro <- predict(modelo_pronostico_final, newdata = fechas_futuras, interval = "prediction", level = 0.80)
pronostico_ventas <- fechas_futuras[, .(fecha_despacho, dia_semana)]
pronostico_ventas[, `:=`(
  ventas_proyectadas = pmax(0, exp(pred_futuro[, "fit"]) - 1),
  limite_inferior = pmax(0, exp(pred_futuro[, "lwr"]) - 1),
  limite_superior = pmax(0, exp(pred_futuro[, "upr"]) - 1)
)]
pronostico_resumen <- data.table(
  indicador = c("Fecha de corte", "Horizonte", "Venta proyectada acumulada", "Promedio diario proyectado"),
  resultado = c(
    as.character(fecha_corte),
    paste0(horizonte_pronostico, " dias"),
    moneda(sum(pronostico_ventas$ventas_proyectadas)),
    moneda(mean(pronostico_ventas$ventas_proyectadas))
  )
)
guardar_csv(pronostico_ventas, "prediccion_ventas.csv")
guardar_csv(prueba, "validacion_pronostico_diario.csv")
guardar_csv(metricas_pronostico, "metricas_pronostico.csv")
guardar_csv(pronostico_resumen, "resumen_pronostico.csv")

# -----------------------------------------------------------------------------
# 4. SEGMENTACION DE CLIENTES
#
# Se resumen recencia, frecuencia, valor, ticket y diversidad. La cantidad de
# grupos se selecciona por el mayor promedio de silueta entre 2 y 6 grupos.
# -----------------------------------------------------------------------------
perfil_clientes <- ventas[, .(
  recencia_dias = as.integer(fecha_corte - max(fecha_despacho)),
  frecuencia_egresos = uniqueN(numero_egreso),
  ventas = sum(valor_venta),
  ticket_promedio = sum(valor_venta) / uniqueN(numero_egreso),
  productos_diferentes = uniqueN(producto_id),
  dias_activos = uniqueN(fecha_despacho)
), by = .(cliente_id, cliente, empresa)]

variables_clientes <- c("recencia_dias", "frecuencia_egresos", "ventas",
                        "ticket_promedio", "productos_diferentes", "dias_activos")
matriz_clientes <- scale(as.matrix(perfil_clientes[, lapply(.SD, log1p), .SDcols = variables_clientes]))
distancia_clientes <- dist(matriz_clientes)
set.seed(20260824)
evaluacion_k <- rbindlist(lapply(2:6, function(k) {
  ajuste <- kmeans(matriz_clientes, centers = k, nstart = 50, iter.max = 100)
  data.table(k = k, silueta_promedio = mean(silhouette(ajuste$cluster, distancia_clientes)[, 3]))
}))
k_optimo <- evaluacion_k[which.max(silueta_promedio), k]
set.seed(20260824)
ajuste_clientes <- kmeans(matriz_clientes, centers = k_optimo, nstart = 100, iter.max = 200)
perfil_clientes[, cluster := ajuste_clientes$cluster]

resumen_cluster <- perfil_clientes[, .(
  clientes = .N,
  ventas = sum(ventas),
  frecuencia_promedio = mean(frecuencia_egresos),
  ticket_promedio = mean(ticket_promedio),
  recencia_promedio = mean(recencia_dias),
  productos_promedio = mean(productos_diferentes)
), by = cluster]
resumen_cluster[, puntaje_estrategico := frank(ventas, ties.method = "average") +
  frank(frecuencia_promedio, ties.method = "average") +
  frank(productos_promedio, ties.method = "average") -
  frank(recencia_promedio, ties.method = "average")]
resumen_cluster[, segmento := "Clientes de desarrollo"]
resumen_cluster[which.max(puntaje_estrategico), segmento := "Clientes estrategicos"]
restantes <- resumen_cluster[segmento != "Clientes estrategicos", cluster]
if (length(restantes)) {
  reactivar_cluster <- resumen_cluster[cluster %in% restantes][which.max(recencia_promedio), cluster]
  resumen_cluster[cluster == reactivar_cluster, segmento := "Clientes por reactivar"]
}
restantes <- resumen_cluster[segmento == "Clientes de desarrollo", cluster]
if (length(restantes)) {
  setorder(resumen_cluster, -frecuencia_promedio, -ventas)
  for (i in seq_along(restantes)) {
    etiqueta <- if (i == 1L) "Clientes frecuentes de desarrollo" else "Clientes de desarrollo"
    resumen_cluster[cluster == restantes[i], segmento := etiqueta]
  }
}
setorder(resumen_cluster, cluster)
perfil_clientes <- merge(perfil_clientes, resumen_cluster[, .(cluster, segmento)], by = "cluster", all.x = TRUE)
setcolorder(perfil_clientes, c("cliente_id", "cliente", "empresa", "segmento", "recencia_dias",
                               "frecuencia_egresos", "ventas", "ticket_promedio",
                               "productos_diferentes", "dias_activos", "cluster"))
resumen_segmentos_clientes <- perfil_clientes[, .(
  clientes = .N,
  ventas = sum(ventas),
  participacion_ventas = sum(ventas) / sum(perfil_clientes$ventas) * 100,
  frecuencia_promedio = mean(frecuencia_egresos),
  ticket_promedio = mean(ticket_promedio),
  recencia_promedio = mean(recencia_dias),
  productos_promedio = mean(productos_diferentes)
), by = segmento][order(-ventas)]
guardar_csv(evaluacion_k, "evaluacion_segmentacion_clientes.csv")
guardar_csv(perfil_clientes, "segmentacion_clientes.csv")
guardar_csv(resumen_segmentos_clientes, "resumen_segmentacion_clientes.csv")

# -----------------------------------------------------------------------------
# 5. SEGMENTACION TEMPORAL DE PRODUCTOS
#
# Se consideran los meses completos. Cada producto se clasifica por continuidad,
# cambio entre inicio y cierre del periodo y variabilidad de su serie mensual.
# -----------------------------------------------------------------------------
ventas_producto_mes <- ventas[mes %in% meses_completos, .(
  ventas = sum(valor_venta),
  egresos = uniqueN(numero_egreso),
  cantidad = sum(cantidad)
), by = .(producto_id, producto, clasificacion, mes)]
productos <- unique(ventas[, .(producto_id, producto, clasificacion)])
base_producto_mes <- CJ(producto_id = productos$producto_id, mes = meses_completos, unique = TRUE)
base_producto_mes <- merge(base_producto_mes, productos, by = "producto_id", all.x = TRUE)
serie_producto <- merge(base_producto_mes, ventas_producto_mes,
                        by = c("producto_id", "producto", "clasificacion", "mes"), all.x = TRUE)
for (campo in c("ventas", "egresos", "cantidad")) {
  set(serie_producto, which(is.na(serie_producto[[campo]])), campo, 0)
}
setorder(serie_producto, producto_id, mes)
serie_producto[, indice_mes := seq_len(.N), by = producto_id]

resumen_temporal_productos <- serie_producto[, .(
  ventas_total = sum(ventas),
  egresos_total = sum(egresos),
  meses_activos = sum(ventas > 0),
  variabilidad = fifelse(mean(ventas) > 0, sd(ventas) / mean(ventas), NA_real_),
  promedio_primeros_tres = mean(ventas[1:min(3, .N)]),
  promedio_ultimos_tres = mean(tail(ventas, min(3, .N)))
), by = .(producto_id, producto, clasificacion)]
resumen_temporal_productos[, cambio_tendencia := fifelse(
  promedio_primeros_tres > 0,
  (promedio_ultimos_tres / promedio_primeros_tres - 1) * 100,
  NA_real_
)]
resumen_temporal_productos[, segmento_temporal := fcase(
  meses_activos <= 3, "Demanda intermitente",
  !is.na(cambio_tendencia) & cambio_tendencia >= 25, "Demanda creciente",
  !is.na(cambio_tendencia) & cambio_tendencia <= -25, "Demanda decreciente",
  !is.na(variabilidad) & variabilidad <= 0.45, "Demanda estable",
  default = "Demanda variable"
)]
resumen_segmentos_productos <- resumen_temporal_productos[, .(
  productos = .N,
  ventas = sum(ventas_total),
  participacion_ventas = sum(ventas_total) / sum(resumen_temporal_productos$ventas_total) * 100,
  ventas_promedio_producto = mean(ventas_total),
  meses_activos_promedio = mean(meses_activos)
), by = segmento_temporal][order(-ventas)]
guardar_csv(serie_producto, "serie_mensual_productos.csv")
guardar_csv(resumen_temporal_productos, "segmentacion_productos.csv")
guardar_csv(resumen_segmentos_productos, "resumen_segmentacion_productos.csv")

# -----------------------------------------------------------------------------
# 6. EVIDENCIAS VISUALES
# -----------------------------------------------------------------------------
historial_pronostico <- rbindlist(list(
  ventas_diarias[, .(fecha_despacho, tipo = "Observado", ventas = ventas)],
  pronostico_ventas[, .(fecha_despacho, tipo = "Proyectado", ventas = ventas_proyectadas)]
))
grafico_pronostico <- ggplot() +
  geom_line(data = ventas_diarias, aes(as.Date(fecha_despacho), ventas), color = azul, linewidth = 0.7) +
  geom_ribbon(data = pronostico_ventas,
              aes(as.Date(fecha_despacho), ymin = limite_inferior, ymax = limite_superior),
              fill = celeste, alpha = 0.22) +
  geom_line(data = pronostico_ventas, aes(as.Date(fecha_despacho), ventas_proyectadas),
            color = naranja, linewidth = 1) +
  geom_vline(xintercept = as.Date(fecha_corte), linetype = "dashed", color = gris) +
  scale_y_continuous(labels = function(x) moneda(x)) +
  labs(title = "Ventas diarias y proyeccion a 30 dias", x = NULL, y = "Ventas") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(color = azul, face = "bold"), panel.grid.minor = element_blank())
ggsave(file.path(dir_evidencias, "prediccion_ventas.png"), grafico_pronostico,
       width = 11, height = 5.8, dpi = 180, bg = "white")

grafico_segmentos_clientes <- ggplot(resumen_segmentos_clientes,
  aes(reorder(segmento, ventas), ventas, fill = segmento)) +
  geom_col(show.legend = FALSE, width = 0.68) + coord_flip() +
  scale_y_continuous(labels = function(x) moneda(x)) +
  scale_fill_manual(values = c(
    "Clientes estrategicos" = azul,
    "Clientes por reactivar" = "#94A3B8",
    "Clientes frecuentes de desarrollo" = turquesa,
    "Clientes de desarrollo" = celeste
  )) +
  labs(title = "Ventas acumuladas por segmento de clientes", x = NULL, y = "Ventas") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(color = azul, face = "bold"), panel.grid.major.y = element_blank())
ggsave(file.path(dir_evidencias, "segmentacion_clientes.png"), grafico_segmentos_clientes,
       width = 10, height = 5.8, dpi = 180, bg = "white")

grafico_segmentos_productos <- ggplot(resumen_segmentos_productos,
  aes(reorder(segmento_temporal, productos), productos, fill = segmento_temporal)) +
  geom_col(show.legend = FALSE, width = 0.68) + coord_flip() +
  scale_fill_manual(values = c(
    "Demanda estable" = turquesa,
    "Demanda creciente" = azul,
    "Demanda decreciente" = naranja,
    "Demanda intermitente" = "#94A3B8",
    "Demanda variable" = celeste
  )) +
  labs(title = "Productos por comportamiento temporal", x = NULL, y = "Productos") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(color = azul, face = "bold"), panel.grid.major.y = element_blank())
ggsave(file.path(dir_evidencias, "segmentacion_productos.png"), grafico_segmentos_productos,
       width = 10, height = 5.8, dpi = 180, bg = "white")

# -----------------------------------------------------------------------------
# 7. VALIDACION DE LA MACROACTIVIDAD Y MODELO DE CONSUMO PARA SHINY
# -----------------------------------------------------------------------------
validacion_macro <- data.table(
  prueba = c(
    "Registros del modelo base disponibles",
    "Ventas diarias concilian con el total general",
    "Agosto identificado como periodo parcial",
    "Pronostico sin valores negativos o no finitos",
    "Validacion historica del pronostico disponible",
    "Todos los clientes tienen un segmento",
    "Todos los productos tienen un segmento temporal",
    "La serie temporal usa solo meses completos"
  ),
  resultado = c(
    nrow(ventas) == modelo_base$metadata$registros,
    isTRUE(all.equal(sum(ventas_diarias$ventas), sum(ventas$valor_venta), tolerance = 1e-8)),
    any(ventas_mensuales_macro$estado_periodo == "PARCIAL"),
    all(is.finite(unlist(pronostico_ventas[, .(ventas_proyectadas, limite_inferior, limite_superior)]))) &&
      all(pronostico_ventas$ventas_proyectadas >= 0) &&
      all(pronostico_ventas$limite_inferior >= 0),
    nrow(prueba) == n_prueba && all(is.finite(prueba$ventas_proyectadas)),
    nrow(perfil_clientes) == uniqueN(ventas$cliente_id) && !anyNA(perfil_clientes$segmento),
    nrow(resumen_temporal_productos) == uniqueN(ventas$producto_id) && !anyNA(resumen_temporal_productos$segmento_temporal),
    all(serie_producto$mes %in% meses_completos)
  )
)
validacion_macro[, estado := fifelse(resultado, "APROBADO", "REVISAR")]
guardar_csv(validacion_macro, "validacion_macro.csv")
if (!all(validacion_macro$resultado)) {
  stop("La validacion de la Macroactividad requiere revision.", call. = FALSE)
}

modelo_macro <- list(
  metadata = list(
    fecha_inicio = fecha_inicio,
    fecha_corte = fecha_corte,
    meses_completos = meses_completos,
    periodo_parcial = ventas_mensuales_macro[estado_periodo == "PARCIAL", mes],
    horizonte_pronostico = horizonte_pronostico,
    nota_limitaciones = "La fuente disponible no incluye metas comerciales, costos internos ni zonas."
  ),
  modelo_base = modelo_base,
  ventas_diarias = ventas_diarias,
  ventas_mensuales = ventas_mensuales_macro,
  pronostico_ventas = pronostico_ventas,
  validacion_pronostico = prueba,
  metricas_pronostico = metricas_pronostico,
  evaluacion_k_clientes = evaluacion_k,
  segmentacion_clientes = perfil_clientes,
  resumen_segmentos_clientes = resumen_segmentos_clientes,
  segmentacion_productos = resumen_temporal_productos,
  resumen_segmentos_productos = resumen_segmentos_productos,
  serie_mensual_productos = serie_producto,
  validacion_macro = validacion_macro
)
saveRDS(modelo_macro, file.path(dir_data, "modelo_macro.rds"), compress = "gzip")

cat("Macroactividad procesada correctamente.\n")
cat("Fecha de corte:", as.character(fecha_corte), "\n")
cat("Clientes segmentados:", nrow(perfil_clientes), "\n")
cat("Productos segmentados:", nrow(resumen_temporal_productos), "\n")
cat("Pruebas aprobadas:", sum(validacion_macro$resultado), "/", nrow(validacion_macro), "\n")
