# IPT-Model: interprovincial and international trade in Canada

A quantitative general-equilibrium model of trade among Canada's 13 provinces
and territories, the United States and the rest of the world, for studying
internal trade barriers, external trade policy and their regional effects.

The model is a multi-sector Eaton-Kortum model with input-output linkages
(Caliendo and Parro, 2015), solved in changes relative to a calibrated
baseline, in the line of Albrecht and Tombe (2016) and its 2019 extension to
the territories, the United States and labour mobility. It has 37 sectors (the
ICIO 2025 industries, ISIC Rev. 4) and is calibrated to 2022 with Statistics
Canada trade-flow and supply-use data and the OECD Inter-Country Input-Output
tables.

* **Model and equations:** [`docs/model.md`](docs/model.md)
* **Data sources and construction:** [`docs/data.md`](docs/data.md)
* **Review of the original code and the errors corrected:** [`docs/methodology_review.md`](docs/methodology_review.md)
* **Dated list of substantive changes:** [`CHANGELOG.md`](CHANGELOG.md)

## Quick start

Requirements: R ≥ 4.1 and the packages `dplyr`, `tidyr`, `readr`, `tibble`,
`data.table`, `yaml`, `sandwich` (and `testthat` for the tests).

```sh
Rscript scripts/00_setup.R                                 # install missing packages
Rscript scripts/run_all.R                                  # main configuration (config/default.yml)
Rscript scripts/run_all.R --config config/sensitivity_theta_papers.yml
Rscript scripts/run_all.R --from 5                         # re-use the processed data in data/processed/default
Rscript scripts/07_run_scenarios.R --only us_tariff_35     # one scenario
```

All scripts run from the repository root. The first run downloads about 1 GB of
Statistics Canada tables into `data/raw/statcan/` (cached, not committed). The
processed inputs of the main configuration are committed, so steps 5-7
(`--from 5`) run without any download. A full run takes a few minutes; each
counterfactual takes 5-15 seconds.

Results are written to `output/<configuration>/`: `summary.md` and
`summary.csv`, and for each scenario `regions.csv` (real income, real income
per capita, real wage, price index, population, trade by region), `canada.csv`
(Canada-wide aggregates) and `sectors.csv` (output and employment by region
and sector).

## Repository layout

```
config/            model configurations (YAML), scenarios, concordances, parameters
  default.yml        main 2022 model
  replication_*.yml  setups of the 2016 and 2019 papers
  scenarios/         counterfactual experiments
  concordances/      sector, product, industry, region and adjacency mappings
  parameters/        trade-elasticity sources
src/               function library (sourced by src/load.R)
scripts/           numbered pipeline steps and run_all.R
tests/             testthat suite and an independent Python cross-check of the solver
data/              raw inputs and processed model inputs (see data/README.md)
docs/              model, data and methodology documentation; reference documents
```

## Pipeline

| Step | Script | Output (`data/processed/<configuration>/`) |
|---|---|---|
| 1 | `01_download_data.R` | Statistics Canada downloads and extracts (cache) |
| 2 | `02_build_distances.R` | `data/processed/distances_2021.csv` |
| 3 | `03_build_trade_flows.R` | `trade_flows.csv.gz`, `us_trade_shares.csv` |
| 4 | `04_build_io_parameters.R` | `phi.csv`, `gamma.csv.gz`, `beta.csv`, `io_parameters.rds` |
| 5 | `05_estimate_trade_costs.R` | `measured_trade_costs.csv.gz`, `gravity_coefficients.csv`, `trade_cost_decomposition.csv` |
| 6 | `06_calibrate.R` | `baseline.rds`, `baseline_diagnostics.csv`, `trade_elasticities.csv` |
| 7 | `07_run_scenarios.R` | `output/<configuration>/` |

Step 6 verifies that the calibrated baseline is an equilibrium (a shock-free
counterfactual must return no change) and stops otherwise.

## Configurations

| File | Purpose |
|---|---|
| `config/default.yml` | Main model: 13 provinces/territories + USA + ROW, 37 sectors, 2022, region-specific IO, observed trade imbalances, BoC-rule trade elasticities |
| `config/sensitivity_theta_papers.yml` | Main model with the trade elasticities of the Tombe papers |
| `config/variant_tariffs_ad_valorem.yml` | US tariff scenarios with ad valorem tariffs on goods and tariff revenue |
| `config/replication_albrecht_tombe_2016.yml` | Albrecht and Tombe (2016) setup: 10 provinces + ROW, 22 sectors, 2010 (needs the 2010 ICIO table) |
| `config/replication_tombe_2019.yml` | 2019 paper setup: 2015, labour mobility (needs the 2015 ICIO table) |

A configuration can `extend` another and override only what it changes. The
main options are:

| Option | Values |
|---|---|
| `years$target` | calibration year (2010-2022, with an ICIO table for that year) |
| `regions$domestic`, `regions$foreign` | provinces/territories to include; `["USA", "ROW"]` or `["ROW"]` |
| `sectors$scheme` | `base37` or a CSV aggregating the base sectors |
| `io_parameters$source` | `regional`, `national`, `global` |
| `trade_elasticities$method` | `boc2018_rule` or `fixed` (CSV) |
| `trade_costs$sample` | `interprovincial` or `all` |
| `calibration$deficits` | `data` (hold observed imbalances fixed) or `purge` |
| `migration$elasticity` | 0 (none) or e.g. 1.5 |
| `scenario_defaults$tariff_treatment` | `iceberg` (default, legacy) or `ad_valorem` |
| `aggregation$canada_weights` | `income`, `real_income`, `population` |

Region codes in YAML must be quoted: an unquoted `ON` is read as `TRUE`.

### Writing scenarios

```yaml
scenarios:
  - id: lower_barriers_goods
    label: "15% lower interprovincial trade costs for goods"
    shocks:
      - {type: iceberg, importers: domestic, exporters: domestic, sectors: goods, factor: 0.85}
  - id: us_tariff_autos
    label: "US 25% tariff on Canadian vehicles"
    tariff_treatment: ad_valorem
    shocks:
      - {type: tariff, importers: ["USA"], exporters: domestic, sectors: [MTV], rate: 0.25}
```

Shock types: `iceberg`, `tariff`, `measured_cost_reduction`,
`eliminate_nongeographic`, `eliminate_measured` (see `src/scenarios.R`).
Region groups: `all`, `domestic`, `provinces`, `territories`, `foreign`, or a
list of codes; sector groups: `all`, `goods`, `services`, or a list of codes
(`config/concordances/sectors.csv`).

## Results (2022 calibration, October 2026)

Change in Canada's real income (%, baseline-income weights).

| Scenario | Main model | Papers' trade elasticities |
|---|---:|---:|
| 10% lower interprovincial trade costs (all sectors) | 3.68 | 3.05 |
| 10% lower trade costs between Canada and foreign regions | 9.34 | 6.36 |
| 10% lower measured interprovincial trade costs (goods) | 0.23 | 0.24 |
| Eliminate non-geographic interprovincial barriers (goods) | 0.42 | 0.53 |
| Eliminate all measured interprovincial trade costs (goods) | 9.92 | 7.78 |
| US 35% tariff on all partners (iceberg, all sectors) | -2.35 | -2.60 |
| ... with Canadian retaliation | -3.31 | -3.60 |
| ... with Canadian and rest-of-world retaliation | -3.35 | -3.84 |
| US 50% tariff on metals | -0.12 | -0.15 |
| ... with Canadian and rest-of-world retaliation | -0.20 | -0.31 |

With ad valorem tariffs on goods only (revenue rebated), a 35% US tariff lowers
Canada's real income by 1.44%, and by 1.94% with Canadian retaliation.

These results depend on several modelling choices documented in
`docs/methodology_review.md`, notably the trade elasticities: the BoC rule
gives very high values for refined petroleum (71.1), metal ores (45.0) and oil
and gas (20.2), which produce near-corner responses to uniform cost changes
(e.g. a 10% cut in external trade costs raises New Brunswick's real income by
63% through an expansion of refining exports).

## Tests

```sh
Rscript tests/testthat.R                         # unit tests
Rscript tests/crosscheck/export_cases.R --real   # export solved cases
python3 tests/crosscheck/solver_crosscheck.py    # independent NumPy/SciPy solver
```

The tests check, among others, that a shock-free counterfactual returns the
baseline, that solutions satisfy every equilibrium condition, the
Arkolakis-Costinot-Rodríguez-Clare welfare formula in one-sector economies
(with and without intermediate inputs), tariff-revenue accounting, population
conservation with migration, exact recovery of trade costs by the Head-Ries
index and of gravity coefficients, and that every Statistics Canada product
and industry code in the 2010-2022 data maps to a sector.

## Known limitations

* Yukon is missing from the committed 2021 census extract, so its pairs are not
  in the gravity regressions and keep their non-geographic barriers when those
  are eliminated (see `docs/data.md` for how to restore it).
* The replication configurations need the 2010 and 2015 ICIO tables, which are
  not in the repository.
* Results with labour mobility lack a congestion force (no land or housing).
* The model is static: no transition dynamics, capital accumulation or trade
  imbalance adjustment beyond the `purge` option.

## References

* Albrecht, L. and T. Tombe (2016). Internal trade, productivity and
  interconnected industries: A quantitative analysis. *Canadian Journal of
  Economics* 49(1): 237-263.
* Alvarez, J., I. Krznar and T. Tombe (2019). Internal trade in Canada: Case
  for liberalization. IMF Working Paper 19/158.
* Caliendo, L. and F. Parro (2015). Estimates of the trade and welfare effects
  of NAFTA. *Review of Economic Studies* 82(1): 1-44.
* Charbonneau, K. B. and A. Landry (2018). Estimating the impacts of tariff
  changes: Two illustrative scenarios. Bank of Canada Staff Analytical Note
  2018-29.
* OECD (2025). Inter-Country Input-Output Database, <https://oe.cd/icio>.
* Statistics Canada, tables 12-10-0100-01, 12-10-0101-01, 17-10-0005-01,
  18-10-0003-01 and catalogue 15-602-X.

Further references are listed in [`docs/model.md`](docs/model.md).
