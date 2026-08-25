# =============================================================================
# MACROACTIVIDAD - ANALISIS COMERCIAL FINAL
# Proyectos de Inteligencia de Negocios
#
# Este script reutiliza el modelo depurado de la Actividad 2 y añade tres
# componentes de la Macroactividad: prediccion diaria, segmentacion de clientes
# y segmentacion temporal de productos. Las salidas quedan guardadas para el
# dashboard, el informe y la validacion tecnica.
# =============================================================================

# Se fija una codificacion UTF-8 disponible en Windows para conservar las
# tildes en las evidencias graficas aun cuando R se inicie con una locale C.
invisible(try(Sys.setlocale("LC_CTYPE", "English_United States.utf8"), silent = TRUE))

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
# Se comparan tres modelos con cuatro ventanas cronologicas de 28 dias. La
# seleccion se realiza por el menor WAPE agregado y el RMSE se utiliza como
# segundo criterio. De esta forma el pronostico final no se elige por preferencia
# metodologica, sino por su desempeño sobre periodos no usados en el ajuste.
# -----------------------------------------------------------------------------
horizonte_pronostico <- 30L
n_prueba <- 28L
n_ventanas <- 4L
if (nrow(ventas_diarias) <= n_prueba * n_ventanas + 30L) {
  stop("No hay suficientes dias para validar la prediccion.", call. = FALSE)
}

predecir_regresion <- function(entrenamiento, fechas_objetivo) {
  ajuste <- lm(log1p(ventas) ~ indice + dia_semana, data = entrenamiento)
  nuevos <- data.table(
    indice = max(entrenamiento$indice) + seq_len(nrow(fechas_objetivo)),
    dia_semana = factor(
      dias_es[as.integer(format(fechas_objetivo$fecha_despacho, "%w")) + 1],
      levels = levels(ventas_diarias$dia_semana)
    )
  )
  pmax(0, exp(predict(ajuste, newdata = nuevos)) - 1)
}

predecir_naive_semanal <- function(entrenamiento, fechas_objetivo) {
  rep(tail(entrenamiento$ventas, 7L), length.out = nrow(fechas_objetivo))
}

predecir_promedio_dia <- function(entrenamiento, fechas_objetivo, semanas = 8L) {
  dias_objetivo <- dias_es[as.integer(format(fechas_objetivo$fecha_despacho, "%w")) + 1]
  vapply(dias_objetivo, function(dia) {
    historial <- entrenamiento[as.character(dia_semana) == dia, ventas]
    mean(tail(historial, semanas))
  }, numeric(1))
}

predecir_modelo <- function(nombre_modelo, entrenamiento, fechas_objetivo) {
  switch(
    nombre_modelo,
    "Regresion logaritmica" = predecir_regresion(entrenamiento, fechas_objetivo),
    "Naive semanal" = predecir_naive_semanal(entrenamiento, fechas_objetivo),
    "Promedio reciente por dia" = predecir_promedio_dia(entrenamiento, fechas_objetivo),
    stop("Modelo de pronostico no reconocido.", call. = FALSE)
  )
}

modelos_candidatos <- c(
  "Regresion logaritmica",
  "Naive semanal",
  "Promedio reciente por dia"
)
inicio_primera_ventana <- nrow(ventas_diarias) - n_prueba * n_ventanas + 1L
inicios_prueba <- inicio_primera_ventana + (seq_len(n_ventanas) - 1L) * n_prueba

validacion_modelos <- rbindlist(lapply(seq_along(inicios_prueba), function(ventana) {
  inicio <- inicios_prueba[ventana]
  fin <- inicio + n_prueba - 1L
  entrenamiento <- copy(ventas_diarias[seq_len(inicio - 1L)])
  prueba_ventana <- copy(ventas_diarias[inicio:fin])
  rbindlist(lapply(modelos_candidatos, function(nombre_modelo) {
    data.table(
      ventana = ventana,
      fecha_despacho = prueba_ventana$fecha_despacho,
      modelo = nombre_modelo,
      ventas = prueba_ventana$ventas,
      ventas_proyectadas = predecir_modelo(nombre_modelo, entrenamiento, prueba_ventana)
    )
  }))
}))
validacion_modelos[, error := ventas - ventas_proyectadas]
validacion_modelos[, error_absoluto := abs(error)]

