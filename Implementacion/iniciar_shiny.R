# Inicia el dashboard con una codificacion UTF-8 compatible con Windows.
invisible(try(Sys.setlocale("LC_CTYPE", "English_United States.utf8"), silent = TRUE))

shiny::runApp(".", launch.browser = TRUE)
