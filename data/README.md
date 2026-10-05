# Data

```
data/
├── raw/
│   ├── icio/       OECD ICIO 2025 edition (extended), one CSV per year, USD millions
│   ├── fx/         Bank of Canada daily CAD per USD (FXUSDCAD)
│   ├── census/     2021 census dissemination-area extract used for distances
│   ├── legacy/     2006-census normalized distances from the legacy script
│   └── statcan/    Statistics Canada downloads and extracts (git-ignored, re-created)
└── processed/      model inputs built by scripts/02-06 (one folder per configuration)
```

See [`docs/data.md`](../docs/data.md) for how each source is used.

## raw/icio

`ICIO2025_<year>.csv` for 2016-2022: OECD Inter-Country Input-Output tables,
2025 edition, extended version (China and Mexico split into CN1/CN2 and
MX1/MX2), current USD millions. Source: <https://oe.cd/icio>. To calibrate to
another year, download that year's CSV and save it under the same naming
pattern. The 2010 and 2015 tables are needed by the two replication
configurations.

## raw/fx

`FXUSDCAD.csv`: Bank of Canada daily exchange rate, Canadian dollars per US
dollar, May 2007 - May 2025. Source:
<https://www.bankofcanada.ca/valet/observations/FXUSDCAD/csv>.

## raw/census

`2021_da_extract.csv`: one row per 2021 census dissemination block with the
province/territory, the representative point (latitude, longitude) of its
dissemination area and the block population (Statistics Canada, Geographic
Attribute File, catalogue 92-151-X, 2021). This extract was produced by the
legacy 2021 distance script, which dropped **Yukon** (see `docs/data.md`). To
restore Yukon, download `2021_92-151_X.csv` from
<https://www12.statcan.gc.ca/census-recensement/2021/geo/aip-pia/attribute-attribs/index2021-eng.cfm?year=2021>,
save it here and set `paths$census_da` to it; `src/distance.R` reads both the
raw file and the extract.

## raw/legacy

`2006_dist_mat_legacy.csv`: normalized distances between the ten provinces
computed by the legacy script from the 2006 Geographic Attribute File. The raw
2006 file is not in the repository, so this file could not be regenerated with
the corrected reader; it lies within about 6% of correctly weighted 2021
values. No configuration uses it (the Albrecht and Tombe replication uses the
2021 census distances); it is kept for reference and can be selected with
`paths$distances`.

## raw/statcan (not committed)

Created by `scripts/01_download_data.R`: full-table CSVs of 12-10-0100-01,
12-10-0101-01, 17-10-0005-01 and 18-10-0003-01, the 15-602-X supply and use
tables of the calibration year, and compact `*_extract.csv.gz` files that later
steps read. Delete an extract to rebuild it.

## processed

`processed/default/` holds the inputs of the main configuration, so that the
model can be re-estimated and re-run without downloading anything:

| File | Content |
|---|---|
| `trade_flows.csv.gz` | bilateral flows by sector, 2010-2022 (and foreign flows for 2022) |
| `us_trade_shares.csv` | US shares of provincial exports/imports and their source |
| `phi.csv`, `beta.csv`, `gamma.csv.gz`, `io_parameters.rds` | production and demand parameters |
| `measured_trade_costs.csv.gz` | Head-Ries trade costs |
| `gravity_coefficients.csv` | distance and adjacency elasticities by sector |
| `exporter_costs.csv` | exporter-specific (asymmetric) trade costs by region, sector and year |
| `trade_cost_decomposition.csv` | geographic, non-geographic and asymmetric components for every pair, 2022 |
| `trade_cost_summary.csv` | trade-weighted averages of the components by sector, exporter and importer |
| `trade_elasticities.csv` | trade elasticities with their derivation |
| `baseline.rds`, `baseline_diagnostics.csv` | calibrated baseline and diagnostics |

`processed/distances_2021.csv` (and `_centroids.csv`) are shared by
configurations that use 2021 census distances.