comparacion_modelos_pronostico <- validacion_modelos[, .(
  ventanas = uniqueN(ventana),
  observaciones = .N,
  MAE = mean(error_absoluto),
  RMSE = sqrt(mean(error^2)),
  WAPE = sum(error_absoluto) / sum(ventas)
), by = modelo][order(WAPE, RMSE)]
modelo_seleccionado <- comparacion_modelos_pronostico[1, modelo]
comparacion_modelos_pronostico[, seleccionado := modelo == modelo_seleccionado]

errores_seleccionados <- validacion_modelos[modelo == modelo_seleccionado, error]
limites_error <- quantile(errores_seleccionados, probs = c(0.10, 0.90), na.rm = TRUE, type = 8)
prueba <- copy(validacion_modelos[ventana == n_ventanas & modelo == modelo_seleccionado])
prueba[, `:=`(
  limite_inferior = pmax(0, ventas_proyectadas + limites_error[1]),
  limite_superior = pmax(0, ventas_proyectadas + limites_error[2])
)]

metricas_modelo_seleccionado <- comparacion_modelos_pronostico[modelo == modelo_seleccionado]
metricas_pronostico <- data.table(
  metrica = c("MAE", "RMSE", "WAPE", "Cobertura empirica del intervalo al 80%"),
  resultado = c(
    metricas_modelo_seleccionado$MAE,
    metricas_modelo_seleccionado$RMSE,
    metricas_modelo_seleccionado$WAPE,
    mean(
      validacion_modelos[modelo == modelo_seleccionado, ventas] >=
        validacion_modelos[modelo == modelo_seleccionado, ventas_proyectadas] + limites_error[1] &
      validacion_modelos[modelo == modelo_seleccionado, ventas] <=
        validacion_modelos[modelo == modelo_seleccionado, ventas_proyectadas] + limites_error[2]
    ) * 100
  )
)

fechas_futuras <- data.table(
  fecha_despacho = as.IDate(seq(as.Date(fecha_corte) + 1, by = "day", length.out = horizonte_pronostico))
)
pronostico_ventas <- fechas_futuras[, .(
  fecha_despacho,
  dia_semana = dias_es[as.integer(format(fecha_despacho, "%w")) + 1]
)]
pronostico_ventas[, ventas_proyectadas := predecir_modelo(
  modelo_seleccionado, ventas_diarias, fechas_futuras
)]
pronostico_ventas[, `:=`(
  limite_inferior = pmax(0, ventas_proyectadas + limites_error[1]),
  limite_superior = pmax(0, ventas_proyectadas + limites_error[2]),
  modelo = modelo_seleccionado
)]
pronostico_resumen <- data.table(
  indicador = c("Fecha de corte", "Horizonte", "Modelo seleccionado", "Venta proyectada acumulada",
                "Promedio diario proyectado", "WAPE de validacion"),
  resultado = c(
    as.character(fecha_corte),
    paste0(horizonte_pronostico, " dias"),
    modelo_seleccionado,
    moneda(sum(pronostico_ventas$ventas_proyectadas)),
    moneda(mean(pronostico_ventas$ventas_proyectadas)),
    paste0(round(metricas_modelo_seleccionado$WAPE * 100, 2), "%")
  )
)
guardar_csv(pronostico_ventas, "prediccion_ventas.csv")
guardar_csv(prueba, "validacion_pronostico_diario.csv")
guardar_csv(metricas_pronostico, "metricas_pronostico.csv")
guardar_csv(validacion_modelos, "validacion_rolling_pronostico.csv")
guardar_csv(comparacion_modelos_pronostico, "comparacion_modelos_pronostico.csv")
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
ajuste_pca_clientes <- prcomp(matriz_clientes, center = FALSE, scale. = FALSE)
perfil_clientes[, `:=`(
  componente_1 = ajuste_pca_clientes$x[, 1],
  componente_2 = ajuste_pca_clientes$x[, 2]
)]
varianza_pca_clientes <- data.table(
  componente = c("Componente 1", "Componente 2"),
  porcentaje_varianza = (ajuste_pca_clientes$sdev^2 / sum(ajuste_pca_clientes$sdev^2))[1:2] * 100
)

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
                               "productos_diferentes", "dias_activos", "cluster",
                               "componente_1", "componente_2"))
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
guardar_csv(varianza_pca_clientes, "varianza_pca_clientes.csv")

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
umbral_meses_intermitente <- 3L
umbral_cambio <- 25
umbral_variabilidad <- 0.45

