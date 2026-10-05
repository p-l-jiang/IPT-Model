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

### Data and defaults (changes on `main`, 2 and 5 October)

- OECD ICIO tables for 1995-2015 added; all years renamed `data/raw/icio/<year>.csv`.
  The Albrecht and Tombe and Alvarez et al. setups now use the papers' years
  (2010 and 2015; the Alvarez et al. regressions use 2010-2015, the first years
  of the detail-level trade flows, instead of 1997-2015).
- Yukon distances computed from the raw 2021 census Geographic Attribute File
  (`2021_92-151_X.csv`, git-ignored); the committed distances include Yukon.
  `scripts/02_build_distances.R` now keeps the committed distances when the raw
  file is absent.
- Labour mobility is on by default (`migration$elasticity: 1.5`).

With these changes the main model gives: 10% lower interprovincial costs
4.01% (3.68% before); eliminating non-geographic barriers 4.90% (4.64%), goods
0.46% (0.42%), services 4.38% (4.18%); asymmetries 4.83% (4.43%); all measured
costs 46.2% (41.9%); 10% lower external costs 9.04% both ways (9.34%), 3.08%
for imports only (3.30%). Mobility amplifies the near-corner response of New
Brunswick's refining to external liberalization (10% lower external costs in
both directions: real income +115%, +43% per person, population +50%; see
`docs/methodology_review.md`, section D).

### Errors fixed

- **"Eliminate non-geographic barriers" could cut costs below within-province
  costs.** Where the estimated geographic component was below one (negative
  distance or adjacency coefficients, mainly in mining support services,
  telecommunications and electronics: 64 interprovincial pairs, 1.2% of 2022
  trade), the shock lowered costs by more than eliminating all measured costs.
  The geographic component is now floored at one (`trade_costs$floor_geographic`;
  the Alvarez et al. replication keeps the paper's unfloored version). Main
  model without labour mobility, all sectors: 4.89% -> 4.64%; services: 4.45%
  -> 4.18%; goods unchanged.
- **Correction to the 2026-10-02 entry (A13).** That entry said the legacy
  level-distance gravity specification made the geographic component depend on
  the units of distance. It does not (the coefficient rescales). The legacy
  specification was that of Alvarez et al. (2019), with two departures (no
  interprovincial indicator; US and ROW own pairs without the intra-regional
  indicator). It is now implemented correctly as an option; the main model
  keeps the Albrecht-Tombe specification. `docs/methodology_review.md` is
  corrected.
- **Trade imbalances in the replications.** The replication setups removed
  imbalances by solving the model with zero deficits (`purge`), which also
  changes the trade shares (Canadian import shares fall by up to 4 points in
  2010). Both papers keep the observed trade shares and impose balanced trade
  on the levels (Albrecht and Tombe, proposition 1 and section 4.1; Alvarez et
  al., section IV). New option `calibration$deficits: balanced`, used by both
  setups (small effect: Albrecht and Tombe's gains from external trade 7.2% ->
  7.4%).
- **Distances in the Albrecht and Tombe replication.** The setup measured
  distance between population centroids; the paper (appendix B) uses the
  population-weighted mean distance between residents, whose internal
  distances are 1.3-1.5 times larger, so normalized distances are a quarter
  smaller and less of measured costs is geographic. New option
  `distances$method: pairwise` (`data/processed/distances_2021_pairwise.csv`).
  With it the paper's non-distance costs are reproduced (12.9% on average
  against its 14.5%; 8.0% before) and so is the gain from removing them (7.0%
  against 6.8%; 5.3% before).
- **Quebec experiment (Albrecht and Tombe, section 4.3.3).** The paper raises
  costs by 10% "if n or i is Quebec", i.e. on all of Quebec's trade including
  with the rest of the world; the scenario raised only interprovincial costs
  (Quebec -1.7% against the paper's -4.8%). It now follows the paper (-4.5%;
  Ontario -0.5%, Alberta -0.2%, as in the paper); the interprovincial version
  is kept as `quebec_border_10_provinces`.
- **Replication configurations.** `config/replication_albrecht_tombe_2016.yml`
  now follows the paper (balanced trade, asymmetric costs and the augmented
  Head-Ries index, real-GDP weights, 2010 data). `config/replication_tombe_2019.yml`,
  which reproduced the legacy script rather than the paper, is replaced by
  `config/replication_alvarez_krznar_tombe_2019.yml`. The Albrecht and Tombe
  bridge now ends exactly at the main model (it kept real-GDP weights).

