# Changelog

Substantive changes to the model, its data and its methods, newest first.
Purely organizational changes (file moves, renames, refactoring that does not
change results) are not listed. Item references (A1, ...) point to
[`docs/methodology_review.md`](docs/methodology_review.md), which explains each
problem in detail.

## 2026-10-05 — Comparison with the published results

The model was compared with Albrecht and Tombe (2016; May 2015 working paper),
Alvarez, Krznar and Tombe (2019, IMF WP 19/158) and Manucha and Tombe (2022,
Macdonald-Laurier Institute). Each paper's setup is a configuration, its
published figures are in `config/benchmarks/published_results.csv`, and
`scripts/replication/run_replications.R` reproduces the comparison and the
step-by-step "bridges" to the main model. Findings and diagnosis:
[`docs/replication.md`](docs/replication.md).

### Errors fixed

- **"Eliminate non-geographic barriers" could cut costs below within-province
  costs.** Where the estimated geographic component was below one (negative
  distance or adjacency coefficients, mainly in mining support services,
  telecommunications and electronics: 64 interprovincial pairs, 1.2% of 2022
  trade), the shock lowered costs by more than eliminating all measured costs.
  The geographic component is now floored at one (`trade_costs$floor_geographic`;
  the Alvarez et al. replication keeps the paper's unfloored version). Main
  model, all sectors: 4.89% -> 4.64%; services: 4.45% -> 4.18%; goods unchanged.
- **Correction to the 2026-10-02 entry (A13).** That entry said the legacy
  level-distance gravity specification made the geographic component depend on
  the units of distance. It does not (the coefficient rescales). The legacy
  specification was that of Alvarez et al. (2019), with two departures (no
  interprovincial indicator; US and ROW own pairs without the intra-regional
  indicator). It is now implemented correctly as an option; the main model
  keeps the Albrecht-Tombe specification. `docs/methodology_review.md` is
  corrected.
- **Replication configurations.** `config/replication_albrecht_tombe_2016.yml`
  now follows the paper (balanced trade, asymmetric costs and the augmented
  Head-Ries index, real-GDP weights) and runs on data in the repository (2016;
  it required the missing 2010 ICIO table and unverified legacy 2006 distances).
  `config/replication_tombe_2019.yml`, which reproduced the legacy script rather
  than the paper, is replaced by `config/replication_alvarez_krznar_tombe_2019.yml`.

### Methodology changes

- **Main-model internal-trade scenarios follow the papers' definitions.** The
  measured-cost experiments now cover all sectors, as in Albrecht and Tombe
  (previously goods only), with goods-only (Alvarez et al.) and services-only
  (Manucha and Tombe) variants; asymmetries and a cut in import costs only are
  added. Results: 10% lower measured costs 0.23% (goods) -> 0.67% (all
  sectors); eliminating all measured costs 9.92% (goods) -> 41.9%; eliminating
  non-geographic barriers 0.42% (goods) and 4.64% (all sectors).
- **External cost experiment.** Albrecht and Tombe's Table 5 figures (2.9% for a
  10% cut) are reproduced only when the cut applies to Canadian imports; a
  two-way cut gives more than twice as much. Both versions are provided
  (`t5c5_import_costs_minus10`: 3.30%; two-way: 9.34%).

### Added

- Exporter-specific (asymmetric) trade costs (Waugh, 2010), the augmented
  Head-Ries index (`trade_costs$measured_index: augmented`) and the
  `eliminate_asymmetries` experiment.
- The trade-cost decomposition of Alvarez et al. (2019): distance in thousands
  of km, neighbour indicator, interprovincial indicator by year, international
  pairs, optional within-region pairs (`trade_costs$regressors`, `$geographic`,
  `$year_interactions`, `$own_pairs`); `config/sensitivity_gravity_levels.yml`
  applies it to the main model (non-geographic barriers for goods: 4.96%; all
  sectors: 23.1%).
- Gains-from-trade experiments (`autarky` shocks, `report: gains_from_trade`),
  with a check that isolated regions can finance their trade imbalances.
- Measured-cost experiments for any importers and exporters (external costs,
  unilateral liberalization, blocs of provinces) and partial eliminations
  (`fraction`).
- Uniform trade elasticities (`trade_elasticities$method: uniform`) and
  command-line overrides (`--set key=value`).
- Trade-weighted summaries of measured, geographic, non-geographic and
  asymmetric costs (`trade_cost_summary.csv`) and exporter-specific costs
  (`exporter_costs.csv`).
