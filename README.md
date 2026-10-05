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
* **Comparison with the published results of Albrecht and Tombe (2016), Alvarez,
  Krznar and Tombe (2019) and Manucha and Tombe (2022):** [`docs/replication.md`](docs/replication.md)
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
  replication_*.yml  setups of the 2016, 2019 and 2022 papers
  scenarios/         counterfactual experiments
  concordances/      sector, product, industry, region and adjacency mappings
  parameters/        trade-elasticity sources
  benchmarks/        published results used by the replication comparison
src/               function library (sourced by src/load.R)
scripts/           numbered pipeline steps and run_all.R
  replication/       runs the paper setups and compares them with the published results
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
| `config/default.yml` | Main model: 13 provinces/territories + USA + ROW, 37 sectors, 2022, region-specific IO, observed trade imbalances, BoC-rule trade elasticities, interprovincial labour mobility |
| `config/sensitivity_theta_papers.yml` | Main model with the trade elasticities of Albrecht and Tombe (2016) |
| `config/sensitivity_gravity_levels.yml` | Main model with the trade-cost decomposition of Alvarez, Krznar and Tombe (2019) (distance in levels) |
| `config/variant_tariffs_ad_valorem.yml` | US tariff scenarios with ad valorem tariffs on goods and tariff revenue |
| `config/replication_albrecht_tombe_2016.yml` | Albrecht and Tombe (2016) setup: 2010, 10 provinces + ROW, 22 sectors, national IO with the paper's value-added and final-demand shares, mean distance between residents, balanced trade, asymmetric costs |
| `config/replication_alvarez_krznar_tombe_2019.yml` | Alvarez, Krznar and Tombe (2019) setup: 2015, 18 sectors, labour mobility, balanced trade, level-distance gravity with international pairs (2010-2015 panel) |
| `config/replication_manucha_tombe_2022.yml` | Manucha and Tombe (2022) setup: 13 regions + ROW, 2018, manufacturing as one sector, labour mobility |

A configuration can `extend` another and override only what it changes. The
main options are:

| Option | Values |
|---|---|
| `years$target` | calibration year (2010-2022, with an ICIO table for that year) |
| `regions$domestic`, `regions$foreign` | provinces/territories to include; `["USA", "ROW"]` or `["ROW"]` |
| `sectors$scheme` | `base37` or a CSV aggregating the base sectors |
| `distances$method` | `centroid` (between population centroids) or `pairwise` (mean distance between residents) |
| `io_parameters$source` | `regional`, `national`, `global` |
| `io_parameters$sector_values` | optional CSV of published value-added and final-demand shares by sector |
| `trade_elasticities$method` | `boc2018_rule`, `fixed` (CSV) or `uniform` (goods and services values) |
| `trade_costs$sample`, `$regressors`, `$geographic` | gravity sample and regressors (`log_dist`, `dist_1000km`, `adjacent`, `interprovincial`, `border`) |
| `trade_costs$measured_index` | `symmetric` (Head-Ries) or `augmented` (with exporter-specific costs) |
| `trade_costs$measurement_elasticities` | optional CSV of elasticities used only to measure trade costs |
| `calibration$deficits` | `data` (hold observed imbalances fixed), `balanced` (observed trade shares, zero imbalances) or `purge` (re-solve with zero imbalances) |
| `migration$elasticity` | 1.5 (default: interprovincial labour mobility) or 0 (none) |
| `scenario_defaults$tariff_treatment` | `iceberg` (default, legacy) or `ad_valorem` |
| `aggregation$canada_weights` | `income`, `real_income`, `population` |

Region codes in YAML must be quoted: an unquoted `ON` is read as `TRUE`.

Any setting can also be overridden on the command line, which is convenient for
sensitivity analysis; give the variant its own name so that its outputs are kept
separate:

```sh
Rscript scripts/run_all.R --from 5 --set name=no_adjacency --set "trade_costs.regressors=[log_dist]"
```

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

Shock types: `iceberg`, `tariff`, `autarky`, `measured_cost_reduction`,
`eliminate_nongeographic`, `eliminate_asymmetries`, `eliminate_measured` (see
`src/scenarios.R` and `docs/model.md`). The measured-cost shocks apply to
interprovincial pairs unless `importers`/`exporters` say otherwise, e.g. a
unilateral liberalization by Alberta or a bloc of provinces:

```yaml
  - id: alberta_mutual_recognition
    label: "Alberta removes non-geographic costs on imports from other provinces"
    shocks:
      - {type: eliminate_nongeographic, importers: ["AB"], exporters: domestic, sectors: all}
```

Region groups: `all`, `domestic`, `provinces`, `territories`, `foreign`, or a
list of codes; sector groups: `all`, `goods`, `services`, or a list of codes
(`config/concordances/sectors.csv`). With `report: gains_from_trade`, results
are the gains of the observed equilibrium relative to the counterfactual
(used for gains from trade relative to autarky).