clasificar_productos <- function(datos, cambio = umbral_cambio,
                                 variacion = umbral_variabilidad) {
  fcase(
    datos$meses_activos <= umbral_meses_intermitente, "Demanda intermitente",
    !is.na(datos$cambio_tendencia) & datos$cambio_tendencia >= cambio, "Demanda creciente",
    !is.na(datos$cambio_tendencia) & datos$cambio_tendencia <= -cambio, "Demanda decreciente",
    !is.na(datos$variabilidad) & datos$variabilidad <= variacion, "Demanda estable",
    default = "Demanda variable"
  )
}
resumen_temporal_productos[, segmento_temporal := clasificar_productos(resumen_temporal_productos)]

escenarios_sensibilidad <- data.table(
  escenario = c("Referencia", "Cambio 20%", "Cambio 30%", "Variabilidad 0.40", "Variabilidad 0.50"),
  cambio = c(25, 20, 30, 25, 25),
  variacion = c(0.45, 0.45, 0.45, 0.40, 0.50)
)
segmento_referencia <- resumen_temporal_productos$segmento_temporal
sensibilidad_segmentacion_productos <- rbindlist(lapply(seq_len(nrow(escenarios_sensibilidad)), function(i) {
  segmento_alterno <- clasificar_productos(
    resumen_temporal_productos,
    escenarios_sensibilidad$cambio[i],
    escenarios_sensibilidad$variacion[i]
  )
  cambiaron <- segmento_alterno != segmento_referencia
  data.table(
    escenario = escenarios_sensibilidad$escenario[i],
    umbral_cambio = escenarios_sensibilidad$cambio[i],
    umbral_variabilidad = escenarios_sensibilidad$variacion[i],
    productos_reclasificados = sum(cambiaron),
    porcentaje_productos = mean(cambiaron) * 100,
    ventas_reclasificadas = sum(resumen_temporal_productos$ventas_total[cambiaron])
  )
}))

cuantiles_cambio <- quantile(resumen_temporal_productos$cambio_tendencia,
                             probs = c(0.25, 0.50, 0.75), na.rm = TRUE, type = 8)
cuantiles_variabilidad <- quantile(resumen_temporal_productos$variabilidad,
                                   probs = c(0.25, 0.50, 0.75), na.rm = TRUE, type = 8)
justificacion_segmentacion_productos <- data.table(
  indicador = c(
    "Percentil 25 del cambio", "Mediana del cambio", "Percentil 75 del cambio",
    "Percentil 25 de variabilidad", "Mediana de variabilidad", "Percentil 75 de variabilidad",
    "Umbral de cambio aplicado", "Umbral de variabilidad aplicado", "Meses maximos para intermitencia"
  ),
  valor = c(
    cuantiles_cambio, cuantiles_variabilidad,
    umbral_cambio, umbral_variabilidad, umbral_meses_intermitente
  )
)
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
guardar_csv(sensibilidad_segmentacion_productos, "sensibilidad_segmentacion_productos.csv")
guardar_csv(justificacion_segmentacion_productos, "justificacion_segmentacion_productos.csv")

