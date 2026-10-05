# Comparison with the published results

This note compares the model with the three studies it builds on:

* **A&T**: Albrecht, L. and T. Tombe (2016), "Internal trade, productivity and
  interconnected industries: A quantitative analysis", *Canadian Journal of
  Economics* 49(1). Figures are from the May 2015 working paper version.
* **AKT**: Alvarez, J., I. Krznar and T. Tombe (2019), "Internal trade in
  Canada: Case for liberalization", IMF Working Paper 19/158.
* **MLI**: Manucha, R. and T. Tombe (2022), *Liberalizing internal trade
  through mutual recognition: A legal and economic analysis*,
  Macdonald-Laurier Institute.

For each paper a configuration reproduces its setup as closely as the data
allow (`config/replication_*.yml`), and its experiments are defined in
`config/scenarios/` with the paper's experiment names. The published figures
are transcribed in `config/benchmarks/published_results.csv`.
`scripts/replication/run_replications.R` runs everything, compares the model
with the published figures and runs "bridges": sequences of variants that move
one setting at a time from a paper's setup to the main model
(`config/default.yml`). Its outputs are in `output/replication/`.

```sh
Rscript scripts/replication/run_replications.R               # all papers, about 30 minutes
Rscript scripts/replication/run_replications.R --group akt   # one paper: at, akt or mli
```

All figures are percent changes in real income (real GDP) for Canada unless
noted.

## Summary

| Experiment | Published | Paper setup | Main model (2022) | Assessment |
|---|---:|---:|---:|---|
| **A&T** gains from trade: all / internal / external | 18.3 / 4.4 / 9.3 | 16.7 / 4.2 / 9.2 | n.a. | Reproduced |
| A&T 10% lower interprovincial costs | 3.6 | 3.15 | 3.68 | Reproduced |
| A&T 10% lower external costs | 2.9 | 2.73 | 3.30 | Reproduced as a cut in import costs only (both directions: 6.25 and 9.34) |
| A&T 10% lower measured internal / external costs | 0.9 / 1.8 | 0.82 / 1.78 | 0.67 / n.a. | Reproduced |
| A&T eliminate non-distance costs | 6.8 | 6.37 | 4.64 | Reproduced; lower in the main model (elasticities) |
| A&T eliminate all measured internal costs | 51.9 | 57.6 | 41.9 | Reproduced; lower in the main model (elasticities) |
| A&T eliminate asymmetries | 3.3 | 5.11 | 4.43 | Larger: current data show larger asymmetries |
| **AKT** gains from trade: internal / external / all | 5.1 / 10.9 / 19.6 | 4.5 / 10.0 / 18.9 | n.a. | Reproduced |
| AKT eliminate non-geographic barriers, goods, internal | 3.8 | 5.16 | 0.42 (4.96)* | 1.4 times larger in the paper setup; specification-dependent |
| AKT same, external / internal and external | 6.2 / 9.1 | 14.4 / 16.6 | n.a. | 2 times larger |
| AKT internal, uniform goods elasticity 4 / 6.5 / 8 | 7.3 / 4.6 / 3.2 | 10.7 / 6.7 / 5.5 | n.a. | Same pattern, 1.5 times larger |
| **MLI** uniform 10% lower interprovincial costs | 6.7 | 3.10 | 3.68 | Not reproduced; the paper's own rule of thumb gives 3.1 |
| MLI remove non-distance costs: all / services | 4.4 / 4.2 | 7.0 / 6.7 | 4.64 / 4.18 | Reproduced by the main model; the 17-sector setup overstates (5.7 / 5.4 with 37 sectors) |
| MLI remove asymmetries: all / services | 7.9 / 4.6 | 5.0 / 4.2 | 4.43 / n.a. | Lower |

\* With the main model's gravity specification (Albrecht and Tombe); 4.96 with
the specification of Alvarez et al. (`config/sensitivity_gravity_levels.yml`).

The main conclusions:

1. **The model reproduces Albrecht and Tombe closely** (gains from trade, the
   elasticity of welfare to trade costs, and the measured-cost experiments), at
   the national level and in the provincial pattern, using 2016 instead of 2010
   data. Their measured trade costs are also reproduced (70.5% vs 67.8% on
   average, nearly identical in several sectors). Their "10% lower external
   costs" figures (Table 5) are reproduced only if the cut applies to Canadian
   imports, not to both directions.