- Configurations, sector schemes and elasticities for the three papers. The
  goods elasticities of Manucha and Tombe (2022), which the paper does not
  list, are recovered from its measured costs (manufacturing 8.9, mining 15.8,
  agriculture 6.9); inverting its Table 1 for services returns 4.9-5.2 against
  the stated 5, which validates the data.
- Tests for the new estimators (recovery of exporter costs and of both gravity
  specifications on synthetic data), autarky (ACR formula), the floor, scenario
  targeting, configuration overrides and the benchmark file.

### Findings (see `docs/replication.md`)

- Albrecht and Tombe: gains from trade, 10% cost cuts, measured-cost
  experiments and non-distance elimination are reproduced (e.g. 4.2 vs 4.4,
  3.15 vs 3.6, 0.82 vs 0.9, 6.4 vs 6.8), as are their measured trade costs;
  removing asymmetries gives more (5.1 vs 3.3).
- Alvarez et al.: gains from trade reproduced (4.5 / 10.0 / 18.9 vs 5.1 / 10.9 /
  19.6); eliminating non-geographic barriers for goods gives 1.4-2.3 times their
  figures, because measured costs in current data are higher than they report.
  The main model's much smaller goods figure (0.42% vs 3.8%) is due to the
  gravity specification.
- Manucha and Tombe: non-distance experiments reproduced by the main model (4.6
  vs 4.4; services 4.2 vs 4.2). Their 6.7% gain from a uniform 10% cut is not
  reproduced: the model gives 3.1-3.7%, which is what the paper's own
  first-order approximation (its Table 2) implies.
- The trade elasticities explain most of the remaining difference between the
  main model and Albrecht and Tombe: with the papers' elasticities the main
  model gives 3.05, 2.81, 0.80, 6.23 and 54.2 against 3.6, 2.9, 0.9, 6.8 and 51.9.

### Removed

- `config/replication_tombe_2019.yml` (see above). `config/parameters/theta_tombe_2019_replication.csv`
  is renamed `theta_albrecht_tombe_2016_base37.csv` (it holds Albrecht and
  Tombe's Table 9 values mapped to the 37 sectors).

## 2026-10-02 — Unified, corrected model calibrated to 2022

The five overlapping script variants (2015 replication and improvement, 2019
replication, "Tombe Improvement" and the "GE Model" scripts) were replaced by a
single configurable pipeline. The two paper setups are now configurations
(`config/replication_albrecht_tombe_2016.yml`, `config/replication_tombe_2019.yml`).

### Data errors fixed

- **China and Mexico restored to the rest of the world** (A1). The ICIO rows of
  CN1, CN2, MX1 and MX2 were dropped while the CHN and MEX rows of the extended
  ICIO are empty, removing about 32% of rest-of-world gross output.
- **Census population weights** (A5). The 2006/2011 distance scripts could weight
  by factor codes instead of populations; verified for the committed 2011
  distance matrix and `da_data.csv`, which were removed.
- **Yukon** (A6). Census records are now matched to provinces by code, so Yukon
  is no longer dropped by a name mismatch ("Yukon Territory" vs "Yukon"). The
  committed 2021 extract still lacks Yukon and must be regenerated from the raw
  census file. Meanwhile, scenarios that use measured trade costs alone (lower
  or eliminate measured interprovincial costs) apply to Yukon's pairs, which
  are no longer dropped with the missing distances.
- **US/ROW split of international trade** (A7). Removed double counting of
  telecommunications and other information services, stopped counting
  re-exports as US exports, and replaced subtraction of industry-based levels by
  within-table US shares applied to the trade-flow totals.
- **Sector concordance** (A8). Trade flows now use the detail-level table
  12-10-0101-01 and one code-based concordance, following ISIC Rev. 4, shared
  with the supply and use tables. Most importantly, passenger cars and trucks
  are now motor vehicles rather than "other transport equipment"; publishing,
  prepared meals, steel pipes, synthetic rubber, rental and leasing, aircraft
  repair and several other products are reassigned to their ISIC sectors.
  Products are matched by code, so renamed products no longer drop out.
- **Neighbour (adjacency) list** (A13). The list is now
  symmetric: land borders plus the Confederation Bridge (PE-NB). NS-NL (ferry)
  and MB-NT (single point) are no longer neighbours; BC-NT and NB-PE are now
  neighbours in both directions.
- **Rest-of-world internal distance** used the Earth's total surface rather than
  land area (8,331 km instead of 4,302 km); a ROW-to-province distance field
  took ROW's internal distance. Both only matter when international pairs enter
  the gravity regressions.
- **Exchange rates.** Partial-year averages (2007) are rejected.
- **Numeric precision.** Large StatCan values are read as doubles (an
  integer64 conversion would otherwise round values to whole millions).

### Model and solver errors fixed

- **Consistent baseline** (A2). The baseline is now an exact equilibrium of the
  model: trade shares, input-output and final-demand shares are taken from the
  data, observed trade imbalances are held fixed (Caliendo and Parro, 2015), and
  expenditures, revenues and value added are solved from market clearing. The
  legacy code imposed balanced trade on inconsistent data, so a shock-free
  counterfactual did not return the baseline; balanced trade alone would move
  provincial real incomes by -30% to +31%. A balanced-trade baseline remains
  available (`calibration$deficits: purge`).
- **Income definition** (A10). Incomes in the expenditure system are nominal
  (they were price-deflated GDP shares, and for 2022 were read from a stale 2019
  file). Real income now includes the fixed trade deficit and tariff revenue.
- **Migration** (A9). Labour mobility now conserves total population, using
  population shares (table 17-10-0005-01) instead of GDP shares.
- **"Eliminate non-geographic barriers"** (A3) passed the counterfactual level of
  trade costs as the change, raising costs; now `min(tau_geo / tau_bar, 1)`.
- **Table 6 year** (A4). Trade-cost shocks use the calibration year instead of
  the last year in the file.
- **"Eliminate all measured costs"** (A15) is capped so that it never raises costs.
- **"10% lower external costs"** (A11) no longer lowers US-ROW trade costs.
- **Sectoral results** (A14). Replaced the "sectoral GDP" measure
  ($\hat w \hat L/\hat p_j$) by sectoral output, value-added and employment changes.
- **Solver.** Newton's method with line search replaces the damped wage
  iteration, which diverges with the high trade elasticities; the
  intermediate-demand and price blocks are solved to convergence (they stopped
  after 50 and 100 iterations without checks).

### Methodology changes (choices that change results)

- **Region-specific input-output structure.** Value-added shares and input
  shares come from each province's supply and use table (and from the ICIO for
  the United States and the rest of the world) instead of a world average
  applied to every region. Selectable: `io_parameters$source` = `regional`
  (default), `national`, `global` (legacy).
