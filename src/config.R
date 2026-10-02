# Configuration loading.
#
# A configuration is a YAML file. A file may declare `extends: <other.yml>`, in
# which case it is merged recursively on top of the parent (lists are merged by
# name; scalars and unnamed vectors in the child replace the parent's).

#' Recursively merge list `y` into list `x`.
merge_config <- function(x, y) {
  for (nm in names(y)) {
    if (is.list(x[[nm]]) && is.list(y[[nm]]) && !is.null(names(y[[nm]]))) {
      x[[nm]] <- merge_config(x[[nm]], y[[nm]])
    } else {
      x[nm] <- list(y[[nm]])
    }
  }
  x
}

#' Read a YAML configuration, resolving `extends` chains.
read_config_file <- function(path) {
  if (!file.exists(path)) stopf("Configuration file not found: %s", path)
  cfg <- yaml::read_yaml(path)
  parent <- cfg$extends
  cfg$extends <- NULL
  if (!is.null(parent)) {
    parent_path <- if (file.exists(parent)) parent else file.path(dirname(path), parent)
    cfg <- merge_config(read_config_file(parent_path), cfg)
  }
  cfg
}

#' Load and validate a model configuration.
#'
#' @param path Path to a YAML configuration (default: config/default.yml).
#' @return A list with all settings; `cfg$config_file` records the source file.
load_config <- function(path = "config/default.yml") {
  cfg <- read_config_file(path)
  cfg$config_file <- path
  cfg$paths$output <- glue_path(cfg$paths$output, name = cfg$name)
  validate_config(cfg)
  cfg
}

#' Configuration for a pipeline script: `--config <file>` on the command line,
#' otherwise config/default.yml.
script_config <- function(default = "config/default.yml") {
  args <- commandArgs(trailingOnly = TRUE)
  k <- match("--config", args)
  path <- if (!is.na(k) && length(args) > k) args[k + 1] else default
  cfg <- load_config(path)
  log_info("Configuration: ", path, " (", cfg$name, ")")
  cfg
}

#' Substitute `{name}` and `{year}` placeholders in a path template.
glue_path <- function(template, ...) {
  args <- list(...)
  out <- template
  for (nm in names(args)) out <- gsub(paste0("{", nm, "}"), args[[nm]], out, fixed = TRUE)
  out
}

validate_config <- function(cfg) {
  needed <- c("name", "paths", "years", "regions", "sectors", "io_parameters",
              "trade_elasticities", "trade_costs", "calibration", "solver")
  missing <- setdiff(needed, names(cfg))
  if (length(missing) > 0) stopf("Configuration is missing: %s", paste(missing, collapse = ", "))
  known <- load_regions()$region_id
  for (grp in c("domestic", "foreign")) {
    r <- cfg$regions[[grp]]
    if (!is.character(r) || !all(r %in% known)) {
      stopf(paste0("regions$%s must list region codes from config/concordances/regions.csv ",
                   "(quote them in YAML: an unquoted ON is read as TRUE). Got: %s"),
            grp, paste(r, collapse = ", "))
    }
  }
  if (!all(cfg$regions$foreign %in% c("USA", "ROW"))) {
    stopf("regions$foreign must be a subset of {USA, ROW}.")
  }
  if (!"ROW" %in% cfg$regions$foreign) stopf("regions$foreign must include ROW.")
  if (!cfg$io_parameters$source %in% c("regional", "national", "global")) {
    stopf("io_parameters$source must be 'regional', 'national' or 'global'.")
  }
  if (!cfg$calibration$deficits %in% c("data", "purge")) {
    stopf("calibration$deficits must be 'data' or 'purge'.")
  }
  invisible(TRUE)
}

#' All model regions in display order (domestic first, then foreign).
model_regions <- function(cfg) c(cfg$regions$domestic, cfg$regions$foreign)

#' Panel years used for trade-cost estimation.
panel_years <- function(cfg) seq(cfg$years$panel[1], cfg$years$panel[2])

#' Path of the ICIO table for a given year.
icio_path <- function(cfg, year) glue_path(cfg$paths$icio_file, year = year)

#' Output directory for the current configuration.
output_dir <- function(cfg, ...) ensure_dir(file.path(cfg$paths$output, ...))

#' Path of a processed (intermediate) data product. Products are stored per
#' configuration so that different configurations never overwrite each other.
processed_path <- function(cfg, file) {
  file.path(ensure_dir(file.path(cfg$paths$processed, cfg$name)), file)
}