2. **The gains from trade of Alvarez et al. are reproduced; their
   non-geographic barriers are not.** With their specification the model gives
   1.4 (internal) to 2.3 (external) times their gains, because measured trade
   costs in current Statistics Canada data are higher than the paper reports
   (79.5% vs 55.1% on average, including in services, whose elasticity of 5 is
   known) and the United States' non-geographic barriers come out much larger.
   The main model's much smaller goods result (0.42% vs 3.8%) is almost entirely
   due to the gravity specification, not to an error.
3. **Manucha and Tombe's non-distance experiments are reproduced by the main
   model** (4.6% vs 4.4%, and 4.2% vs 4.2% for services). Its goods elasticities
   are not published but can be recovered from its Table 1 (manufacturing 8.9,
   mining 15.8, agriculture 6.9). The paper's 6.7% gain from a uniform 10% cut in
   interprovincial costs is not reproduced: our model gives 3.1-3.7%, which is
   what the paper's own first-order approximation (its Table 2) implies.
4. **Which share of trade costs is "policy-relevant" is the main source of
   uncertainty**, not the solver or the data. In the same 2022 data, the two
   published decompositions leave on average 3-10% (log distance relative to
   internal distance; the higher figure counts positive values only) or 42%
   (distance in levels) of measured interprovincial costs as non-geographic,
   and the gains from removing them range from 4.6% to 23%.

## Setups compared

| | A&T | AKT | MLI | Main model |
|---|---|---|---|---|
| Data year (paper / our setup) | 2010 / 2016 | 2015 / 2016 | 2018 / 2018 | 2022 |
| Regions | 10 provinces, ROW | 12 (NT and NU merged), US, ROW / 13, US, ROW | 13, ROW | 13, US, ROW |
| Sectors | 22 | 18 | 32 / 17 | 37 |
| Input-output | national | national | not stated / regional | regional |
| Trade elasticities, goods | Caliendo-Parro (their Table 9) | Caliendo-Parro (not listed) / averaged as in A&T | Fontagné et al. (not listed) / recovered from Table 1 | BoC 2018 rule |
| Trade elasticity, services | 5 | 5 | 5 | 7 |
| Trade imbalances | balanced | balanced | federal transfers / observed | observed |
| Labour mobility | none | 1.5 | yes / 1.5 | none |
| Gravity regressors | log normalized distance | distance (1000 km), neighbour, interprovincial x year | log normalized distance | log normalized distance, adjacency |
| Gravity sample | provinces, one year | provinces, US, ROW, 1997-2015 / 2016-2022 | provinces, one year | provinces, 2010-2022 |
| Asymmetric costs | yes (Waugh) | no | yes | yes (reported) |
| Canada aggregate | real GDP shares | nominal GDP shares | not stated / income shares | income shares |

Data year. The repository holds the ICIO tables for 2016-2022, so A&T and AKT
are run on 2016 data. The A&T setup gives nearly the same results on 2016,
2018 and 2022 data (10% lower internal costs: 3.15, 3.20, 3.22; gains from
internal trade: 4.22, 4.23, 4.23; eliminating non-distance costs: 6.37, 6.27,
5.81), so the year is unlikely to explain the differences below. With the 2010
and 2015 ICIO tables in `data/raw/icio/`, set `years` in the configurations.

## Albrecht and Tombe (2016)

**Trade costs.** The paper's measured costs (Head-Ries index, Table 4) are
reproduced: 70.5% on average against 67.8%, with identical values for
chemicals and rubber (12.5 vs 12.5), wholesale and retail (102 vs 102) and
education (231 vs 230) and close ones for finance (88 vs 92), transport (80 vs
84) and metals (60 vs 63).
The non-distance component averages 10.7% against 14.5%; it is small or
negative for goods (-12% to 0% here, -8% to +12% in the paper; agriculture and
mining -8.5 vs -8.3) and large for services (education 101 vs 105, health 82 vs
83, hotels and restaurants 31 vs 29, wholesale and retail 16 vs 15). The
asymmetric (exporter-specific) costs are larger in current data: 11.5% on
average against 7.8%, with the largest differences for exports from
Newfoundland and Labrador (34 vs 14), Manitoba (25 vs 12), Quebec (22 vs 13) and
Prince Edward Island (43 vs 30).

