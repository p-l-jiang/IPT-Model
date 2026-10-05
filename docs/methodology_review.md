# Review of the legacy code (October 2026)

This note records the technical and methodological problems found in the
original scripts and how each is resolved. The original scripts are preserved
in the repository history (commit `24ede19`, folder `src/`):

* `2006 Distance Calc.R`, `2011 Distance Calc.R`, `2021 Distance Calc.R`
* `GE Model Data Cleaning.R`, `GE Model Shares Calculation.R`, `GE Model Main.R`
  (the most recent version: 2022, ICIO 2025)
* `Tombe 2015 Replication R.R`, `Tombe 2015 Improvement R.R`,
  `Tombe 2019 Replication R.R`, `Tombe Improvement R.R` (earlier variants that
  repeated most of the code above)

Items are grouped by severity. "Verified" means the problem was reproduced
with the data in the repository. The dated summary of the resulting changes is
in [`CHANGELOG.md`](../CHANGELOG.md); the comparison of the corrected model
with the published results of the papers is in
[`replication.md`](replication.md).

## A. Errors that changed results

### A1. China and Mexico were missing from the rest of the world
`GE Model Data Cleaning.R` (and the 2019 scripts) dropped the ICIO rows and
columns of `CN1`, `CN2`, `MX1` and `MX2`, keeping `CHN` and `MEX`. In the
*extended* ICIO, however, the `CHN_*` and `MEX_*` rows and intermediate-use
columns are all zero: China's and Mexico's production is reported only under the
split codes. (The country regex `^[A-Z]{3}` also fails on these codes.) As a
result the rest of the world excluded China and Mexico entirely as producers,
i.e. about USD 48 trillion of a USD 151 trillion rest-of-world gross output in
2022 (about 32%), including two of the largest sources of US imports.
**Verified** on `ICIO2025_2022.csv`. *Fix:* all non-Canadian, non-US codes,
including the split codes, are mapped to ROW (`src/icio.R`).

### A2. The baseline was not an equilibrium
`GE Model Main.R` combined trade shares from the trade-flow data, final-demand
shares from the provincial supply and use tables, value-added and input shares
from the world input-output table, and incomes from GDP shares, and then imposed
balanced trade (`I_prime <- w_hat * L_hat * initial_income`). These pieces do not
satisfy the model's market-clearing conditions, so a counterfactual without any
shock would not return "no change"; every reported effect mixed the policy with
a re-balancing of inconsistent data. Interprovincial imbalances are large (2022:
deficits of about 20-30% of value added in Prince Edward Island, Nova Scotia and
New Brunswick and 41% in Yukon; surpluses of about 23% in Alberta and
Saskatchewan). Imposing balanced trade alone would change provincial real
incomes by between -30% (Yukon) and +31% (Saskatchewan).
*Fix:* the baseline is solved from the market-clearing conditions given the
observed trade shares, input-output and final-demand shares, with observed
deficits held fixed (Caliendo and Parro, 2015); `scripts/06_calibrate.R` checks
that a shock-free counterfactual returns the baseline to machine precision.
Purging deficits first is available as an option (see `docs/model.md`).

### A3. "Eliminate non-distance barriers" raised trade costs
`GE Model Main.R` (Table 6, column 4) and `Tombe 2019 Replication R.R` passed
the counterfactual *level* of trade costs (`tau_counterfactual = min(tau_geo,
tau_bar)`, which is at least one) to the solver as the *change* `tau_hat`. The
scenario therefore increased interprovincial trade costs instead of removing
their non-geographic part. *Fix:* `tau_hat = min(tau_geo / tau_bar, 1)`.

### A4. Table 6 shocks used the wrong year
The Table 6 loops in `GE Model Main.R` iterated over every row of the
trade-cost panel (all years 2007-2022) without filtering on the target year, so
each pair received the value of whichever year came last in the file. *Fix:* the
decomposition is computed for the calibration year only.

### A5. Population weights in the 2006 and 2011 distance files were factor codes
`2006 Distance Calc.R` and `2011 Distance Calc.R` read the census files with
`read.csv(stringsAsFactors = TRUE)` and then applied `as.numeric()` to the
population column, which returns factor level codes rather than populations if
the column is read as a factor. **Verified** for 2011: the committed
`2011_dist_mat.csv` is reproduced exactly (to 1e-15) by weighting with the
codes stored in `da_data.csv`, whose "populations" sum to 341 million. The 2011
normalized distances differ from correctly weighted ones by up to 43%. *Fix:*
census files are read as text and converted explicitly (`src/distance.R`); the
corrupted files were removed. The 2006 file is within about 6% of correctly
weighted 2021 values and is kept, flagged, for the 2015 replication.

### A6. Yukon was dropped from the 2021 distances
`2021 Distance Calc.R` recoded "Yukon Territory", but the 2021 census uses
"Yukon", so Yukon was filtered out; `dist_mat_final.csv` had 25 pairs with
missing distances and Yukon never entered the gravity regressions. *Fix:* census
records are matched to regions by province code (PRUID). The committed 2021
extract was produced by the legacy script and still lacks Yukon; regenerating it
requires the raw 2021 Geographic Attribute File (see `docs/data.md`). Until
then, pairs without distances are kept in the trade-cost decomposition, so
scenarios that use measured costs alone (Table 6, columns 1 and 5) still apply
to Yukon's trade; only the non-geographic component (column 4) is unidentified
for Yukon and left unchanged.