### Methodology changes

- **Main-model internal-trade scenarios follow the papers' definitions.** The
  measured-cost experiments now cover all sectors, as in Albrecht and Tombe
  (previously goods only), with goods-only (Alvarez et al.) and services-only
  (Manucha and Tombe) variants; asymmetries and a cut in import costs only are
  added. Results without labour mobility: 10% lower measured costs 0.23%
  (goods) -> 0.67% (all sectors); eliminating all measured costs 9.92% (goods)
  -> 41.9%; eliminating non-geographic barriers 0.42% (goods) and 4.64% (all
  sectors).
- **External cost experiment.** Albrecht and Tombe's Table 5 figures (2.9% for a
  10% cut) are reproduced only when the cut applies to Canadian imports; a
  two-way cut gives more than twice as much. Both versions are provided
  (`t5c5_import_costs_minus10`: 3.08%; two-way: 9.04%).
- **Albrecht and Tombe's input-output parameters.** Their value-added and
  final-demand shares (Table 9, OECD STAN) are used in their setup
  (`io_parameters$sector_values`); the input coefficients, which the paper does
  not report, come from the 2010 supply and use tables. Gains from external
  trade 7.4% -> 8.4% (paper 9.3%), from all trade 14.6% -> 16.3% (18.3%).

### Added

- Exporter-specific (asymmetric) trade costs (Waugh, 2010), the augmented
  Head-Ries index (`trade_costs$measured_index: augmented`) and the
  `eliminate_asymmetries` experiment.
- The trade-cost decomposition of Alvarez et al. (2019): distance in thousands
  of km, neighbour indicator, interprovincial indicator by year, international
  pairs, optional within-region pairs (`trade_costs$regressors`, `$geographic`,
  `$year_interactions`, `$own_pairs`); `config/sensitivity_gravity_levels.yml`
  applies it to the main model (non-geographic barriers for goods: 5.08%; all
  sectors: 25.4%).
- Pairwise (Head and Mayer, 2002) distances (`distances$method: pairwise`).
- Published value-added and final-demand shares (`io_parameters$sector_values`)
  and elasticities used only to measure trade costs
  (`trade_costs$measurement_elasticities`; used to scale Alvarez et al.'s
  measured costs to their Table 1 in a diagnostic run).
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
  targeting, the three treatments of imbalances, pairwise distances, published
  sector values, measurement elasticities, configuration overrides and the
  benchmark file.

### Findings (see `docs/replication.md`)

- Albrecht and Tombe, on their 2010 data: their trade data (Table 1), measured
  costs (Table 4: 66.5% against 67.8%), distance elasticities (Table 11) and
  non-distance costs are reproduced, and so are their results: gains from
  internal trade 4.5% (paper 4.4%), 10% lower internal costs 3.4% (3.6%),
  measured-cost experiments 0.84% and 1.66% (0.9% and 1.8%), non-distance
  costs 7.0% (6.8%), all internal costs 53.1% (51.9%). Gains from external
  trade are 10% lower (8.4% against 9.3%; input-output coefficients) and
  removing asymmetries gives more (4.8% against 3.3%).
- Alvarez et al.: gains from trade reproduced (4.5 / 10.1 / 18.9 against 5.1 /
  10.9 / 19.6). Their measured costs cannot be reproduced from current data
  with the stated elasticities (79% against 55% on average, also when computed
  directly from their source table and product mapping); the other two papers'
  costs are. Hence larger non-geographic barriers and gains (goods, internal:
  5.6% against 3.8%; 4.3% with costs scaled to their Table 1). The main model's
  much smaller goods figure (0.46%) is due to the gravity specification.
- Manucha and Tombe: non-distance experiments reproduced by the main model (4.9
  vs 4.4; services 4.4 vs 4.2). Their 6.7% gain from a uniform 10% cut is not
  reproduced: the model gives 3.1-4.0%; the paper's own first-order
  approximation (its Table 2) gives 3.1%.
- The trade elasticities explain most of the remaining difference between the
  main model and Albrecht and Tombe: with the papers' elasticities the main
  model gives 3.23, 2.76, 0.84, 6.68 and 61.0 against 3.6, 2.9, 0.9, 6.8 and
  51.9. With the papers' distance measure its non-geographic gains would rise
  from 4.9% to about 6.3%; this needs Yukon's census points (the raw file).

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