**Results by province** (published / paper setup):

| | Gains from internal trade | 10% lower internal costs | 10% lower import costs | Eliminate non-distance costs | Eliminate asymmetries |
|---|---|---|---|---|---|
| AB | 4.7 / 5.2 | 3.6 / 3.7 | 2.5 / 2.4 | 5.5 / 6.0 | 2.4 / 2.8 |
| BC | 4.7 / 4.2 | 3.9 / 3.3 | 2.9 / 2.7 | 4.9 / 5.0 | 2.8 / 2.7 |
| MB | 8.1 / 7.2 | 6.0 / 5.2 | 2.5 / 2.4 | 8.4 / 11.7 | 5.2 / 8.8 |
| NB | 8.1 / 7.9 | 6.5 / 6.0 | 4.7 / 3.8 | 28.3 / 26.5 | 8.0 / 9.1 |
| NL | 7.7 / 6.5 | 6.6 / 4.6 | 3.0 / 3.1 | 23.5 / 22.5 | 5.0 / 9.3 |
| NS | 7.5 / 6.9 | 6.1 / 5.2 | 3.0 / 2.5 | 24.3 / 19.7 | 7.9 / 8.8 |
| ON | 3.2 / 3.1 | 2.6 / 2.3 | 3.1 / 2.9 | 3.2 / 2.5 | 2.8 / 5.2 |
| PE | 11.4 / 10.4 | 7.2 / 7.2 | 2.1 / 1.7 | 35.1 / 43.5 | 18.6 / 20.5 |
| QC | 4.2 / 3.8 | 3.5 / 2.9 | 2.9 / 2.6 | 7.1 / 7.1 | 2.5 / 5.0 |
| SK | 7.1 / 7.4 | 5.2 / 5.2 | 3.0 / 2.7 | 17.2 / 17.8 | 8.7 / 11.4 |
| Canada | 4.4 / 4.2 | 3.6 / 3.2 | 2.9 / 2.7 | 6.8 / 6.4 | 3.3 / 5.1 |

Other experiments (published / paper setup): gains from all trade 18.3 / 16.7;
from external trade 9.3 / 9.2; 10% lower measured internal costs 0.9 / 0.8 and
external costs 1.8 / 1.8; eliminating all measured internal costs 51.9 / 57.6;
halving measured internal costs 7.6 / 7.4; 10% higher costs between Quebec and
the other provinces: Alberta -0.2 / -0.2, Ontario -0.5 / -0.6.

**Diagnosis.**

* *External costs.* Lowering the costs of trade between Canada and the rest of
  the world by 10% in both directions gives 6.25%, more than twice the paper's
  2.9%. Lowering only the costs of Canadian imports gives 2.73% and the paper's
  provincial pattern (above). Lowering only export costs gives 2.40%. The
  paper's Table 5 figures therefore correspond to a cut in import costs (or to a
  rest of the world that does not respond to cheaper Canadian goods), although
  the text suggests both directions. Its Table 6 experiment on measured external
  costs, by contrast, matches the two-way cut (1.78 vs 1.8). The scenario files
  keep both versions (`iceberg_external_10`, `iceberg_external_10_two_way`).
* *Asymmetries.* The gains from removing asymmetries (5.1% vs 3.3%) follow from
  the larger exporter-specific costs in current data. The estimation follows
  the paper (appendix B) and is tested on synthetic data with known costs.
* *Gains from all trade* are somewhat lower for Newfoundland and Labrador (29
  vs 49) and New Brunswick (31 vs 42), whose trade structure changed between
  2010 and 2016; the national figure is close (16.7 vs 18.3).

## Alvarez, Krznar and Tombe (2019)

The paper's trade-cost decomposition, which the model did not implement before,
was added: distance in thousands of km and a neighbour indicator form the
geographic component; an interprovincial-trade indicator by year and the
exporter-year and importer-year fixed effects are non-geographic; the
regressions pool interprovincial and international pairs.

**Gains from trade** are reproduced (published / paper setup): internal 5.1 /
4.5, external 10.9 / 10.0, all 19.6 / 18.9, with the same provincial pattern
(e.g. internal: Ontario 4.4 / 3.4, Prince Edward Island 12.6 / 10.8, Manitoba
8.3 / 7.4) and employment responses of the same sign and similar size for most
provinces. Exceptions are Nova Scotia's external gains (23.7 / 9.2) and the
northern territories' total gains (28.8 / 54.6 for NT and NU).