### A7. US trade was double-counted and inconsistent with total trade
`GE Model Data Cleaning.R` built province-US trade from table 12-10-0100-01 by
combining summary-level industries (including "Information and cultural
industries") with selected detailed industries, among them Telecommunications
(`BS517000`) and Other information services (`BS519000`), which are already part
of the summary aggregate. It also counted re-exports as US exports, although the
"International exports" of the trade-flow table from which US exports were
subtracted exclude re-exports (for Ontario in 2022, US exports were overstated
by CAD 20 billion and exports to the rest of the world understated by 20%).
Subtracting industry-based US levels from product-based totals could also turn
flows negative, and those were silently dropped. *Fix:* US shares of each
province's exports and imports are computed within table 12-10-0100-01 at a
single (detailed) aggregation level and applied to the totals of the trade-flow
table (`src/trade_flows.R`).

### A8. Sector misclassifications
The summary-level product "Transportation equipment" (passenger cars, light and
heavy trucks, aircraft, ships, rolling stock) was mapped entirely to "Other
transport equipment", with only "Motor vehicle parts" in "Motor vehicles":
Ontario's and Quebec's vehicle assembly was in the wrong sector, with the wrong
trade elasticity and input structure. The detailed product map used for final
demand had further departures from the ISIC sectors of the ICIO: newspapers,
periodicals and books in paper and printing (ISIC 58 is publishing); prepared
meals and drinks for immediate consumption in food manufacturing (ISIC 56);
steel pipes in fabricated metals (ISIC 24); synthetic rubber in rubber products
(ISIC 20); rental and leasing in finance (ISIC 77); aircraft maintenance in
transport equipment (ISIC 33); gold and used vehicles in "other services".
Products were also matched by name, so products renamed between releases (e.g.
"Education services" / "Educational services") silently fell out. *Fix:* one
code-based concordance at the detailed product level, following ISIC Rev. 4, is
used for both the trade flows and the supply and use tables; the tests check
that every code in the 2010-2022 data is mapped.

### A9. Migration did not conserve population
The migration block normalized labour changes with GDP shares
(`can_omega / sum(can_omega)`) instead of population shares, so the national
labour-market condition $\sum_n \ell_n \hat L_n = 1$ did not hold and total
Canadian population changed in the counterfactual. *Fix:* baseline population
shares (table 17-10-0005-01).

### A10. Income weights were deflated prices, and stale
Provincial incomes in the solver (`omega`) were GDP at market prices deflated by
the inter-city price index. The equilibrium requires nominal incomes. In
addition, the price index table ends in 2019, so the 2022 query returned no
provincial rows and `GE Model Main.R` read an `improvement_omega_data.csv` left
over from a 2019 run in another folder. *Fix:* incomes come from the consistent
calibration; the price index is used only, optionally, to weight provincial
outcomes in Canada-wide aggregates, with the year actually used reported.

### A11. "10% lower external costs" also changed US-ROW trade
In the 2019 and 2022 versions, "external" was implemented as "not both Canadian",
which also lowered costs between the United States and the rest of the world.
*Fix:* only pairs with exactly one Canadian region.

### A12. Trade elasticities did not follow the stated rule
`theta_data` was described as "BoC 2018 estimates where significant, otherwise
Caliendo-Parro, plus 2", but: agriculture (10.1) and food (4.6) used the 1993
values although the 2016 estimates are significant; refined petroleum was 72.1
instead of 71.1 and wood 17.7 instead of 17.8; computers used the electrical
machinery value (14.3) instead of the "medical and communication" value (11.8);
motor vehicles was 7.0, which matches neither estimate; energy extraction used
the metal-ores value (45.0) instead of oil and gas (20.2); and mining support, a
service, received 45.0. *Fix:* elasticities are derived by code from the
transcribed BoC table and a component map
(`config/parameters/`), with an audit table written to
`trade_elasticities.csv`. Two judgment calls are documented: motor vehicles has
t = 4.5/2.3 = 1.957 < 1.96, so the rule gives 1.0 + 2 = 3.0; and the rule as
stated uses one BoC component per model sector except paper and printing (the
pharmaceutical, aircraft, non-metallic minerals and forestry components are not
averaged in).

### A13. Gravity specification
`GE Model Shares Calculation.R` followed Alvarez, Krznar and Tombe (2019) in
regressing log trade costs on distance in kilometres, in levels, on a sample
that pooled interprovincial and international pairs. Unlike the paper, it
omitted the interprovincial-trade indicator and included the US-US and ROW-ROW
own pairs (log cost zero by construction) without the internal-trade dummy it
used for provinces, so the distance coefficient was partly identified from
pairs with zero cost by construction. The adjacency list was asymmetric (NS-NL,
PE-NB, BC-NT and MB-NT appeared in one direction only). *Fix:* the main model
uses the specification of Albrecht and Tombe (2016), log distance relative to
internal distances $d_{ni}/\sqrt{d_{nn}d_{ii}}$ on interprovincial pairs, with
symmetric adjacency (land borders and the Confederation Bridge) and standard
errors clustered by origin and destination. The specification of Alvarez et al.
is implemented correctly as an option (own pairs excluded, interprovincial
indicator by year; `config/sensitivity_gravity_levels.yml`).

*Correction (2026-10-05).* An earlier version of this note said that distance
in levels made the geographic component depend on the units of distance. It
does not: the coefficient rescales with the units, so $b \cdot d$ is
unchanged. The choice between the two specifications is a modelling choice,
not an error, and it matters a great deal for the share of measured costs
called non-geographic (see `docs/replication.md`).

### A14. Sectoral results were not sectoral
`analyze_sectoral_results_by_region()` reported $\hat w \hat L / \hat p_j$ as
"sectoral GDP change", which is regional income deflated by a sectoral price,
not an outcome of the sector. *Fix:* sectoral gross output (and value added)
changes $\hat R_{nj}$ and employment changes $\hat R_{nj}/\hat w_n$.

### A15. "Eliminate all measured costs" could raise costs
The shock $1/\bar\tau$ was applied whenever $\bar\tau > 0$, raising costs for
pairs with measured costs below one. *Fix:* capped at one.

### A16. "Eliminate non-geographic barriers" could cut below within-province costs
*(Added 2026-10-05.)* The legacy code (`tau_counterfactual = pmin(tau_cf_raw,
tau_bar)`) and the first version of the unified model lowered costs to the
geographic component $\tau^{geo}$ even where it is below one, i.e. where a
negative distance or adjacency coefficient predicts that trading with another
province is cheaper than trading within one. For those pairs the shock exceeded
the elimination of all measured costs. In the 2022 main model this affected 64
interprovincial pairs (1.2% of trade, mainly mining support services,
telecommunications and electronics). *Fix:* $\tau^{geo}$ is floored at one
(`trade_costs$floor_geographic`); Canada's gain from eliminating
non-geographic barriers in all sectors falls from 4.89% to 4.64%.

## B. Numerical issues

* The wage update was a damped fixed point with an arbitrary damping factor;
  with trade elasticities as high as 71 it oscillates or diverges (in the
  restructured model, the undamped version produced negative value added in the
  first scenario). *Fix:* Newton's method with line search (3-8 steps).
* The intermediate-demand loop stopped after 50 iterations and the price loop
  after 100, without checking convergence. *Fix:* the expenditure system is
  solved exactly as a linear system and the price contraction to $10^{-13}$, with
  errors raised on non-convergence.
* The legacy ROW internal distance used the Earth's total surface (including
  oceans) minus the US and Canada (490.6 million km²) instead of land area
  (130.8 million km²): 8,331 km instead of 4,302 km. *Fix* (matters only when
  international pairs enter the gravity regressions).
