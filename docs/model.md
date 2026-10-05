# The model

IPT-Model is a static, multi-sector Ricardian trade model with input-output
linkages in the tradition of Eaton and Kortum (2002) and Caliendo and Parro
(2015), applied to Canada's provinces and territories as in Albrecht and Tombe
(2016). This note states the equations solved by `src/solver.R`, the
calibration in `src/calibration.R` and the trade-cost measurement in
`src/trade_costs.R`.

## Notation

| Symbol | Meaning |
|---|---|
| $n, i$ | destination (importer) and origin (exporter) regions, $N$ in total |
| $j, k$ | sectors, $J$ in total |
| $\pi_{nij}$ | share of region $n$'s spending on sector $j$ that is bought from $i$ |
| $\phi_{nj}$ | value-added share of gross output in sector $j$ of region $n$ |
| $\gamma_{nkj}$ | share of input $k$ in the intermediate-input bill of sector $j$ in $n$ ($\sum_k \gamma_{nkj}=1$) |
| $\beta_{nj}$ | share of sector $j$ in final demand of region $n$ ($\sum_j \beta_{nj}=1$) |
| $\theta_j$ | trade elasticity (Fréchet shape parameter) of sector $j$ |
| $\tau_{nij}$ | iceberg trade cost from $i$ to $n$ |
| $t_{nij}$ | ad valorem tariff levied by $n$ on imports from $i$ |
| $X_{nj}$ | total expenditure of $n$ on sector-$j$ goods (at destination prices) |
| $R_{ij}$ | gross output (revenue) of sector $j$ in $i$ |
| $VA_n = w_n L_n$ | value added (labour income) of $n$ |
| $D_n$ | trade deficit of $n$; $\sum_n D_n = 0$ |
| $I_n$ | final expenditure (income) of $n$ |

## Equilibrium

Each sector produces a continuum of varieties with Fréchet-distributed
productivity. Unit costs combine labour and a Cobb-Douglas bundle of
intermediate inputs, $c_{ij} \propto w_i^{\phi_{ij}} \prod_k P_{ik}^{(1-\phi_{ij})\gamma_{ikj}}$,
and buyers source each variety from the cheapest origin, so

$$\pi_{nij} = \frac{\lambda_{ij}\,(\kappa_{nij} c_{ij})^{-\theta_j}}{\sum_m \lambda_{mj}\,(\kappa_{nmj} c_{mj})^{-\theta_j}},
\qquad P_{nj} \propto \Big(\sum_i \lambda_{ij}(\kappa_{nij} c_{ij})^{-\theta_j}\Big)^{-1/\theta_j},$$

with $\kappa_{nij} = \tau_{nij}(1+t_{nij})$. Market clearing:

$$X_{nj} = \sum_k \gamma_{njk}(1-\phi_{nk}) R_{nk} + \beta_{nj} I_n,
\qquad R_{ij} = \sum_n \frac{\pi_{nij} X_{nj}}{1+t_{nij}},$$

$$VA_n = \sum_j \phi_{nj} R_{nj},
\qquad I_n = VA_n + D_n + \sum_{i,j} \frac{t_{nij}}{1+t_{nij}}\,\pi_{nij} X_{nj}.$$

Tariff revenue is rebated lump-sum to the importing region. Labour moves freely
across sectors within a region. Final demand includes household, NPISH and
government consumption, investment and inventory changes (the model is static).

## Equilibrium in changes