## Results (2022 calibration, October 2026)

Change in Canada's real income (%, baseline-income weights), with
interprovincial labour mobility (migration elasticity 1.5). The last column
gives the published figure of the study whose experiment the scenario follows
(A&T: Albrecht and Tombe, 2016; AKT: Alvarez, Krznar and Tombe, 2019; MLI:
Manucha and Tombe, 2022); see [`docs/replication.md`](docs/replication.md).

| Scenario | Main model | Papers' trade elasticities | Published |
|---|---:|---:|---:|
| 10% lower interprovincial trade costs | 4.01 | 3.23 | 3.6 (A&T), 6.7 (MLI) |
| 10% lower costs of Canadian imports from foreign regions | 3.08 | 2.76 | 2.9 (A&T) |
| 10% lower trade costs with foreign regions, both directions | 9.04 | 6.67 | |
| 10% lower measured interprovincial trade costs | 0.71 | 0.84 | 0.9 (A&T) |
| Eliminate interprovincial trade-cost asymmetries | 4.83 | 5.63 | 3.3 (A&T), 7.9 (MLI) |
| Eliminate non-geographic interprovincial barriers | 4.90 | 6.68 | 6.8 (A&T), 4.4 (MLI) |
| ... goods only | 0.46 | 0.57 | 3.8 (AKT)* |
| ... services only | 4.38 | 5.98 | 4.2 (MLI) |
| Eliminate all measured interprovincial trade costs | 46.2 | 61.0 | 51.9 (A&T) |
| US 35% tariff on all partners (iceberg, all sectors) | -2.98 | -3.28 | |
| ... with Canadian retaliation | -3.97 | -4.31 | |
| ... with Canadian and rest-of-world retaliation | -3.90 | -4.59 | |
| US 50% tariff on metals | -0.09 | -0.12 | |
| ... with Canadian and rest-of-world retaliation | -0.19 | -0.29 | |

\* AKT measure geographic costs with distance in levels; with that
specification (`config/sensitivity_gravity_levels.yml`) the main model gives
5.08 for goods, 5.28 for asymmetries and 25.4 for all sectors. Which share of
measured costs is policy-relevant is the largest source of uncertainty in these
experiments.

With ad valorem tariffs on goods only (revenue rebated), a 35% US tariff lowers
Canada's real income by 1.97%, and by 2.47% with Canadian retaliation.

These results depend on several modelling choices documented in
`docs/methodology_review.md` and `docs/replication.md`, notably the trade
elasticities: the BoC rule gives very high values for refined petroleum (71.1),
metal ores (45.0) and oil and gas (20.2), which produce near-corner responses to
uniform cost changes. For example, a 10% cut in external trade costs raises
New Brunswick's refining output 130-fold and its real income by 115% (43% per
person, as its population grows by half through migration). With the
elasticities of the papers, the main model comes close to most of Albrecht and
Tombe's figures.

## Tests

```sh
Rscript tests/testthat.R                         # unit tests
Rscript tests/crosscheck/export_cases.R --real   # export solved cases
python3 tests/crosscheck/solver_crosscheck.py    # independent NumPy/SciPy solver
```

The tests check, among others, that a shock-free counterfactual returns the
baseline, that solutions satisfy every equilibrium condition, the
Arkolakis-Costinot-Rodríguez-Clare welfare formula in one-sector economies
(with and without intermediate inputs) for small shocks and for autarky,
tariff-revenue accounting, population conservation with migration, exact
recovery of trade costs by the Head-Ries index, of exporter-specific costs and
of the coefficients of both gravity specifications, and that every Statistics
Canada product and industry code in the 2010-2022 data maps to a sector.

`Rscript scripts/replication/run_replications.R` re-runs the setups of the three
papers and compares them with their published figures
(`output/replication/comparison.md`).

## Known limitations

* Which share of measured trade costs is non-geographic (policy-relevant)
  depends on the gravity specification; `config/sensitivity_gravity_levels.yml`
  gives the alternative of Alvarez, Krznar and Tombe (2019). See
  `docs/replication.md`.
* The main model measures distance between population centroids. The papers
  use the mean distance between residents (`distances$method: pairwise`),
  which attributes less of measured costs to geography (eliminating
  non-geographic barriers: about 6.3% instead of 4.9%). Switching requires
  rebuilding the distances from the raw 2021 census file, because the
  committed extract lacks Yukon.
* Labour mobility is on by default, and the model has no congestion force
  (no land or housing) to offset it. Regional results, and national results
  driven by one region (e.g. New Brunswick's refining under external
  liberalization), should be read with this in mind; set
  `migration$elasticity: 0` for fixed populations.
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