# -----------------------------------------------------------------------------
# 6. RANKINGS COMERCIALES Y HALLAZGOS CONSOLIDADOS
# -----------------------------------------------------------------------------
resumen_productos_comercial <- ventas[, .(
  ventas = sum(valor_venta),
  frecuencia_egresos = uniqueN(numero_egreso),
  cantidad = sum(cantidad)
), by = .(producto_id, producto, clasificacion)]
ranking_productos_valor <- copy(resumen_productos_comercial)[order(-ventas)]
ranking_productos_valor[, posicion := .I]
setcolorder(ranking_productos_valor, c("posicion", "producto_id", "producto", "clasificacion",
                                      "ventas", "frecuencia_egresos", "cantidad"))
ranking_productos_frecuencia <- copy(resumen_productos_comercial)[order(-frecuencia_egresos, -ventas)]
ranking_productos_frecuencia[, posicion := .I]
setcolorder(ranking_productos_frecuencia, c("posicion", "producto_id", "producto", "clasificacion",
                                           "frecuencia_egresos", "ventas", "cantidad"))

ranking_clientes_valor <- ventas[, .(
  ventas = sum(valor_venta),
  frecuencia_egresos = uniqueN(numero_egreso),
  ticket_promedio = sum(valor_venta) / uniqueN(numero_egreso)
), by = .(cliente_id, cliente, empresa)][order(-ventas)]
ranking_clientes_valor[, posicion := .I]
setcolorder(ranking_clientes_valor, c("posicion", "cliente_id", "cliente", "empresa",
                                     "ventas", "frecuencia_egresos", "ticket_promedio"))

ranking_responsables_valor <- ventas[, .(
  ventas = sum(valor_venta),
  egresos = uniqueN(numero_egreso),
  clientes = uniqueN(cliente_id)
), by = jefe_operativo][order(-ventas)]
ranking_responsables_valor[, posicion := .I]
setcolorder(ranking_responsables_valor, c("posicion", "jefe_operativo", "ventas", "egresos", "clientes"))

ventas_clasificacion_mes <- ventas[mes %in% meses_completos, .(
  ventas = sum(valor_venta)
), by = .(mes, clasificacion)][order(mes, clasificacion)]

hallazgos_macro <- data.table(
  tema = c(
    "Ventas acumuladas", "Producto con mayor impacto economico", "Producto con mayor rotacion",
    "Cliente con mayor aporte", "Responsable con mayor valor gestionado", "Pronostico seleccionado",
    "Segmento principal de clientes", "Comportamiento temporal principal", "Limitaciones"
  ),
  hallazgo = c(
    moneda(sum(ventas$valor_venta)),
    paste0(ranking_productos_valor[1, producto], " (", moneda(ranking_productos_valor[1, ventas]), ")"),
    paste0(ranking_productos_frecuencia[1, producto], " (",
           format(ranking_productos_frecuencia[1, frecuencia_egresos], big.mark = ","), " egresos)"),
    paste0(ranking_clientes_valor[1, cliente], " (", moneda(ranking_clientes_valor[1, ventas]), ")"),
    paste0(ranking_responsables_valor[1, jefe_operativo], " (",
           moneda(ranking_responsables_valor[1, ventas]), ")"),
    paste0(modelo_seleccionado, " con WAPE de ",
           round(metricas_modelo_seleccionado$WAPE * 100, 2), "%"),
    paste0(resumen_segmentos_clientes[1, segmento], " (",
           round(resumen_segmentos_clientes[1, participacion_ventas], 1), "% de las ventas)"),
    paste0(resumen_segmentos_productos[1, segmento_temporal], " (",
           round(resumen_segmentos_productos[1, participacion_ventas], 1), "% de las ventas)"),
    "No existen metas comerciales, costos internos ni zonas en la fuente disponible."
  )
)