For a shock $(\hat\tau, t')$, write $\hat x = x'/x$ and
$\hat\kappa_{nij} = \hat\tau_{nij}(1+t'_{nij})/(1+t_{nij})$. Given baseline
$(\pi, \phi, \gamma, \beta, \theta, VA, D, X, R)$, the counterfactual solves

$$\hat c_{ij} = \hat w_i^{\phi_{ij}} \prod_k \hat P_{ik}^{(1-\phi_{ij})\gamma_{ikj}}$$

$$\hat P_{nj} = \Big(\sum_i \pi_{nij}(\hat\kappa_{nij}\hat c_{ij})^{-\theta_j}\Big)^{-1/\theta_j},
\qquad \pi'_{nij} = \pi_{nij}\Big(\frac{\hat\kappa_{nij}\hat c_{ij}}{\hat P_{nj}}\Big)^{-\theta_j}$$

together with the market-clearing conditions above evaluated at $(\pi', t')$,
$VA'_n = \hat w_n \hat L_n VA_n$ and the numeraire $\sum_n VA'_n = \sum_n VA_n$
(world value added). Deficits are held fixed in units of world value added,
$D'_n = D_n$ (Caliendo and Parro, 2015), unless a scenario changes them.

**Labour mobility (optional).** With location preferences drawn from a Fréchet
distribution with dispersion $\kappa$, population in the mobile regions
$\mathcal M$ (the provinces and territories) satisfies

$$\hat L_n = \frac{\hat U_n^{\kappa}}{\sum_{m\in\mathcal M} \ell_m \hat U_m^{\kappa}},
\qquad \hat U_n = \frac{\hat I_n}{\hat L_n \hat P_n},
\qquad \hat P_n = \prod_j \hat P_{nj}^{\beta_{nj}},$$

where $\ell_m$ are baseline **population** shares, so that total population in
$\mathcal M$ is unchanged. Population outside $\mathcal M$ is fixed.

## Outcomes

* Real income: $\hat I_n/\hat P_n$; per capita: $\hat I_n/(\hat L_n\hat P_n)$; real wage: $\hat w_n/\hat P_n$.
  With balanced trade, no tariffs and no migration all three coincide and equal
  the familiar $\hat w_n/\hat P_n$.
* Canada-wide real income: weighted average of provincial changes with weights
  set by `aggregation$canada_weights` (baseline income shares by default;
  `real_income` deflates incomes by the inter-city price index; `population`).
* Sectoral gross output and value added change by $\hat R_{nj}$; sectoral
  employment by $\hat R_{nj}/\hat w_n$ (labour is paid the same wage in all
  sectors of a region and $\phi$ is fixed).

A useful check, used in the test suite: with one sector and balanced trade,
$\hat I_n/\hat P_n = \hat\pi_{nn}^{-1/(\theta\phi)}$ (Arkolakis, Costinot and
Rodríguez-Clare, 2012, with a roundabout input-output structure).

## Calibration

Trade shares $\pi$, value-added shares $\phi$, input shares $\gamma$ and
final-demand shares $\beta$ are taken from the data (see `docs/data.md`); $\phi$
and $\gamma$ are region-specific by default. Deficits are the observed gross
trade imbalances implied by the bilateral flow matrix,
$D_n = \sum_{i,j} F_{nij} - \sum_{m,j} F_{mnj}$, which sum to zero.

Given $(\pi, \phi, \gamma, \beta, D)$, expenditures, revenues and value added
are then **solved from the market-clearing conditions** rather than taken from
separate sources. Writing expenditure as a function of income other than tariff
revenue, $x = H\,(VA + D)$, value added satisfies $VA = M(VA + D)$ with
$M = \Phi A H$; the columns of $M$ sum to one, so the system is solved with the
normalization $\sum_n VA_n = $ observed world value added. The result is an
exact equilibrium: a counterfactual with $\hat\tau = 1$ returns $\hat w = \hat P
= 1$ to machine precision (checked by `scripts/06_calibrate.R` on every run). The
gap between model-implied and observed value added is reported in
`baseline_diagnostics.csv` (0.3-6% by region in 2022).

With `calibration$deficits: purge`, the model is first solved with $D' = 0$ and
that balanced-trade equilibrium becomes the baseline.

## Solution algorithm

1. *Prices.* For given wages, $\log\hat P$ solves a contraction (the composition
   of a log-sum-exp and a linear map with weights $1-\phi<1$), iterated to
   $10^{-13}$, in logs to handle trade elasticities up to about 70.
2. *Expenditure.* Given $\pi'$ and $t'$, $X'$ solves a linear system of size
   $NJ$, built from the block structure of the input-output and trade matrices.
3. *Wages and population.* Newton's method on the $N$ (+ number of mobile
   regions) equilibrium conditions: relative excess labour demand in all regions
   but one (Walras' law makes the last redundant), the numeraire, and the
   migration conditions. The Jacobian is computed by finite differences and
   steps are chosen by backtracking line search. Convergence is declared when
   all residuals are below $10^{-10}$; typical scenarios converge in 3-8 steps.

An independent NumPy implementation solved with MINPACK
(`tests/crosscheck/solver_crosscheck.py`) reproduces the R solution to about
$10^{-13}$, including tariffs and migration on the calibrated 2022 baseline.

## Measured trade costs

For each sector, the Head and Ries (2001) index measures bilateral trade costs
relative to internal trade costs:

$$\bar\tau_{nij} = \left(\frac{\pi_{nnj}\,\pi_{iij}}{\pi_{nij}\,\pi_{inj}}\right)^{1/(2\theta_j)},$$

which equals $\sqrt{\tau_{nij}\tau_{inj}/(\tau_{nnj}\tau_{iij})}$ in the model.
It is symmetric and defined when trade is positive in both directions.

**Geographic decomposition.** Measured costs are decomposed by
sector-specific regressions pooled over the panel years,

$$\log\bar\tau_{nit} = \sum_k b_k\,x_{k,ni} + \mu_{nt} + \nu_{it} + \varepsilon_{nit},$$

estimated by OLS with exporter-year and importer-year fixed effects and
standard errors clustered by origin and destination. The geographic component
is $\tau^{geo}_{ni} = \exp(\sum_{k\in G} b_k x_{k,ni})$ over the geographic
regressors $G$; the non-geographic component $\bar\tau/\tau^{geo}$ contains
the fixed effects, any border indicators and the residual. Two specifications
are implemented (`trade_costs` in the configuration):

* *Albrecht and Tombe (2016)*, the default: $x$ = log distance relative to
  internal distances, $\log(d_{ni}/\sqrt{d_{nn}d_{ii}})$, and (in the main
  model) an adjacency indicator, estimated on interprovincial pairs over
  2010-2022. The geographic component is unit-free and equals one for pairs as
  close as the average within-region distance.
* *Alvarez, Krznar and Tombe (2019)*: $x$ = distance in thousands of km and a
  neighbour indicator, plus an interprovincial-trade indicator by year that is
  not part of $G$, estimated on interprovincial and international pairs
  (`config/sensitivity_gravity_levels.yml`).

The share of measured costs attributed to geography depends heavily on this
choice: normalized distance jumps from 1 within a region to about 4-30
between provinces, so the log specification attributes most of the cost of
crossing a provincial border to geography; distance in levels attributes it to
the non-geographic component. Neither is identified by interprovincial data
alone (see `docs/replication.md`).

**Asymmetric costs.** Following Waugh (2010) and Albrecht and Tombe (2016,
appendix B), let $\tau_{nij} = t^{s}_{nij}\,t_{ij}$ with a symmetric part and
an exporter-specific cost $t_{ij}$. Then

$$\log\frac{\pi_{nij}}{\pi_{nnj}} = g_j\,x_{ni} + \iota_{nj} + \eta_{ij} + e_{nij},$$

estimated on interprovincial pairs with importer-year and exporter-year fixed
effects, identifies $\log t_{ij} = -(\iota_{ij} + \eta_{ij})/\theta_j$ (the
sum of a region's importer and exporter effects, which does not depend on the
normalization of the fixed effects). Removing asymmetries lowers each cost to
that of the cheaper direction, $\hat\tau_{nij} = \min(1, t_{nj}/t_{ij})$. The
augmented index $\tilde\tau_{nij} = \bar\tau_{nij}(t_{ij}/t_{nj})^{1/2} =
\tau_{nij}/\sqrt{\tau_{nnj}\tau_{iij}}$ measures directional costs and is used
by the measured-cost scenarios when `trade_costs$measured_index` is
`augmented` (as in Albrecht and Tombe's Table 6).

`scripts/05_estimate_trade_costs.R` writes the decomposition for every pair
with two-way trade in the calibration year, the exporter-specific costs and
trade-weighted summaries (`trade_cost_summary.csv`): measured costs
$\bar\tau - 1$, the geographic component, the non-geographic component (as
$\bar\tau - \tau^{geo}$ and $\bar\tau/\tau^{geo} - 1$) and the
contribution of asymmetries $\max(1, t_i/t_n) - 1$.

## Scenarios

| Scenario type | Change in trade costs |
|---|---|
| `iceberg` | $\hat\tau = $ `factor` for the listed importer-exporter pairs (never for own trade) |
| `tariff` (`iceberg` treatment, default) | $\hat\tau = 1 + $ `rate`; no tariff revenue (legacy) |
| `tariff` (`ad_valorem` treatment) | $t' = t + $ `rate`; revenue rebated to the importer |
| `autarky` | $\hat\tau = \infty$ for the listed pairs |
| `measured_cost_reduction` | $\hat\tau = (1 + (1-s)(\bar\tau - 1))/\bar\tau$ for $\bar\tau>1$ ($\tilde\tau$ with the augmented index) |
| `eliminate_nongeographic` | $\hat\tau = \min(\max(\tau^{geo}, 1)/\bar\tau, 1)^{f}$ |
| `eliminate_asymmetries` | $\hat\tau = \min(1, t_n/t_i)^{f}$ |
| `eliminate_measured` | $\hat\tau = \min(1/\bar\tau, 1)^{f}$ |

The measured-cost shocks apply in the calibration year to the listed
importer-exporter pairs (interprovincial pairs by default) and sectors; $f$
(`fraction`, default 1) is the share of the log cost removed, so two shocks
with $f = 1/2$ remove the geometric average of two measures. Pairs without an
estimate are left unchanged; in particular, pairs without distance data
(Yukon, with the committed census extract) have no $\tau^{geo}$. The floor
$\max(\tau^{geo}, 1)$ keeps geography from making trade with another region
cheaper than trade within one (`trade_costs$floor_geographic: false` removes
it, as in Alvarez et al., 2019).

**Gains from trade.** With `report: gains_from_trade`, a scenario of
prohibitive costs is reported as the gain of the observed equilibrium relative
to the counterfactual, $1/\hat x - 1$ for every outcome $x$, and the
Canada-wide figure averages the regional gains with baseline weights (Albrecht
and Tombe, 2016, proposition 3). With balanced trade and one sector this is the
Arkolakis-Costinot-Rodríguez-Clare formula $\pi_{nn}^{-1/(\theta\phi)} - 1$
(checked in the test suite). Isolating a group of regions requires their trade
imbalances to sum to zero, so these experiments are run on balanced-trade
baselines (`calibration$deficits: purge`); the solver stops if a region is left
without any supplier of a good it uses.

## References

* Albrecht, L. and T. Tombe (2016). "Internal trade, productivity and
  interconnected industries: A quantitative analysis." *Canadian Journal of
  Economics* 49(1): 237-263.
* Arkolakis, C., A. Costinot and A. Rodríguez-Clare (2012). "New trade models,
  same old gains?" *American Economic Review* 102(1): 94-130.
* Caliendo, L. and F. Parro (2015). "Estimates of the trade and welfare effects
  of NAFTA." *Review of Economic Studies* 82(1): 1-44.
* Charbonneau, K. B. and A. Landry (2018). "Estimating the impacts of tariff
  changes: Two illustrative scenarios." Bank of Canada Staff Analytical Note
  2018-29.
* Dekle, R., J. Eaton and S. Kortum (2008). "Global rebalancing with gravity:
  Measuring the burden of adjustment." *IMF Staff Papers* 55(3): 511-540.
* Eaton, J. and S. Kortum (2002). "Technology, geography, and trade."
  *Econometrica* 70(5): 1741-1779.
* Head, K. and J. Ries (2001). "Increasing returns versus national product
  differentiation as an explanation for the pattern of US-Canada trade."
  *American Economic Review* 91(4): 858-876.
* Head, K. and T. Mayer (2002). "Illusory border effects: Distance mismeasurement
  inflates estimates of home bias in trade." CEPII Working Paper 2002-01.
* Alvarez, J., I. Krznar and T. Tombe (2019). "Internal trade in Canada: Case
  for liberalization." IMF Working Paper 19/158.
* Manucha, R. and T. Tombe (2022). *Liberalizing internal trade through mutual
  recognition: A legal and economic analysis.* Macdonald-Laurier Institute.
* Tombe, T. and X. Zhu (2019). "Trade, migration, and productivity: A
  quantitative analysis of China." *American Economic Review* 109(5): 1843-1872.
* Waugh, M. E. (2010). "International trade and income differences." *American
  Economic Review* 100(5): 2093-2124.
