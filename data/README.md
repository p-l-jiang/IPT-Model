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

`<year>.csv` for 1995-2022: OECD Inter-Country Input-Output tables, 2025
edition, extended version (China and Mexico split into CN1/CN2 and MX1/MX2),
current USD millions. Source: <https://oe.cd/icio>. A calibration year needs its
ICIO table and the Statistics Canada trade-flow and supply and use tables
(2010 onward).

## raw/fx

`FXUSDCAD.csv`: Bank of Canada daily exchange rate, Canadian dollars per US
dollar, May 2007 - May 2025. Source:
<https://www.bankofcanada.ca/valet/observations/FXUSDCAD/csv>.

## raw/census

The distances in `data/processed/distances_2021.csv` are built from the 2021
census Geographic Attribute File (Statistics Canada, catalogue 92-151-X:
dissemination-block populations and dissemination-area representative points),
`2021_92-151_X.csv`, which `paths$census_da` points to. The file is large and
git-ignored: to rebuild the distances, download it from
<https://www12.statcan.gc.ca/census-recensement/2021/geo/aip-pia/attribute-attribs/index2021-eng.cfm?year=2021>
into this folder and run `scripts/02_build_distances.R` (without it, step 2
keeps the committed distances).

`2021_da_extract.csv` is the extract produced by the legacy 2021 distance
script. It lacks **Yukon** (the script looked for "Yukon Territory"; see
`docs/data.md`); `src/distance.R` reads both it and the raw file. The
Albrecht and Tombe replication builds its pairwise distances
(`data/processed/distances_2021_pairwise.csv`, ten provinces) from it.

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
configurations that use 2021 census distances between population centroids;
`processed/distances_2021_pairwise.csv` holds mean distances between residents
(no Yukon), used by the Albrecht and Tombe replication.