guardar_csv(ranking_productos_valor, "ranking_productos_valor.csv")
guardar_csv(ranking_productos_frecuencia, "ranking_productos_frecuencia.csv")
guardar_csv(ranking_clientes_valor, "ranking_clientes_valor.csv")
guardar_csv(ranking_responsables_valor, "ranking_responsables_valor.csv")
guardar_csv(ventas_clasificacion_mes, "ventas_clasificacion_mes.csv")
guardar_csv(hallazgos_macro, "hallazgos_macro.csv")

# -----------------------------------------------------------------------------
# 7. EVIDENCIAS VISUALES GENERADAS DESDE R
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
  labs(title = "Ventas diarias y proyección a 30 días", x = NULL, y = "Ventas") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(color = azul, face = "bold"), panel.grid.minor = element_blank())
ggsave(file.path(dir_evidencias, "prediccion_ventas.png"), grafico_pronostico,
       width = 11, height = 5.8, dpi = 180, bg = "white")

grafico_segmentos_clientes <- ggplot(resumen_segmentos_clientes,
  aes(reorder(segmento, ventas), ventas, fill = segmento)) +
  geom_col(show.legend = FALSE, width = 0.68) + coord_flip() +
  scale_y_continuous(labels = function(x) moneda(x)) +
  scale_x_discrete(labels = function(x) fifelse(x == "Clientes estrategicos", "Clientes estratégicos", x)) +
  scale_fill_manual(values = c(
    "Clientes estrategicos" = azul,
    "Clientes por reactivar" = "#94A3B8",
    "Clientes frecuentes de desarrollo" = turquesa,
    "Clientes de desarrollo" = celeste
  ), labels = c(
    "Clientes estrategicos" = "Clientes estratégicos",
    "Clientes por reactivar" = "Clientes por reactivar",
    "Clientes frecuentes de desarrollo" = "Clientes frecuentes de desarrollo",
    "Clientes de desarrollo" = "Clientes de desarrollo"
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

acortar_etiqueta <- function(x, maximo = 48L) {
  fifelse(nchar(x) > maximo, paste0(substr(x, 1L, maximo - 3L), "..."), x)
}

datos_producto_valor <- copy(ranking_productos_valor[1:10])
datos_producto_valor[, etiqueta := acortar_etiqueta(producto)]
grafico_productos_valor <- ggplot(datos_producto_valor[order(ventas)],
  aes(reorder(etiqueta, ventas), ventas)) +
  geom_col(fill = azul, width = 0.68) + coord_flip() +
  scale_y_continuous(labels = function(x) moneda(x)) +
  labs(title = "Productos con mayor valor de ventas", x = NULL, y = "Ventas") +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(color = azul, face = "bold"), panel.grid.major.y = element_blank())
ggsave(file.path(dir_evidencias, "ranking_productos_valor.png"), grafico_productos_valor,
       width = 10.5, height = 6.2, dpi = 180, bg = "white")

datos_producto_frecuencia <- copy(ranking_productos_frecuencia[1:10])
datos_producto_frecuencia[, etiqueta := acortar_etiqueta(producto)]
grafico_productos_frecuencia <- ggplot(datos_producto_frecuencia[order(frecuencia_egresos)],
  aes(reorder(etiqueta, frecuencia_egresos), frecuencia_egresos)) +
  geom_col(fill = turquesa, width = 0.68) + coord_flip() +
  scale_y_continuous(labels = function(x) format(x, big.mark = ",", scientific = FALSE)) +
  labs(title = "Productos con mayor frecuencia de egresos", x = NULL, y = "Egresos distintos") +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(color = azul, face = "bold"), panel.grid.major.y = element_blank())