- **Gravity specification** (A13). Log normalized distance instead of distance
  in km in levels; interprovincial pairs only (international pairs with a
  border dummy as an option); standard errors clustered by origin and
  destination.
- **Trade elasticities** (A12). Derived strictly from the stated rule (Bank of
  Canada 2016 estimate when significant at 5%, otherwise the 1993 estimate, plus
  2; services 5 + 2). Changes from the legacy values: agriculture 10.1 -> 3.1,
  energy extraction 45.0 -> 20.2, mining support 45.0 -> 7.0, food 4.6 -> 3.5,
  wood 17.7 -> 17.8, refined petroleum 72.1 -> 71.1, chemicals 6.7 -> 6.8,
  computers and electronics 14.3 -> 11.8, motor vehicles 7.0 -> 3.0 (its
  2016 t-statistic is 1.957, just below 1.96).
- **Canada-wide aggregation.** Provincial changes are weighted by baseline
  nominal income shares by default (legacy: price-deflated GDP shares, available
  as `aggregation$canada_weights: real_income`).

### Added

- Ad valorem tariffs with revenue rebated to the importer (Caliendo and Parro,
  2015) as an alternative to iceberg-cost tariffs, selectable per scenario or
  configuration; goods-only US tariff scenarios
  (`config/variant_tariffs_ad_valorem.yml`).
- Sensitivity configuration with the trade elasticities of the Tombe papers
  (`config/sensitivity_theta_papers.yml`).
- Configuration files, versioned concordances and scenario files; automatic
  download and caching of Statistics Canada data; support for any calibration
  year with supply and use tables (2010-2022) and an ICIO table.
- Baseline diagnostics (model-implied vs observed value added, deficits) and an
  automatic identity check of the calibration.
- Test suite (analytic welfare formulas, equilibrium conditions, tariff
  accounting, migration, trade-cost measurement, concordance coverage, data
  parsing) and an independent NumPy/MINPACK cross-check of the solver.

### Removed

- Legacy scripts (preserved in the repository history at commit `24ede19`).
- `data/distance/2011_dist_mat.csv` and `data/distance/da_data.csv` (corrupted
  population weights, A5) and `data/distance/dist_mat_final.csv` (missing
  Yukon, superseded by `data/processed/distances_2021.csv`).
