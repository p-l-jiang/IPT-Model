# Changelog

Substantive changes to the model, its data and its methods, newest first.
Purely organizational changes (file moves, renames, refactoring that does not
change results) are not listed. Item references (A1, ...) point to
[`docs/methodology_review.md`](docs/methodology_review.md), which explains each
problem in detail.

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