ggsave(file.path(dir_evidencias, "ranking_productos_frecuencia.png"), grafico_productos_frecuencia,
       width = 10.5, height = 6.2, dpi = 180, bg = "white")

datos_clientes_valor <- copy(ranking_clientes_valor[1:10])
datos_clientes_valor[, etiqueta := acortar_etiqueta(cliente)]
grafico_clientes_valor <- ggplot(datos_clientes_valor[order(ventas)],
  aes(reorder(etiqueta, ventas), ventas)) +
  geom_col(fill = naranja, width = 0.68) + coord_flip() +
  scale_y_continuous(labels = function(x) moneda(x)) +
  labs(title = "Clientes con mayor valor de ventas", x = NULL, y = "Ventas") +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(color = azul, face = "bold"), panel.grid.major.y = element_blank())
ggsave(file.path(dir_evidencias, "ranking_clientes_valor.png"), grafico_clientes_valor,
       width = 10.5, height = 6.2, dpi = 180, bg = "white")

datos_responsables <- copy(ranking_responsables_valor[1:min(.N, 10)])
grafico_responsables <- ggplot(datos_responsables[order(ventas)],
  aes(reorder(jefe_operativo, ventas), ventas)) +
  geom_col(fill = celeste, width = 0.68) + coord_flip() +
  scale_y_continuous(labels = function(x) moneda(x)) +
  labs(title = "Ventas por responsable comercial / jefe operativo", x = NULL, y = "Ventas") +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(color = azul, face = "bold"), panel.grid.major.y = element_blank())
ggsave(file.path(dir_evidencias, "ranking_responsables_valor.png"), grafico_responsables,
       width = 10.5, height = 6.2, dpi = 180, bg = "white")

meses_cortos <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")
datos_calor <- copy(ventas_clasificacion_mes)
datos_calor[, mes_etiqueta := factor(
  meses_cortos[as.integer(format(as.Date(mes), "%m"))],
  levels = meses_cortos[sort(unique(as.integer(format(as.Date(mes), "%m"))))]
)]
grafico_calor_clasificacion <- ggplot(datos_calor,
  aes(mes_etiqueta, clasificacion, fill = ventas)) +
  geom_tile(color = "white", linewidth = 1.1) +
  geom_text(aes(label = paste0("$", round(ventas / 1e6, 2), " M")),
            color = "white", fontface = "bold", size = 3.5) +
  scale_fill_gradient(low = celeste, high = azul, labels = function(x) moneda(x)) +
  labs(title = "Ventas mensuales por clasificación", x = "Mes", y = NULL, fill = "Ventas") +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(color = azul, face = "bold"), panel.grid = element_blank(),
        legend.position = "none")
ggsave(file.path(dir_evidencias, "mapa_calor_clasificacion.png"), grafico_calor_clasificacion,
       width = 10.5, height = 5.4, dpi = 180, bg = "white")

grafico_pca_clientes <- ggplot(perfil_clientes,
  aes(componente_1, componente_2, color = segmento)) +
  geom_point(alpha = 0.72, size = 2.3) +
  scale_color_manual(values = c(
    "Clientes estrategicos" = azul,
    "Clientes por reactivar" = naranja,
    "Clientes frecuentes de desarrollo" = turquesa,
    "Clientes de desarrollo" = celeste
  ), labels = c(
    "Clientes estrategicos" = "Clientes estratégicos",
    "Clientes por reactivar" = "Clientes por reactivar",
    "Clientes frecuentes de desarrollo" = "Clientes frecuentes de desarrollo",
    "Clientes de desarrollo" = "Clientes de desarrollo"
  )) +
  labs(
    title = "Segmentación de clientes representada mediante PCA",
    x = paste0("Componente 1 (", round(varianza_pca_clientes[1, porcentaje_varianza], 1), "%)"),
    y = paste0("Componente 2 (", round(varianza_pca_clientes[2, porcentaje_varianza], 1), "%)"),
    color = "Segmento"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(color = azul, face = "bold"), panel.grid.minor = element_blank(),
        legend.position = "bottom")
