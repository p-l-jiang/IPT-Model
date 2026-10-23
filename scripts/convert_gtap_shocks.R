# Convert a GTAP shock file into an IPT scenario file (see src/gtap_shocks.R).
#
# Usage (from the repository root):
#   Rscript scripts/convert_gtap_shocks.R --psh <file.psh> --id <scenario id>
#       [--label "<label>"] [--out config/scenarios/<id>.yml]
#       [--weights icio | <VCIF csv>] [--regions <csv>] [--commodities <csv>]
#       [--canada Canada] [--usa USA] [--config config/default.yml]
#
# Weights: `icio` (default) uses the OECD ICIO table of the calibration year and
# the concordances in config/concordances/gtap/. A CSV with columns commodity,
# exporter, importer, value (VCIF from the GTAP database the shocks were run
# on) uses GTAP's own trade instead, e.g. in R with HARr:
#   v <- HARr::read_har("basedata.har")$vcif
#   d <- as.data.frame(as.table(v)); names(d) <- c("commodity", "exporter", "importer", "value")
#   write.csv(d, "vcif.csv", row.names = FALSE)
#
# Writes the scenario file and, next to it, <id>_conversion.csv (one row per
# IPT shock with the GTAP components behind it) and <id>_components.csv.
# Two scenarios are written with the same shocks: <id> with fixed provincial
# populations (as in GTAP) and <id>_mobility with interprovincial migration.
# Run them with:
#   Rscript scripts/07_run_scenarios.R --set "scenarios=[config/scenarios/<id>.yml]"

source("src/load.R")
source("src/gtap_shocks.R")
cfg <- script_config()

args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default = NULL) {
  k <- match(paste0("--", name), args)
  if (is.na(k) || k == length(args)) default else args[k + 1]
}
psh <- arg("psh") %||% stopf("Give the shock file with --psh <file>.")
id <- arg("id") %||% stopf("Give a scenario id with --id <id>.")
label <- arg("label", sprintf("GTAP shocks %s", basename(psh)))
out <- arg("out", file.path("config", "scenarios", paste0(id, ".yml")))
weights_src <- arg("weights", "icio")
canada <- arg("canada", "Canada")
usa <- arg("usa", "USA")
conc <- load_gtap_concordances(arg("regions", concordance_path("gtap/regions_sc2551.csv")),
                               arg("commodities", concordance_path("gtap/commodities_sc2551.csv")), cfg)

shocks <- read_gtap_shocks(psh)
log_info(sprintf("Read %d shocks from %s (%s).", nrow(shocks), basename(psh),
                 paste(names(table(shocks$variable)), table(shocks$variable), sep = ": ", collapse = ", ")))

if (identical(weights_src, "icio")) {
  weights <- icio_gtap_weights(cfg, cfg$years$target, conc)
  weights_note <- sprintf("OECD ICIO %d bilateral trade (intermediate + final use)", cfg$years$target)
} else {
  weights <- gtap_csv_weights(weights_src, conc)
  weights_note <- sprintf("GTAP VCIF from %s", basename(weights_src))
}

theta_file <- processed_path(cfg, "trade_elasticities.csv")
theta <- if (file.exists(theta_file)) {
  te <- readr::read_csv(theta_file, show_col_types = FALSE)
  setNames(te$theta, te$sector_id)
} else {
  setNames(rep(NA_real_, length(model_sectors(cfg))), model_sectors(cfg))
}

conv <- convert_gtap_shocks(shocks, weights, theta, canada = canada, usa = usa)
if (nrow(conv$dropped) > 0) {
  log_info(sprintf("Dropped %d shock(s) between GTAP regions that are all in ROW: %s", nrow(conv$dropped),
                   paste(unique(paste(conv$dropped$exporter, "->", conv$dropped$importer)), collapse = ", ")))
}

header <- c(
  sprintf("%s: converted from the GTAP shock file %s", label, basename(psh)),
  sprintf("by scripts/convert_gtap_shocks.R on %s (configuration %s).", format(Sys.Date()), cfg$name),
  "",
  "tms -> ad valorem tariffs (rate = tms / 100: same change in the power of the tariff,",
  "  revenue rebated to the importer). qxs -> iceberg cost with the same partial-equilibrium",
  "  change in the flow, factor = (1 + q)^(-1/theta), no revenue.",
  "GTAP Canada -> all provinces and territories (same rate in each); USA -> USA; all other",
  "  GTAP regions -> ROW. Where an IPT sector or ROW holds several GTAP commodities or regions,",
  sprintf("  the rate is their trade-weighted average (weights: %s).", weights_note),
  sprintf("  Concordances: config/concordances/gtap/. Audit table: %s.", basename(sub("\\.yml$", "_conversion.csv", out))),
  if (nrow(conv$dropped) > 0) sprintf("Not represented (both sides in ROW): %d shocks, %s.", nrow(conv$dropped),
                                      paste(unique(paste(conv$dropped$exporter, "->", conv$dropped$importer)), collapse = ", ")),
  "Comments after each shock: the GTAP commodities behind it, their average change in the cell",
  "  and their share (w) of the cell's baseline trade.")

variants <- list(
  list(id = id, label = paste0(label, ", fixed populations"),
       tariff_treatment = "ad_valorem", migration_elasticity = 0),
  list(id = paste0(id, "_mobility"), label = paste0(label, ", interprovincial labour mobility"),
       tariff_treatment = "ad_valorem", migration_elasticity = cfg$migration$elasticity %||% 1.5))
write_gtap_scenario(conv, out, variants, header = header, sector_order = model_sectors(cfg))

audit <- conv$cells |>
  select(type, importers = ipt_importer, exporters = ipt_exporter, sector, rate, factor,
         flow_change = change, theta, trade_usd_m, gtap_components = detail)
write_table(audit, sub("\\.yml$", "_conversion.csv", out))
write_table(conv$components |>
              select(variable, importers = ipt_importer, exporters = ipt_exporter, sector, commodity,
                     gtap_exporter = exporter, gtap_importer = importer, trade_usd_m = value, weight, shock_pct = value_pct),
            sub("\\.yml$", "_components.csv", out))
log_info(sprintf("Wrote %d IPT shocks to %s.", nrow(conv$cells), out))
