#' @title phenology
#' @name phenology
#' @aliases phenology-package
#' @docType package
#' @keywords Vegetation phenology package
#' @description Vegetation phenology package
#' @import magrittr numDeriv plyr pls Ipaper
#' @import tibble ggplot2 
#' @importFrom gridExtra arrangeGrob
#' @importFrom data.table data.table as.data.table := is.data.table fwrite fread
#' @importFrom zoo na.approx index zoo
#' @importFrom dplyr bind_cols bind_rows group_by
#' @importFrom purrr map map_df map_dbl is_empty
#' @importFrom tidyr gather spread
#' @importFrom lubridate ymd dyears is.Date
#' @importFrom stringr str_extract
#' @importFrom utils object.size
#' @importFrom grDevices dev.off cairo_pdf
#' @import graphics
#' @importFrom Rcpp sourceCpp
NULL
# stats
# ' @useDynLib phenology, .registration = TRUE

.onLoad <- function (libname, pkgname){
    if(getRversion() >= "2.15.1") {
        utils::globalVariables(
            c(".SD", ".N", 
              "meth", "doy", "origin", # tidyFitPheno
              "DayOfYear", "SummaryQA", "site", "EVI", "w", "QC_flag", # tidy_MOD13.gee
              "beg", "end",  # plot_phenofit
              "val", "type", "flag", "peak" # season
            )
        )
    }
}
# .onUnload <- function (libpath) {
#   library.dynam.unload("phenofit", libpath)
# }