**Eliminating non-geographic barriers for goods** gives larger gains than the
paper: internal 5.2 vs 3.8, external 14.4 vs 6.2, both 16.6 vs 9.1. By province
(internal, published / paper setup): AB 3.2 / 4.3, BC 2.8 / 4.1, MB 7.1 / 10.4,
NB 6.0 / 12.8, NL 12.8 / 14.2, NS 4.8 / 10.3, ON 2.9 / 3.9, PE 16.2 / 23.3, QC
4.6 / 5.9, SK 5.1 / 10.5. With the paper's uniform goods elasticities (its
appendix II), which remove any ambiguity about how it aggregated elasticities,
the model gives 10.7, 6.7 and 5.5 against 7.3, 4.6 and 3.2 for elasticities of
4, 6.5 and 8: the same response to the elasticity, about 1.5 times the level.

**Diagnosis.**

* *Higher measured costs in current data.* The paper's interprovincial costs
  average 55.1% (Table 1); the same calculation on current Statistics Canada
  data gives 79.5%. In logs, the paper's costs are 60-90% of ours in every
  sector but metals (median 73%), including services, whose elasticity of 5 is
  known, so the gap lies in the data (the paper uses the 2007-2015 trade-flow
  tables, since revised, and older US data) rather than in the elasticities.
  The other two papers' costs, from 2010 and 2018 data, are reproduced. Higher
  measured costs leave larger non-geographic barriers for goods (31.5% vs
  about 19%) and hence larger gains.
* *The geographic coefficients* are similar to the paper's (its figure on p.
  11): distance raises costs by 8-16% per 1,000 km for most goods and services
  and by about 3% for mining, petroleum and chemicals, and telecommunications
  (the paper's lowest), and neighbours have 1-19% lower costs (paper: 4-30%).
  Utilities are the exception (a negative distance effect here, the paper's
  largest), but they have few trading pairs.
* *International barriers.* The paper reports non-geographic barriers of about
  3% with the United States and -13% with the rest of the world (its footnote
  24 says the geographic terms overstate international distance effects). Here
  they are 32% for goods traded with the United States and -22% with the rest
  of the world, so eliminating them is worth much more. The US block of the
  model comes from the OECD ICIO; the paper used Eora and USA Trade Online.
* *Within-province observations.* The paper's equation includes an
  intra-provincial indicator, which suggests that within-province pairs (log
  cost zero) were in the sample. Including them (`trade_costs$own_pairs`)
  lowers the distance coefficients and raises the gains further (9.2 internal,
  33.0 external), and leaves almost no geographic component, contrary to the
  paper's decomposition (geography 57% of barriers), so they are left out.
* *Yukon.* Without Yukon distances (see `docs/data.md`) Yukon's pairs get no
  geographic component and are not liberalized, so Yukon loses (-0.6%) instead
  of gaining 6.9%.

**Why the main model's goods result is so much smaller** (0.42% vs 3.8%). The
bridge below shows that switching from the paper's specification to that of
Albrecht and Tombe takes the result from 5.2% to 0.8%; every other difference
(no migration, observed imbalances, regional input-output tables, 37 sectors,
BoC elasticities, 2022 data) moves it from 0.8% to 0.4%. With log distance
normalized by internal distance, normalized distance rises from 1 within a
province to 4-30 between provinces, so the regression attributes most of the
jump in costs at the border to geography; in goods, measured costs are almost
entirely "geographic". With distance in levels, the same jump is attributed to
non-geographic barriers. For goods, the main model leaves 2.9% of measured
costs as non-geographic in 2022 (counting positive values only), the level
specification 31.5% in 2016. Interprovincial data alone cannot tell the two
apart; estimates that use within-province shipment distances (Bemrose, Brown
and Tweedle, 2017: a 6.9% tariff equivalent for goods) lie in between.

## Manucha and Tombe (2022)

**Recovering the elasticities.** The paper takes goods elasticities from
Fontagné, Guimbard and Orefice (2022) without listing them. Because the
Head-Ries index depends only on trade shares and the elasticity, the
elasticities can be recovered from the paper's measured costs (its Table 1) and
the same 2018 data. For six service sectors, whose elasticity the paper sets at
5, this inversion returns 4.87-5.18, which confirms that the data and the index
match the paper's. For goods it returns 8.9 (manufacturing), 15.8 (mining; the
Caliendo-Parro value is 15.7) and 6.9 (crop and animal production), which the
configuration uses.

