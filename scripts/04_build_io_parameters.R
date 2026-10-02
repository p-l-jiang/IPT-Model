# Build region-specific value-added shares (phi), input-output coefficients
# (gamma) and final-demand shares (beta) for the calibration year.
#
# Usage: Rscript scripts/04_build_io_parameters.R [--config config/default.yml]

source("src/load.R")
cfg <- script_config()
year <- cfg$years$target
icio <- load_icio_year(cfg, year, load_fx(cfg))
io <- build_io_parameters(cfg, year, icio)
saveRDS(io, processed_path(cfg, "io_parameters.rds"))

write_table(array_to_long(io$phi, c("region", "sector", "phi")), processed_path(cfg, "phi.csv"))
write_table(array_to_long(io$beta, c("region", "sector", "beta")), processed_path(cfg, "beta.csv"))
readr::write_csv(array_to_long(io$gamma, c("region", "input_sector", "sector", "gamma")),
                 processed_path(cfg, "gamma.csv.gz"))
if (nrow(io$clamped_phi) > 0) {
  log_info(sprintf("Note: %d value-added shares outside (0.01, 1] were clamped.", nrow(io$clamped_phi)))
}
log_info("Wrote IO parameters.")
