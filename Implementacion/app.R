# =============================================================================
# MACROACTIVIDAD - DASHBOARD EJECUTIVO FINAL
# =============================================================================
suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(data.table)
  library(ggplot2)
})

modelo <- readRDS(file.path("data", "modelo_macro.rds"))
ventas <- as.data.table(modelo$modelo_base$fact_ventas)
metadata <- modelo$metadata

azul <- "#082E6D"
celeste <- "#00A6D6"
turquesa <- "#10B8A6"
naranja <- "#F59E0B"
gris <- "#64748B"

moneda_ui <- function(x, decimales = 0) {
  paste0("$", format(round(x, decimales), big.mark = ",", nsmall = decimales, scientific = FALSE))
}

ui <- navbarPage(
  title = div(class = "brand-title", span("HANASKA"), tags$small("Centro de Distribución | Inteligencia de Negocios")),
  id = "navegacion",
  collapsible = TRUE,
  theme = bs_theme(version = 5, bootswatch = "flatly", primary = azul, secondary = celeste,
                   bg = "#F4F7FB", fg = "#172033", base_font = font_google("Inter")),
  header = tagList(
    tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "styles.css?v=1")),
    div(class = "filter-strip",
      fluidRow(
        column(3, dateRangeInput("fechas", "Periodo", start = metadata$fecha_inicio,
          end = metadata$fecha_corte, min = metadata$fecha_inicio, max = metadata$fecha_corte,
          format = "dd/mm/yyyy")),
        column(2, selectInput("empresa", "Empresa", c("TODAS", sort(unique(ventas$empresa))))),
        column(2, selectInput("jefe", "Jefe operativo", c("TODOS", sort(unique(ventas$jefe_operativo))))),
        column(2, selectInput("clasificacion", "Clasificación", c("TODAS", sort(unique(ventas$clasificacion))))),
        column(2, selectizeInput("producto", "Producto", c("TODOS", sort(unique(ventas$producto))),
          options = list(placeholder = "Buscar producto...", maxOptions = 1000))),
        column(1, actionButton("limpiar", "Limpiar", class = "btn-reset"))
      )
    )
  ),

  tabPanel("Resumen ejecutivo",
    div(class = "page-wrap",
      div(class = "hero-card",
        div(class = "eyebrow", "MACROACTIVIDAD | PROYECTO BI FINAL"),
        h2("Desempeño comercial y análisis predictivo"),
        p("Los indicadores responden a la selección activa. El último mes se identifica como parcial cuando no cubre todos sus días."),
        div(class = "status-pill", textOutput("periodo_activo", inline = TRUE))
      ),
      fluidRow(
        column(3, div(class = "kpi-card kpi-blue", span("Valor total de ventas"), h3(textOutput("kpi_ventas", inline = TRUE)), tags$small("Cantidad por precio cliente"))),
        column(3, div(class = "kpi-card kpi-cyan", span("Número de egresos"), h3(textOutput("kpi_egresos", inline = TRUE)), tags$small("Conteo distinto"))),
        column(3, div(class = "kpi-card kpi-green", span("Ticket promedio"), h3(textOutput("kpi_ticket", inline = TRUE)), tags$small("Ventas divididas para egresos"))),
        column(3, div(class = "kpi-card kpi-orange", span("Clientes atendidos"), h3(textOutput("kpi_clientes", inline = TRUE)), tags$small("Clientes con actividad")))
      ),
      fluidRow(
        column(8, div(class = "chart-card", div(class = "card-heading", h4("Evolucion mensual"), span("Los meses parciales no se comparan como cierre mensual")), plotOutput("grafico_tendencia", height = "390px"))),
        column(4, div(class = "chart-card", div(class = "card-heading", h4("Composicion de ventas"), span("Participacion por clasificacion")), plotOutput("grafico_clasificacion", height = "390px")))
      ),
      fluidRow(
        column(4, div(class = "mini-kpi", span("Productos despachados"), strong(textOutput("kpi_productos", inline = TRUE)))),
        column(4, div(class = "mini-kpi", span("Variación del último mes completo"), strong(textOutput("kpi_variacion", inline = TRUE)))),
        column(4, div(class = "mini-kpi", span("Estado del último periodo"), strong(textOutput("kpi_estado_periodo", inline = TRUE))))
      )
    )
  ),

  tabPanel("Análisis comercial",
    div(class = "page-wrap",
      div(class = "section-intro", h2("Tendencias, responsables y productos"), p("Los resultados se actualizan con los filtros superiores.")),
      fluidRow(
        column(7, div(class = "chart-card", h4("Ventas por jefe operativo"), plotOutput("grafico_jefes", height = "440px"))),
        column(5, div(class = "chart-card", h4("Productos con mayor frecuencia"), plotOutput("grafico_productos", height = "440px")))
      ),
      fluidRow(
        column(6, div(class = "table-card", h4("Resumen mensual"), tableOutput("tabla_mensual"))),
        column(6, div(class = "table-card", h4("Productos de menor frecuencia"), tableOutput("tabla_menores")))
      )
    )
  ),

  tabPanel("Pronóstico de ventas",
    div(class = "page-wrap",
      div(class = "section-intro", h2("Proyección diaria"), p("La proyección se calcula sobre el periodo completo disponible y se acompaña de una validación histórica.")),
      fluidRow(
        column(4, div(class = "kpi-card kpi-blue", span("Horizonte"), h3(textOutput("pron_horizonte", inline = TRUE)), tags$small("Días posteriores a la fecha de corte"))),
        column(4, div(class = "kpi-card kpi-cyan", span("Venta proyectada"), h3(textOutput("pron_total", inline = TRUE)), tags$small("Acumulada para el horizonte"))),
        column(4, div(class = "kpi-card kpi-green", span("WAPE de validación"), h3(textOutput("pron_wape", inline = TRUE)), tags$small("Error ponderado sobre 28 días")))
      ),
      div(class = "chart-card", h4("Ventas observadas y proyección a 30 días"), plotOutput("grafico_pronostico", height = "450px")),
      fluidRow(
        column(6, div(class = "table-card", h4("Métricas de validación"), tableOutput("tabla_metricas_pronostico"))),
        column(6, div(class = "table-card", h4("Proyección diaria"), tableOutput("tabla_pronostico")))
      )
    )
  ),

  tabPanel("Segmentación",
    div(class = "page-wrap",
      div(class = "section-intro", h2("Clientes y productos"), p("Los segmentos se definen sobre el periodo completo válido; los filtros permiten explorar su composición.")),
      fluidRow(
        column(6, div(class = "chart-card", h4("Ventas por segmento de clientes"), plotOutput("grafico_segmentos_clientes", height = "390px"))),
        column(6, div(class = "chart-card", h4("Productos por comportamiento temporal"), plotOutput("grafico_segmentos_productos", height = "390px")))
      ),
      fluidRow(
        column(6, div(class = "table-card", h4("Perfil de segmentos de clientes"), tableOutput("tabla_segmentos_clientes"))),
        column(6, div(class = "table-card", h4("Resumen temporal de productos"), tableOutput("tabla_segmentos_productos")))
      ),
      div(class = "table-card", h4("Productos de mayor venta dentro del segmento temporal"), tableOutput("tabla_productos_segmentados"))
    )
  ),

  tabPanel("Modelo y calidad",
    div(class = "page-wrap",
      div(class = "section-intro", h2("Trazabilidad y validación"), p("La solución conserva la integridad del modelo base y valida los componentes incorporados en la Macroactividad.")),
      fluidRow(
        column(7, div(class = "chart-card", h4("Validaciones de la Macroactividad"), tableOutput("tabla_validacion_macro"))),
        column(5, div(class = "table-card", h4("Alcance de la información"),
          p("La información disponible permite analizar ventas, clientes, productos, responsables y empresas."),
          p("No incorpora metas comerciales, costos internos ni zonas; por ello, estos indicadores no se calculan."),
          p(textOutput("fecha_corte_texto", inline = TRUE))
        ))
      ),
      div(class = "table-card", h4("Relaciones del modelo base"), tableOutput("tabla_relaciones"))
    )
  ),

  tabPanel("Conclusiones",
    div(class = "page-wrap",
      div(class = "section-intro", h2("Conclusiones ejecutivas"), p("Los hallazgos sintetizan los resultados del proyecto y orientan decisiones de seguimiento comercial.")),
      div(class = "conclusion-card", uiOutput("conclusiones_dinamicas")),
      div(class = "download-card", h4("Exportar seleccion"), p("La descarga contiene los registros correspondientes a los filtros activos."),
        downloadButton("descargar", "Descargar CSV filtrado", class = "btn-download"))
    )
  ),
  bslib::nav_item(tags$span(class = "student-nav", icon("user-graduate"), " Wladimir Marcelo Nacimba Ona"))
)