ggsave(file.path(dir_evidencias, "pca_segmentacion_clientes.png"), grafico_pca_clientes,
       width = 10.5, height = 6.2, dpi = 180, bg = "white")

datos_comparacion <- copy(comparacion_modelos_pronostico)
datos_comparacion[, WAPE_porcentaje := WAPE * 100]
datos_comparacion[, estado_modelo := fifelse(seleccionado, "Seleccionado", "Comparacion")]
datos_comparacion[, modelo_mostrar := fcase(
  modelo == "Regresion logaritmica", "Regresión logarítmica",
  modelo == "Promedio reciente por dia", "Promedio reciente por día",
  default = modelo
)]
grafico_comparacion_modelos <- ggplot(datos_comparacion[order(-WAPE_porcentaje)],
  aes(reorder(modelo_mostrar, WAPE_porcentaje), WAPE_porcentaje, fill = estado_modelo)) +
  geom_col(width = 0.66, show.legend = FALSE) + coord_flip() +
  geom_text(aes(label = paste0(round(WAPE_porcentaje, 2), "%")), hjust = -0.12, color = azul) +
  scale_fill_manual(values = c("Seleccionado" = turquesa, "Comparacion" = "#A8B4C5")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.16))) +
  labs(title = "Comparación de modelos mediante validación temporal", x = NULL, y = "WAPE") +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(color = azul, face = "bold"), panel.grid.major.y = element_blank())
ggsave(file.path(dir_evidencias, "comparacion_modelos_pronostico.png"), grafico_comparacion_modelos,
       width = 9.5, height = 5.2, dpi = 180, bg = "white")

grafico_tendencia_mensual <- ggplot(ventas_mensuales_macro,
  aes(as.Date(mes), ventas, group = 1)) +
  geom_line(color = azul, linewidth = 0.9) +
  geom_point(aes(fill = estado_periodo), shape = 21, size = 3.4, color = "white") +
  scale_fill_manual(values = c("COMPLETO" = turquesa, "PARCIAL" = naranja)) +
  scale_y_continuous(labels = function(x) moneda(x)) +
  labs(title = "Evolución mensual de las ventas", x = NULL, y = "Ventas", fill = "Periodo") +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(color = azul, face = "bold"), panel.grid.minor = element_blank(),
        legend.position = "bottom")
ggsave(file.path(dir_evidencias, "tendencia_mensual.png"), grafico_tendencia_mensual,
       width = 10.5, height = 5.6, dpi = 180, bg = "white")