* In the 2021 distance script, ROW-to-province rows took ROW's internal distance
  for the province (`mutate(d_nn_o = d_nn_row, d_nn_d = d_nn_o)` evaluates
  sequentially). *Fix.*
* The 2007 exchange rate averages May-December only (the series starts in May
  2007). *Fix:* partial years are flagged and rejected.

## C. Engineering

* Hard-coded `setwd()` paths, `View()` calls, package installation at run time,
  and objects defined in one script but used in another (`provincesplus`,
  `sut_product_to_sector_map_use`), so no script ran on its own.
* About 10,000 lines duplicated across five variants of the model.
* Intermediate files written to and read from different folders.
* No tests.

The restructured repository has one configurable pipeline (`scripts/`), a
function library (`src/`), configuration and concordances under version
control (`config/`), a test suite (93 expectations) and an independent
cross-check of the solver
(`tests/`).

## D. Issues flagged but not changed

* **Tariffs as iceberg costs.** By default, tariffs in the US-tariff scenarios
  are modelled as iceberg costs on all sectors, as before. This overstates the
  losses of the imposing country (no tariff revenue, no terms-of-trade gain) and
  taxes services. Ad valorem tariffs with revenue rebated to the importer, on
  goods only, are implemented and can be selected
  (`config/variant_tariffs_ad_valorem.yml`); for a 35% US tariff they reduce the
  estimated real-income loss for Canada from 2.35% to 1.44%.
* **Very high trade elasticities.** The BoC rule gives 71.1 for refined
  petroleum, 45.0 for metal ores and 20.2 for oil and gas. With constant returns,
  such values produce near-corner responses: a 10% cut in Canada's external
  trade costs makes New Brunswick's refining output grow about 100-fold and
  capture most US petroleum imports. `config/sensitivity_theta_papers.yml`
  re-runs the model with the elasticities of the Tombe papers.
* **No congestion force with migration.** With labour mobility there is no fixed
  factor (land, housing) to offset agglomeration; results with migration should
  be read with this in mind.
* **Industry-based US shares** are applied to product-based totals (see
  `docs/data.md`).