**Trade costs.** By sector, measured costs match the paper (transport 82.6 vs
82.6, accommodation 116 vs 117, information 82 vs 80, professional services 91
vs 94, arts 112 vs 106); the non-distance component matches in manufacturing
(0.9 vs 0.4), agriculture (0.4 vs 0.0), transport (14 vs 13) and information (44
vs 38) but is larger in finance and real estate, professional services and
administrative services. The paper's 32 sectors cannot be built from the
ICIO-based sectors (wholesale and retail trade, finance and owner-occupied
housing, or government services by level are not separate); aggregation raises
measured costs (70% vs 60% on average) because sectors with very different
costs are merged (wholesale 67% and retail 202% become one sector at 105%).

**Results** (Canada, published / paper setup / main model): removing
non-distance costs 4.4 / 7.0 / 4.6; in services only 4.2 / 6.7 / 4.2; removing
asymmetries 7.9 / 5.0 / 4.4; in services only 4.6 / 4.2 / n.a. Alberta acting
alone (Canada): uniform 10% cut 1.4 / 0.7; non-distance costs 0.9 / 1.1;
asymmetries 1.6 / 0.8. For Alberta itself the paper setup gives larger gains
from unilateral non-distance liberalization (8.4 vs 2.5) and, unlike the paper,
a small loss when all provinces remove asymmetries (-0.2 vs +3.0): Alberta is a
low-cost exporter, so removing asymmetries lowers the costs of its competitors
and its import costs but not its export costs. The NWPTA bloc (British
Columbia, Alberta, Saskatchewan, Manitoba) gains 4.6% when it removes the
average of the two measures among its members (paper: 2.9%) and 11.0% when it
removes non-distance costs (paper's upper bound: 6.5%).

**Diagnosis.**

* *Non-distance costs* are overstated by the 17-sector setup through
  aggregation. With the 37 base sectors and the same elasticities, the average
  non-distance cost falls from 9.9% to 7.9% (paper: 8.0%) and the gain from
  removing it from 7.0% to 5.7% (paper: 4.4%; main model: 4.6%).
* *The uniform 10% cut.* The paper reports 6.7%. The model gives 3.1% in the
  paper's setup and 3.7% in the main model, and no setting in the bridge comes
  close to 6.7%. The paper's own rule of thumb (its Table 2: network centrality
  times interprovincial import share, summed over sectors) gives 0.31% of GDP
  per 1% cut, about 3.1% for a 10% cut, which is what the model produces. The
  paper's full-model figure must therefore come from features absent here, most
  likely the federal tax-transfer system of Tombe and Winter (2021) and its
  definition of real GDP, or from a different experiment; it cannot be
  diagnosed further without the paper's code.