# -----------------------------------------------------------------------------
# 8. VALIDACION DE LA MACROACTIVIDAD Y MODELO DE CONSUMO PARA SHINY
# -----------------------------------------------------------------------------
validacion_macro <- data.table(
  prueba = c(
    "Registros del modelo base disponibles",
    "Ventas diarias concilian con el total general",
    "Agosto identificado como periodo parcial",
    "Pronostico sin valores negativos o no finitos",
    "Validacion temporal de todos los modelos disponible",
    "El modelo seleccionado tiene el menor WAPE",
    "Todos los clientes tienen un segmento",
    "La representacion PCA de clientes es valida",
    "Todos los productos tienen un segmento temporal",
    "La serie temporal usa solo meses completos",
    "Los rankings cubren productos y clientes",
    "La sensibilidad conserva el escenario de referencia",
    "El registro de limpieza del modelo base esta disponible"
  ),
  resultado = c(
    nrow(ventas) == modelo_base$metadata$registros,
    isTRUE(all.equal(sum(ventas_diarias$ventas), sum(ventas$valor_venta), tolerance = 1e-8)),
    any(ventas_mensuales_macro$estado_periodo == "PARCIAL"),
    all(is.finite(unlist(pronostico_ventas[, .(ventas_proyectadas, limite_inferior, limite_superior)]))) &&
      all(pronostico_ventas$ventas_proyectadas >= 0) &&
      all(pronostico_ventas$limite_inferior >= 0),
    nrow(validacion_modelos) == n_prueba * n_ventanas * length(modelos_candidatos) &&
      all(is.finite(validacion_modelos$ventas_proyectadas)),
    modelo_seleccionado == comparacion_modelos_pronostico[which.min(WAPE), modelo],
    nrow(perfil_clientes) == uniqueN(ventas$cliente_id) && !anyNA(perfil_clientes$segmento),
    all(is.finite(perfil_clientes$componente_1)) && all(is.finite(perfil_clientes$componente_2)),
    nrow(resumen_temporal_productos) == uniqueN(ventas$producto_id) && !anyNA(resumen_temporal_productos$segmento_temporal),
    all(serie_producto$mes %in% meses_completos),
    nrow(ranking_productos_valor) == uniqueN(ventas$producto_id) &&
      nrow(ranking_clientes_valor) == uniqueN(ventas$cliente_id),
    sensibilidad_segmentacion_productos[escenario == "Referencia", productos_reclasificados] == 0,
    !is.null(modelo_base$registro_cambios) && nrow(modelo_base$registro_cambios) > 0
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
    modelo_pronostico = modelo_seleccionado,
    wape_validacion = comparacion_modelos_pronostico[seleccionado == TRUE, WAPE],
    ventanas_validacion = n_ventanas,
    umbral_cambio_productos = umbral_cambio,
    umbral_variabilidad_productos = umbral_variabilidad,
    varianza_pca_clientes = varianza_pca_clientes,
    nota_limitaciones = "La fuente disponible no incluye metas comerciales, costos internos ni zonas."
  ),
  modelo_base = modelo_base,
  ventas_diarias = ventas_diarias,
  ventas_mensuales = ventas_mensuales_macro,
  pronostico_ventas = pronostico_ventas,
  validacion_pronostico = prueba,
  metricas_pronostico = metricas_pronostico,
  comparacion_modelos_pronostico = comparacion_modelos_pronostico,
  validacion_rolling_pronostico = validacion_modelos,
  evaluacion_k_clientes = evaluacion_k,
  segmentacion_clientes = perfil_clientes,
  resumen_segmentos_clientes = resumen_segmentos_clientes,
  varianza_pca_clientes = varianza_pca_clientes,
  segmentacion_productos = resumen_temporal_productos,
  resumen_segmentos_productos = resumen_segmentos_productos,
  serie_mensual_productos = serie_producto,
  sensibilidad_segmentacion_productos = sensibilidad_segmentacion_productos,
  justificacion_segmentacion_productos = justificacion_segmentacion_productos,
  ranking_productos_valor = ranking_productos_valor,
  ranking_productos_frecuencia = ranking_productos_frecuencia,
  ranking_clientes_valor = ranking_clientes_valor,
  ranking_responsables_valor = ranking_responsables_valor,
  ventas_clasificacion_mes = ventas_clasificacion_mes,
  hallazgos_macro = hallazgos_macro,
  validacion_macro = validacion_macro
)
saveRDS(modelo_macro, file.path(dir_data, "modelo_macro.rds"), compress = "gzip")

cat("Macroactividad procesada correctamente.\n")
cat("Fecha de corte:", as.character(fecha_corte), "\n")
cat("Modelo de pronostico seleccionado:", modelo_seleccionado, "\n")
cat("WAPE de validacion:", round(metricas_modelo_seleccionado$WAPE * 100, 2), "%\n")
cat("Clientes segmentados:", nrow(perfil_clientes), "\n")
cat("Productos segmentados:", nrow(resumen_temporal_productos), "\n")
cat("Pruebas aprobadas:", sum(validacion_macro$resultado), "/", nrow(validacion_macro), "\n")