server <- function(input, output, session) {
  observeEvent(input$limpiar, {
    updateDateRangeInput(session, "fechas", start = metadata$fecha_inicio, end = metadata$fecha_corte)
    updateSelectInput(session, "empresa", selected = "TODAS")
    updateSelectInput(session, "jefe", selected = "TODOS")
    updateSelectInput(session, "clasificacion", selected = "TODAS")
    updateSelectizeInput(session, "producto", selected = "TODOS")
  })

  datos_filtrados <- reactive({
    req(input$fechas)
    d <- ventas[fecha_despacho >= as.IDate(input$fechas[1]) & fecha_despacho <= as.IDate(input$fechas[2])]
    if (!is.null(input$empresa) && input$empresa != "TODAS") d <- d[empresa == input$empresa]
    if (!is.null(input$jefe) && input$jefe != "TODOS") d <- d[jefe_operativo == input$jefe]
    if (!is.null(input$clasificacion) && input$clasificacion != "TODAS") d <- d[clasificacion == input$clasificacion]
    if (!is.null(input$producto) && input$producto != "TODOS") d <- d[producto == input$producto]
    d
  })

  output$periodo_activo <- renderText({
    paste(format(as.Date(input$fechas[1]), "%d/%m/%Y"), "al", format(as.Date(input$fechas[2]), "%d/%m/%Y"))
  })
  output$kpi_ventas <- renderText(moneda_ui(sum(datos_filtrados()$valor_venta)))
  output$kpi_egresos <- renderText(format(uniqueN(datos_filtrados()$numero_egreso), big.mark = ","))
  output$kpi_ticket <- renderText({
    d <- datos_filtrados(); n <- uniqueN(d$numero_egreso)
    if (n == 0) "$0" else moneda_ui(sum(d$valor_venta) / n)
  })
  output$kpi_clientes <- renderText(format(uniqueN(datos_filtrados()$cliente_id), big.mark = ","))
  output$kpi_productos <- renderText(format(uniqueN(datos_filtrados()$producto_id), big.mark = ","))

  tendencia <- reactive({
    d <- datos_filtrados()[, .(ventas = sum(valor_venta), egresos = uniqueN(numero_egreso)), by = mes][order(mes)]
    d[, estado := ifelse(mes == as.IDate(format(metadata$fecha_corte, "%Y-%m-01")) &
      max(as.IDate(input$fechas)) == metadata$fecha_corte, "PARCIAL", "COMPLETO")]
    d
  })
  output$kpi_variacion <- renderText({
    d <- tendencia()[estado == "COMPLETO"]
    if (nrow(d) < 2) return("N/D")
    v <- (tail(d$ventas, 1) / d$ventas[nrow(d) - 1] - 1) * 100
    paste0(ifelse(v >= 0, "+", ""), round(v, 1), "%")
  })
  output$kpi_estado_periodo <- renderText({
    if (max(as.IDate(input$fechas)) == metadata$fecha_corte) "AGOSTO PARCIAL" else "SELECCION FILTRADA"
  })

  output$grafico_tendencia <- renderPlot({
    d <- tendencia(); validate(need(nrow(d) > 0, "No existen datos para la seleccion."))
    ggplot(d, aes(as.Date(mes), ventas)) +
      geom_area(fill = celeste, alpha = 0.17) +
      geom_line(color = azul, linewidth = 1.15) +
      geom_point(aes(shape = estado), color = turquesa, size = 3) +
      scale_shape_manual(values = c("COMPLETO" = 16, "PARCIAL" = 1)) +
      scale_y_continuous(labels = function(x) paste0("$", round(x / 1e6, 1), " M")) +
      scale_x_date(date_labels = "%b", date_breaks = "1 month") +
      labs(x = NULL, y = "Ventas", shape = "Periodo") +
      theme_minimal(base_size = 12) +
      theme(panel.grid.minor = element_blank(), legend.position = "bottom")
  })
  output$grafico_clasificacion <- renderPlot({
    d <- datos_filtrados()[, .(ventas = sum(valor_venta)), by = clasificacion]
    validate(need(nrow(d) > 0, "No existen datos para la seleccion."))
    ggplot(d, aes(x = "", y = ventas, fill = clasificacion)) + geom_col(width = 1, color = "white") +
      coord_polar(theta = "y") +
      scale_fill_manual(values = c("FRUVER" = turquesa, "NO PERECIBLE" = azul, "PERECIBLE" = naranja)) +
      theme_void() + theme(legend.position = "bottom", legend.title = element_blank())
  })

  output$grafico_jefes <- renderPlot({
    d <- datos_filtrados()[, .(ventas = sum(valor_venta)), by = jefe_operativo][order(-ventas)][1:min(.N, 10)]
    validate(need(nrow(d) > 0, "No existen datos para la seleccion."))
    ggplot(d[order(ventas)], aes(reorder(jefe_operativo, ventas), ventas)) + geom_col(fill = azul, width = 0.66) +
      coord_flip() + scale_y_continuous(labels = function(x) paste0("$", round(x / 1e6, 1), " M")) +
      labs(x = NULL, y = "Ventas") + theme_minimal(base_size = 11) + theme(panel.grid.major.y = element_blank())
  })
  resumen_productos <- reactive(datos_filtrados()[, .(frecuencia = uniqueN(numero_egreso), ventas = sum(valor_venta)), by = producto])
  output$grafico_productos <- renderPlot({
    d <- resumen_productos()[order(-frecuencia)][1:min(.N, 10)]
    validate(need(nrow(d) > 0, "No existen datos para la seleccion."))
    ggplot(d[order(frecuencia)], aes(reorder(producto, frecuencia), frecuencia)) + geom_col(fill = turquesa, width = 0.66) +
      coord_flip() + labs(x = NULL, y = "Egresos distintos") + theme_minimal(base_size = 10) + theme(panel.grid.major.y = element_blank())
  })
  output$tabla_mensual <- renderTable({
    d <- copy(tendencia()); d[, `:=`(Mes = format(as.Date(mes), "%Y-%m"), Ventas = moneda_ui(ventas), Egresos = format(egresos, big.mark = ","))]
    d[, .(Mes, Ventas, Egresos, Estado = estado)]
  }, striped = TRUE, hover = TRUE, spacing = "s")
  output$tabla_menores <- renderTable({
    d <- resumen_productos()[order(frecuencia, ventas)][1:min(.N, 10)]
    d[, .(Producto = producto, Frecuencia = format(frecuencia, big.mark = ","), Ventas = moneda_ui(ventas))]
  }, striped = TRUE, hover = TRUE, spacing = "xs")

  output$pron_horizonte <- renderText(paste0(metadata$horizonte_pronostico, " dias"))
  output$pron_total <- renderText(moneda_ui(sum(modelo$pronostico_ventas$ventas_proyectadas)))
  output$pron_wape <- renderText({
    x <- modelo$metricas_pronostico[metrica == "WAPE", resultado]
    paste0(round(x * 100, 1), "%")
  })
  output$grafico_pronostico <- renderPlot({
    d <- modelo$ventas_diarias
    p <- modelo$pronostico_ventas
    ggplot() +
      geom_line(data = d, aes(as.Date(fecha_despacho), ventas), color = azul, linewidth = 0.65) +
      geom_ribbon(data = p, aes(as.Date(fecha_despacho), ymin = limite_inferior, ymax = limite_superior), fill = celeste, alpha = 0.24) +
      geom_line(data = p, aes(as.Date(fecha_despacho), ventas_proyectadas), color = naranja, linewidth = 1) +
      geom_vline(xintercept = as.Date(metadata$fecha_corte), linetype = "dashed", color = gris) +
      scale_y_continuous(labels = function(x) moneda_ui(x)) +
      labs(x = NULL, y = "Ventas") + theme_minimal(base_size = 12) + theme(panel.grid.minor = element_blank())
  })
  output$tabla_metricas_pronostico <- renderTable({
    d <- copy(modelo$metricas_pronostico)
    d[, resultado_mostrar := fifelse(
      metrica %in% c("MAE", "RMSE"),
      moneda_ui(resultado),
      fifelse(metrica == "WAPE", paste0(round(resultado * 100, 2), "%"),
        paste0(round(resultado, 2), "%"))
    )]
    d[, .(Metrica = metrica, Resultado = resultado_mostrar)]
  }, striped = TRUE, hover = TRUE, spacing = "s")
  output$tabla_pronostico <- renderTable({
    d <- copy(modelo$pronostico_ventas)[1:10]
    d[, `:=`(Fecha = format(as.Date(fecha_despacho), "%d/%m/%Y"), Proyeccion = moneda_ui(ventas_proyectadas))]
    d[, .(Fecha, Dia = dia_semana, Proyeccion)]
  }, striped = TRUE, hover = TRUE, spacing = "s")

  clientes_segmentados <- reactive({
    d <- copy(modelo$segmentacion_clientes)
    if (!is.null(input$empresa) && input$empresa != "TODAS") d <- d[empresa == input$empresa]
    d
  })
  productos_segmentados <- reactive({
    d <- copy(modelo$segmentacion_productos)
    if (!is.null(input$clasificacion) && input$clasificacion != "TODAS") d <- d[clasificacion == input$clasificacion]
    d
  })
  output$grafico_segmentos_clientes <- renderPlot({
    d <- clientes_segmentados()[, .(clientes = .N, ventas = sum(ventas)), by = segmento][order(-ventas)]
    validate(need(nrow(d) > 0, "No existen clientes para la seleccion."))
    ggplot(d, aes(reorder(segmento, ventas), ventas, fill = segmento)) + geom_col(show.legend = FALSE, width = 0.67) +
      coord_flip() + scale_y_continuous(labels = function(x) moneda_ui(x)) +
      scale_fill_manual(values = c("Clientes estrategicos" = azul, "Clientes por reactivar" = "#94A3B8",
        "Clientes frecuentes de desarrollo" = turquesa, "Clientes de desarrollo" = celeste)) +
      labs(x = NULL, y = "Ventas") + theme_minimal(base_size = 12) + theme(panel.grid.major.y = element_blank())
  })
  output$grafico_segmentos_productos <- renderPlot({
    d <- productos_segmentados()[, .(productos = .N), by = segmento_temporal][order(productos)]
    validate(need(nrow(d) > 0, "No existen productos para la seleccion."))
    ggplot(d, aes(reorder(segmento_temporal, productos), productos, fill = segmento_temporal)) + geom_col(show.legend = FALSE, width = 0.67) +
      coord_flip() + scale_fill_manual(values = c("Demanda estable" = turquesa, "Demanda creciente" = azul,
        "Demanda decreciente" = naranja, "Demanda intermitente" = "#94A3B8", "Demanda variable" = celeste)) +
      labs(x = NULL, y = "Productos") + theme_minimal(base_size = 12) + theme(panel.grid.major.y = element_blank())
  })
  output$tabla_segmentos_clientes <- renderTable({
    d <- clientes_segmentados()[, .(Clientes = .N, Ventas = sum(ventas), Frecuencia = mean(frecuencia_egresos), Recencia = mean(recencia_dias)), by = segmento]
    d[, `:=`(Ventas = moneda_ui(Ventas), Frecuencia = round(Frecuencia, 1), Recencia = round(Recencia, 1))]
    setnames(d, "segmento", "Segmento"); d
  }, striped = TRUE, hover = TRUE, spacing = "s")
  output$tabla_segmentos_productos <- renderTable({
    d <- productos_segmentados()[, .(Productos = .N, Ventas = sum(ventas_total), Meses_activos = mean(meses_activos)), by = segmento_temporal]
    d[, `:=`(Ventas = moneda_ui(Ventas), Meses_activos = round(Meses_activos, 1))]
    setnames(d, "segmento_temporal", "Segmento temporal"); d
  }, striped = TRUE, hover = TRUE, spacing = "s")
  output$tabla_productos_segmentados <- renderTable({
    d <- productos_segmentados()[order(-ventas_total)][1:min(.N, 15)]
    d[, .(Producto = producto, Clasificacion = clasificacion, Segmento = segmento_temporal,
      Ventas = moneda_ui(ventas_total), Meses_activos = meses_activos)]
  }, striped = TRUE, hover = TRUE, spacing = "xs")

  output$tabla_validacion_macro <- renderTable({
    d <- copy(modelo$validacion_macro); setnames(d, c("Prueba", "Resultado", "Estado")); d
  }, striped = TRUE, hover = TRUE, spacing = "s")
  output$tabla_relaciones <- renderTable({
    d <- copy(modelo$modelo_base$validacion_relaciones)
    d[, Estado := ifelse(claves_sin_coincidencia == 0, "APROBADO", "REVISAR")]
    setnames(d, c("Relacion", "Claves sin coincidencia", "Estado")); d
  }, striped = TRUE, hover = TRUE, spacing = "s")
  output$fecha_corte_texto <- renderText(paste("La fecha de corte corresponde al", format(as.Date(metadata$fecha_corte), "%d/%m/%Y"), "."))

  output$conclusiones_dinamicas <- renderUI({
    seg <- modelo$resumen_segmentos_clientes[order(-ventas)][1]
    prod <- modelo$resumen_segmentos_productos[order(-ventas)][1]
    proy <- sum(modelo$pronostico_ventas$ventas_proyectadas)
    wape <- modelo$metricas_pronostico[metrica == "WAPE", resultado] * 100
    tagList(
      div(class = "insight", span("01"), p(HTML(paste0("El segmento <strong>", seg$segmento, "</strong> concentra ", round(seg$participacion_ventas, 1), "% del valor de ventas y requiere seguimiento prioritario.")))),
      div(class = "insight", span("02"), p(HTML(paste0("La categoría <strong>", prod$segmento_temporal, "</strong> concentra ", round(prod$participacion_ventas, 1), "% del valor analizado en productos y orienta la planificación de abastecimiento.")))),
      div(class = "insight", span("03"), p(HTML(paste0("La proyección para los siguientes 30 dias alcanza <strong>", moneda_ui(proy), "</strong>. La validación historica registró un WAPE de ", round(wape, 1), "%.")))),
      div(class = "insight warning", span("!"), p("Agosto se interpreta como periodo parcial. Los indicadores de metas, costos y zonas no se presentan porque la informacion disponible no los incorpora."))
    )
  })
  output$descargar <- downloadHandler(
    filename = function() paste0("ventas_filtradas_", Sys.Date(), ".csv"),
    content = function(file) fwrite(datos_filtrados(), file, sep = ";", bom = TRUE)
  )
}

shinyApp(ui, server)