* *Asymmetries* are smaller in the model (11% average contribution against the
  paper's 22%), so removing them yields less.
* *Labour mobility* adds little to national gains (0.1-0.4 points in the
  bridge) but more than doubles Alberta's own gains in the unilateral
  experiments (non-distance costs: 8.4% with mobility, 3.6% without; 10%
  cut: 5.1% and 2.2%), as people move to the liberalizing province.

## Bridges from the papers' setups to the main model

Canada-wide real income (%), one change at a time, cumulative.

**From Albrecht and Tombe:**

| Step | 10% internal | 10% imports | Measured internal 10% | Asymmetries | Non-distance | All measured |
|---|---:|---:|---:|---:|---:|---:|
| Paper setup (2016) | 3.15 | 2.73 | 0.82 | 5.11 | 6.37 | 57.6 |
| + observed trade imbalances | 3.03 | 2.74 | 0.79 | 4.74 | 6.41 | 56.6 |
| + province-specific input-output | 2.98 | 2.72 | 0.78 | 4.66 | 6.25 | 56.3 |
| + territories and the US | 3.00 | 2.70 | 0.79 | 4.91 | 5.56 | 57.3 |
| + 37 sectors (paper elasticities) | 2.95 | 2.69 | 0.75 | 5.19 | 5.65 | 56.5 |
| + BoC-rule elasticities | 3.30 | 3.18 | 0.65 | 4.64 | 4.12 | 43.6 |
| + adjacency, pooled panel, symmetric index | 3.30 | 3.18 | 0.69 | 4.52 | 5.11 | 42.0 |
| + 2022 data (main model) | 3.70 | 3.33 | 0.68 | 4.41 | 4.71 | 42.3 |

The elasticities are the main source of differences between the main model and
the paper; the other choices move results by less than 10%. The main model with
the paper's elasticities (`config/sensitivity_theta_papers.yml`) gives 3.05,
2.81, 0.80, 5.07, 6.23 and 54.2, close to the paper's 3.6, 2.9, 0.9, 3.3, 6.8
and 51.9.

**From Alvarez, Krznar and Tombe** (eliminating non-geographic barriers for
goods, internal):

| Step | Result |
|---|---:|
| Paper setup (2016) | 5.16 |
| Albrecht-Tombe gravity specification | 0.81 |
| + no labour mobility | 0.82 |
| + observed trade imbalances | 0.76 |
| + province-specific input-output | 0.77 |
| + 37 sectors (paper elasticities) | 0.59 |
| + BoC-rule elasticities | 0.46 |
| + 2022 data (main model) | 0.42 |

**From Manucha and Tombe:**

| Step | Uniform 10% | Non-distance | Asymmetries | Non-distance, services |
|---|---:|---:|---:|---:|
| Paper setup (2018) | 3.10 | 7.00 | 5.04 | 6.69 |
| No labour mobility | 3.04 | 6.65 | 4.85 | 6.43 |
| + US as a separate region | 3.04 | 6.65 | 4.85 | 6.43 |
| + 37 sectors, BoC-rule elasticities | 3.41 | 4.16 | 4.86 | 3.84 |
| + adjacency, pooled panel | 3.41 | 4.97 | 4.74 | 4.51 |
| + 2022 data (main model) | 3.68 | 4.64 | 4.43 | 4.18 |

## What changed in the model

* Exporter-specific (asymmetric) trade costs and the augmented Head-Ries index,
  and the experiment that removes asymmetries (A&T, MLI).
* The gravity specification of Alvarez et al. as an option, with international
  pairs, an interprovincial indicator by year and optional within-region pairs;
  `config/sensitivity_gravity_levels.yml` applies it to the main model.
* Gains-from-trade (autarky) experiments.
* Measured-cost experiments for any set of importers and exporters (external
  costs, unilateral liberalization, blocs) and partial eliminations.
* A floor on the geographic component: where geography predicts costs below
  within-province costs, eliminating non-geographic barriers cut more than
  eliminating all measured costs (64 pairs, 1.2% of interprovincial trade in
  2022).
* The main model's internal-trade scenarios now follow the papers' definitions
  (all sectors, as in A&T; goods, as in AKT; services, as in MLI) and include
  asymmetries and an import-cost variant of the external experiment.

## Remaining differences

| Difference | Cause | What would resolve it |
|---|---|---|
| AKT non-geographic gains 1.4-2.3 times the paper's | measured costs in current data higher than the paper's; US block from the ICIO | the paper's 2015 data vintage and US data |
| MLI uniform 10% cut: 6.7 vs 3.1-3.7 | model features absent here (fiscal transfers) or experiment definition | the paper's code |
| MLI and A&T asymmetries | larger (A&T) or smaller (MLI) exporter-specific costs in our data | finer sectors (MLI); the 2010 data (A&T) |
| A&T and AKT data years | ICIO tables for 2010 and 2015 not in the repository | add them to `data/raw/icio/` |
| Yukon in AKT experiments | no Yukon distances | the 2021 census file (`docs/data.md`) |

## References

* Bemrose, R. K., W. M. Brown and J. Tweedle (2017). "Going the distance:
  Estimating the effect of provincial borders on trade when geography matters."
  Statistics Canada, Analytical Studies Branch Research Paper 394.
* Fontagné, L., H. Guimbard and G. Orefice (2022). "Tariff-based product-level
  trade elasticities." *Journal of International Economics* 137: 103593.
* Tombe, T. and J. Winter (2021). "Fiscal integration with internal trade:
  Quantifying the effects of federal transfers in Canada." *Canadian Journal of
  Economics* 54(2): 522-556.
* Waugh, M. E. (2010). "International trade and income differences." *American
  Economic Review* 100(5): 2093-2124.
