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
Rscript scripts/replication/run_replications.R               # all papers, about 40 minutes
Rscript scripts/replication/run_replications.R --group akt   # one paper: at, akt or mli
```

All figures are percent changes in real income (real GDP) for Canada unless
noted. The main model is calibrated to 2022 with labour mobility (migration
elasticity 1.5).

## Summary

| Experiment | Published | Paper setup | Main model (2022) | Assessment |
|---|---:|---:|---:|---|
| **A&T** gains from trade: all / internal / external | 18.3 / 4.4 / 9.3 | 16.3 / 4.5 / 8.4 | n.a. | Reproduced; external gains 10% lower |
| A&T 10% lower interprovincial costs | 3.6 | 3.44 | 4.01 | Reproduced |
| A&T 10% lower external costs | 2.9 | 2.63 | 3.08 | Reproduced as a cut in import costs only (both directions: 6.15 and 9.04) |
| A&T 10% lower measured internal / external costs | 0.9 / 1.8 | 0.84 / 1.66 | 0.71 / n.a. | Reproduced |
| A&T eliminate non-distance costs | 6.8 | 6.97 | 4.90 | Reproduced; lower in the main model (distance measure, elasticities) |
| A&T eliminate all measured internal costs | 51.9 | 53.1 | 46.2 | Reproduced |
| A&T eliminate asymmetries | 3.3 | 4.77 | 4.83 | Larger: larger asymmetries in our data |
| A&T 10% higher costs on Quebec's trade: Quebec / Ontario | -4.8 / -0.5 | -4.5 / -0.5 | n.a. | Reproduced when the shock covers Quebec's international trade, as the paper's formula says |
| **AKT** gains from trade: internal / external / all | 5.1 / 10.9 / 19.6 | 4.5 / 10.1 / 18.9 | n.a. | Reproduced |
| AKT eliminate non-geographic barriers, goods, internal | 3.8 | 5.62 (4.30)† | 0.46 (5.08)* | 1.5 times larger; 1.1 times with the paper's measured costs |
| AKT same, external / internal and external | 6.2 / 9.1 | 20.1 / 21.7 | n.a. | 2.4-3.2 times larger (international costs) |
| AKT internal, uniform goods elasticity 4 / 6.5 / 8 | 7.3 / 4.6 / 3.2 | 12.7 / 7.8 / 6.4 | n.a. | Same pattern, 1.7-2 times larger |
| **MLI** uniform 10% lower interprovincial costs | 6.7 | 3.10 | 4.01 | Not reproduced; the paper's own rule of thumb gives 3.1 |
| MLI remove non-distance costs: all / services | 4.4 / 4.2 | 6.5 / 6.3 | 4.90 / 4.38 | Close in the main model; 1.5 times larger in the paper setup |
| MLI remove asymmetries: all / services | 7.9 / 4.6 | 5.1 / 4.2 | 4.83 / 2.72 | Lower: smaller asymmetries in our data |

\* With the main model's gravity specification (Albrecht and Tombe); 5.08 with
the specification of Alvarez et al. (`config/sensitivity_gravity_levels.yml`).
† With measured trade costs scaled to the paper's Table 1 (see below).

The main conclusions:

1. **The model reproduces Albrecht and Tombe on their 2010 data**, once their
   setup is followed in three respects that the earlier replication missed:
   the value-added and final-demand shares they report (their Table 9), their
   distance measure (the mean distance between residents, not between
   population centroids) and their treatment of trade imbalances (observed
   trade shares with balanced trade). The data match theirs: export shares by
   province and sector (their Table 1), measured trade costs (their Table 4:
   66.5% against 67.8% on average), distance elasticities (their Table 11) and
   non-distance costs (12.9% against 14.5%). Gains from external trade remain
   10% lower (input-output coefficients, which the paper does not report), and
   asymmetric costs are larger in our data. Their "10% lower external costs"
   figures (Table 5) correspond to a cut in import costs only, and their
   Quebec experiment raises the costs of all of Quebec's trade, including with
   the rest of the world.
2. **The gains from trade of Alvarez et al. are reproduced; their
   non-geographic barriers are not**, because their measured trade costs are
   lower than the same data give (55% against 79% on average). The gap is
   systematic across sectors, including services, whose elasticity is known,
   and it remains when the costs are computed directly from their source table
   with their product mapping; the measured costs of the other two papers,
   which use the same method, are reproduced from these data. With
   the costs scaled to their Table 1, the internal result (4.3% against 3.8%)
   and its provincial pattern are close; the external results remain 2.5 times
   larger. The main model's much smaller goods result (0.46%) is due to the
   gravity specification.
3. **Manucha and Tombe's non-distance experiments are reproduced by the main
   model** (4.9% against 4.4%; services 4.4% against 4.2%). Their goods
   elasticities are not published but can be recovered from their Table 1
   (manufacturing 8.9, mining 15.8, agriculture 6.9). Their 6.7% gain from a
   uniform 10% cut in interprovincial costs is not reproduced: the model gives
   3.1-4.0%, and the paper's own first-order approximation (its Table 2) gives
   3.1%.
4. **Which share of trade costs is "policy-relevant" is the main source of
   uncertainty**, not the solver or the data. In the same 2022 data, the two
   published decompositions leave non-geographic barriers of 2-10% on average
   (tariff equivalent; log distance relative to internal distance, the higher
   figure counting positive values only) or 42% (distance in levels), and the
   gains from removing them range from 4.9% to 25%. The distance measure also
   matters: with the papers' mean distance between residents, the main
   model's gain would be about 6.3% instead of 4.9%.

## Setups compared

| | A&T | AKT | MLI | Main model |
|---|---|---|---|---|
| Data year (paper / our setup) | 2010 / 2010 | 2015 / 2015 | 2018 / 2018 | 2022 |
| Regions | 10 provinces, ROW | 12 (NT and NU merged), US, ROW / 13, US, ROW | 13, ROW | 13, US, ROW |
| Sectors | 22 | 18 | 32 / 17 | 37 |
| Input-output | national (OECD STAN) / national, with Table 9 value-added and final-demand shares | national | not stated / regional | regional |
| Trade elasticities, goods | Caliendo-Parro (their Table 9) | Caliendo-Parro (not listed) / averaged as in A&T | Fontagné et al. (not listed) / recovered from Table 1 | BoC 2018 rule |
| Trade elasticity, services | 5 | 5 | 5 | 7 |
| Trade imbalances | balanced, observed trade shares | balanced, observed trade shares | federal transfers / observed | observed |
| Labour mobility | none | 1.5 | yes / 1.5 | 1.5 |
| Distance | mean distance between residents (cities, GRUMP) / same (2021 census) | between population centroids (GRUMP) / same (2021 census) | mean distance between residents / between centroids | between centroids |
| Gravity regressors | log normalized distance | distance (1000 km), neighbour, interprovincial x year | log normalized distance | log normalized distance, adjacency |
| Gravity sample | provinces, one year | provinces, US, ROW, 1997-2015 / 2010-2015 | provinces, one year | provinces, 2010-2022 |
| Asymmetric costs | yes (Waugh) | no | yes | yes (reported) |
| Canada aggregate | real GDP shares | nominal GDP shares | not stated / income shares | income shares |

Data year. The setups use the papers' years. The Statistics Canada
detail-level trade flows begin in 2010, so the Alvarez et al. regressions use
2010-2015 instead of 1997-2015. With later data, the Albrecht and Tombe setup
gives nearly the same internal results on 2010, 2016 and 2022 data (gains from
internal trade 4.5, 4.2 and 4.3; 10% lower internal costs 3.44, 3.21 and 3.23;
eliminating non-distance costs 6.97, 7.17 and 6.97) but larger gains from
external trade (8.4, 10.4 and 10.3), as import shares and input-output linkages
changed.

## Albrecht and Tombe (2016)

**Data and trade costs.** The 2010 data reproduce the paper's Table 1: Canada's
provinces export 15.4% of their output abroad and 11.0% to other provinces
(paper: 15% and 11%), and the sector pattern is the same (equipment and
vehicles 65% and 12% against 66% and 11%; paper 47% and 18% against 45% and
19%). Measured costs (Table 4) average 66.5% against 67.8%, with nearly
identical values by exporter (Quebec 62.7 vs 62.5, New Brunswick 66.5 vs 66.4,
Ontario 72.5 vs 73.5) and by sector (chemicals and rubber 12.5 vs 12.5,
wholesale and retail 102 vs 102, health 246 vs 246, education 227 vs 230). The
distance elasticities match their Table 11 (e.g. agriculture and mining 0.17
vs 0.17, hotels and restaurants 0.22 vs 0.22, real estate 0.34 vs 0.34,
wholesale and retail 0.30 vs 0.29, health 0.41 vs 0.37). With the paper's
distance measure, non-distance costs average 12.9% against 14.5%
(by exporter: Quebec 17.7 vs 17.4, Nova Scotia 29.8 vs 31.5, Ontario 14.0 vs
17.1; by sector: wholesale and retail 14.5 vs 14.8, finance 36.1 vs 36.2,
education 102 vs 105, health 74 vs 83). Asymmetric (exporter-specific) costs
average 10.1% against 7.8%, with the largest differences for exports from
Manitoba, Prince Edward Island, Quebec and Newfoundland and Labrador.

**Results by province** (published / paper setup):

| | Gains from internal trade | 10% lower internal costs | 10% lower import costs | Eliminate non-distance costs | Eliminate asymmetries |
|---|---|---|---|---|---|
| AB | 4.7 / 4.6 | 3.6 / 3.4 | 2.5 / 2.2 | 5.5 / 5.8 | 2.4 / 2.2 |
| BC | 4.7 / 4.8 | 3.9 / 3.8 | 2.9 / 2.6 | 4.9 / 6.0 | 2.8 / 2.8 |
| MB | 8.1 / 8.1 | 6.0 / 5.8 | 2.5 / 2.3 | 8.4 / 11.8 | 5.2 / 9.4 |
| NB | 8.1 / 8.1 | 6.5 / 6.3 | 4.7 / 4.3 | 28.3 / 27.9 | 8.0 / 8.1 |
| NL | 7.7 / 7.8 | 6.6 / 6.1 | 3.0 / 3.2 | 23.5 / 23.1 | 5.0 / 7.5 |
| NS | 7.5 / 7.8 | 6.1 / 6.0 | 3.0 / 2.9 | 24.3 / 25.2 | 7.9 / 9.2 |
| ON | 3.2 / 3.2 | 2.6 / 2.6 | 3.1 / 2.8 | 3.2 / 3.0 | 2.8 / 4.5 |
| PE | 11.4 / 11.1 | 7.2 / 6.8 | 2.1 / 1.9 | 35.1 / 47.1 | 18.6 / 22.5 |
| QC | 4.2 / 4.2 | 3.5 / 3.4 | 2.9 / 2.6 | 7.1 / 7.9 | 2.5 / 4.4 |
| SK | 7.1 / 7.2 | 5.2 / 5.1 | 3.0 / 2.6 | 17.2 / 17.3 | 8.7 / 14.8 |
| Canada | 4.4 / 4.5 | 3.6 / 3.4 | 2.9 / 2.6 | 6.8 / 7.0 | 3.3 / 4.8 |

Other experiments (published / paper setup): gains from all trade 18.3 / 16.3;
from external trade 9.3 / 8.4; 10% lower measured internal costs 0.9 / 0.84 and
external costs 1.8 / 1.66; eliminating all measured internal costs 51.9 / 53.1;
halving measured internal costs 7.6 / 7.4; 10% higher costs on Quebec's trade
with all other regions, which is the paper's experiment ($\hat\tau = 1.1$ "if
$n$ or $i$ is Quebec"): Quebec -4.8 / -4.5, Ontario -0.5 / -0.5, Alberta -0.2 /
-0.2. Raising only the costs of Quebec's trade with the other provinces gives
Quebec -1.7.

**Diagnosis.**

* *Input-output structure.* The paper takes Canada-wide input-output
  parameters from the OECD STAN tables; the setup uses the 2010 supply and use
  tables, whose input-output multipliers for goods are smaller (they sum to
  0.55 across goods sectors, against 0.71 in the paper's Table 9). Gains from
  external trade, which come mostly from goods, are therefore smaller: 7.4%
  with our parameters. With the paper's value-added and final-demand shares,
  which Table 9 reports, they rise to 8.4% (gains from all trade from 14.6% to
  16.3%, the import-cost cut from 2.42% to 2.63%), and the multipliers to 0.62.
  The remaining gap lies in the input coefficients, which the paper does not
  report.
* *Distance measure.* The paper normalizes the population-weighted mean
  distance between the residents of two provinces by the same measure within
  each province (appendix B). Distances between population centroids, used
  before, give internal distances 1.3-1.5 times smaller, so normalized
  distances are about a quarter larger. The fixed effects absorb most of this
  rescaling, so the distance elasticities barely change, but more of measured
  costs is attributed to geography: non-distance costs average 8.0% instead of
  12.9% (paper: 14.5%), and eliminating them gives 5.8% instead of 7.5% with
  our input-output shares (bridge below; 7.0% with the paper's).
* *Trade imbalances.* The paper keeps the observed trade shares and imposes
  balanced trade on the income levels (proposition 1; "initial equilibrium
  trade shares are as described in section 2.2"). Solving the model with zero
  deficits instead (`purge`) lowers Canadian import shares by up to 4 points
  in 2010 and gains from external trade from 7.4% to 7.2%.
* *External costs.* Lowering the costs of trade between Canada and the rest of
  the world by 10% in both directions gives 6.15%, more than twice the paper's
  2.9%. Lowering only the costs of Canadian imports gives 2.63% and the paper's
  provincial pattern (above). The paper's Table 5 figures therefore correspond
  to a cut in import costs (or to a rest of the world that does not respond to
  cheaper Canadian goods), although the text suggests both directions. Its
  Table 6 experiment on measured external costs, by contrast, is close to the
  two-way cut (1.66 vs 1.8). The scenario files keep both versions
  (`iceberg_external_10`, `iceberg_external_10_two_way`).
* *Asymmetries.* The gains from removing asymmetries (4.8% vs 3.3%) follow from
  the larger exporter-specific costs in our data. The estimation follows the
  paper (appendix B) and recovers known costs in synthetic data.
* *Gains from all trade* are lower for Newfoundland and Labrador (27.8 vs
  49.4) and New Brunswick (27.8 vs 41.7); the national figure is closer (16.3
  vs 18.3).

## Alvarez, Krznar and Tombe (2019)

The paper's trade-cost decomposition is implemented as an option: distance in
thousands of km and a neighbour indicator form the geographic component; an
interprovincial-trade indicator by year and the exporter-year and
importer-year fixed effects are non-geographic; the regressions pool
interprovincial and international pairs.

**Gains from trade** are reproduced (published / paper setup): internal 5.1 /
4.5, external 10.9 / 10.1, all 19.6 / 18.9, with the same provincial pattern
(e.g. internal: Alberta 5.1 / 5.1, Manitoba 8.3 / 7.8, Prince Edward Island
12.6 / 11.5, Ontario 4.4 / 3.4). Exceptions are Nova Scotia's external gains
(23.7 / 10.3) and the northern territories' total gains (28.8 / 64.5 for NT
and NU).

**Eliminating non-geographic barriers for goods** gives larger gains than the
paper: internal 5.6 vs 3.8, external 20.1 vs 6.2, both 21.7 vs 9.1. By
province (internal, published / paper setup): AB 3.2 / 5.2, BC 2.8 / 5.1, MB
7.1 / 11.6, NB 6.0 / 13.1, NL 12.8 / 18.0, NS 4.8 / 12.1, ON 2.9 / 4.3, PE
16.2 / 25.1, QC 4.6 / 6.8, SK 5.1 / 11.0, YT 6.9 / 19.5. With the paper's
uniform goods elasticities (its appendix II) the model gives 12.7, 7.8 and 6.4
against 7.3, 4.6 and 3.2 for elasticities of 4, 6.5 and 8.

**Diagnosis.**

* *Measured costs.* The paper's interprovincial costs average 55.1% in 2015
  (its Table 1); the same calculation on current Statistics Canada data gives
  78.8%. This is not a processing difference on our side: computing the index
  directly from the paper's source table (12-10-0088-01, summary level) with
  its product mapping (appendix I) and elasticities gives 79.0%. In logs the
  paper's costs are 67-78% of ours in every service sector and 73-91% in goods
  sectors but metals. For services, whose elasticity of 5 is stated, matching
  them would require elasticities of 6.5-9. Yet the measured costs of the other
  two papers, which use the same method, are reproduced from these data, and
  they are consistent with ours rather than with the IMF paper's: transport costs are 84% in Albrecht and Tombe (2010) and 83% in
  Manucha and Tombe (2018) but 58% in Alvarez et al. (2015, 80% here);
  wholesale and retail trade 102% in 2010 but 68% in 2015 (102% here). The
  difference therefore lies in the IMF paper's data (an earlier vintage of the
  tables) or their processing, which we cannot reproduce. Higher measured costs
  leave larger non-geographic barriers (goods: 32% against the paper's 19%)
  and hence larger gains.
* *With the paper's measured costs.* Measuring costs with elasticities that
  reproduce the paper's Table 1 by sector
  (`config/parameters/theta_measurement_alvarez_krznar_tombe_2019.csv`, run
  `akt_paper_costs`; the model keeps the paper's elasticities) lowers average
  costs to 53.6% and the internal goods result to 4.3% (paper 3.8%), with the
  paper's provincial pattern (correlation 0.89; NL 13.1 vs 12.8, PE 17.7 vs
  16.2, ON 3.4 vs 2.9, QC 5.1 vs 4.6, NT and NU 7.7 vs 7.5). The rest of the gap
  comes from the geographic share of costs, 22% here against 37% in the paper.
* *The geographic coefficients* are similar to the paper's (its p. 11): an
  extra 1,000 km raises costs by 6-22% for most goods and services and by
  0-3% for mining, petroleum and chemicals, and telecommunications (the
  paper's lowest), and neighbours have up to 16% lower costs (paper: 4-30%).
  Utilities are the exception (no distance effect here, the paper's largest),
  but they have few trading pairs.
* *International barriers.* For goods traded with the United States, geography
  predicts costs of 122% against measured costs of 50%, so the average
  non-geographic component is negative, as the paper reports (its footnote 24,
  which says the geographic terms overstate international distance effects).
  The experiment cuts only positive barriers, which average 7.7% for the
  United States and 6.7% for the rest of the world and apply to large trade
  flows; external gains are 20.1% (15.6% with the paper's measured costs)
  against 6.2%. The US block of the model comes from the OECD ICIO; the paper
  used Eora and USA Trade Online, so this part cannot be reconciled.
* *Within-province observations.* The paper's equation includes an
  intra-provincial indicator, which suggests that within-province pairs (log
  cost zero) were in the sample. Including them (`trade_costs$own_pairs`)
  lowers the distance coefficients and raises the gains further (8.5 internal,
  32.7 external), and leaves almost no geographic component, contrary to the
  paper's decomposition (geography 57% of barriers), so they are left out.
* *Yukon,* now with census distances, gains 19.5% (paper 6.9%) instead of
  losing 0.6% when its pairs had no geographic component.

**Why the main model's goods result is so much smaller** (0.46% vs 3.8%). The
bridge below shows that switching from the paper's specification to that of
Albrecht and Tombe takes the result from 5.6% to 0.8%; every other difference
(observed imbalances, regional input-output tables, 37 sectors, BoC
elasticities, 2022 data) moves it from 0.8% to 0.46%. With log distance
normalized by internal distance, normalized distance rises from 1 within a
province to 4-30 between provinces, so the regression attributes most of the
jump in costs at the border to geography; in goods, measured costs are almost
entirely "geographic". With distance in levels, the same jump is attributed to
non-geographic barriers. For goods, the main model leaves 3.1% of measured
costs as non-geographic (counting positive values only), the level
specification 35.8%. Interprovincial data alone cannot tell the two apart;
estimates that use within-province shipment distances (Bemrose, Brown and
Tweedle, 2017: a 6.9% tariff equivalent for goods) lie in between.

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
vs 94, arts 112 vs 106). The paper's 32 sectors cannot be built from the
ICIO-based sectors (wholesale and retail trade, finance and owner-occupied
housing, or government and private education and health are not separate);
aggregation raises measured costs (70% vs 60% on average) because sectors with
very different costs are merged (wholesale 67% and retail 202% become one
sector). On the paper's definitions, non-distance costs average 7.7% (paper:
8.0%) and asymmetric costs 11.3% (paper: 22.0%). By sector, non-distance costs
are higher than the paper's in the merged service sectors (education 101 and
health 92, against 44 and 45 for the paper's private services and 94-127 for
government ones).

**Results** (Canada, published / paper setup / main model): removing
non-distance costs 4.4 / 6.5 / 4.9; in services only 4.2 / 6.3 / 4.4; removing
asymmetries 7.9 / 5.1 / 4.8; in services only 4.6 / 4.2 / 2.7. Alberta acting
alone (Canada): uniform 10% cut 1.4 / 0.68; non-distance costs 0.9 / 0.96;
asymmetries 1.6 / 0.78. For Alberta itself the setup reproduces the gain from
a unilateral 10% cut (5.1 vs 5.2) but gives larger gains from unilateral
non-distance liberalization (7.7 vs 2.5) and, unlike the paper, a small loss
when all provinces remove asymmetries (-0.3 vs +3.0): Alberta is a low-cost
exporter, so removing asymmetries lowers the costs of its competitors and its
import costs but not its export costs. The NWPTA bloc (British Columbia,
Alberta, Saskatchewan, Manitoba) gains 4.5% when it removes the average of the
two measures among its members (paper: 2.9%) and 10.1% when it removes
non-distance costs (paper's upper bound: 6.5%).

**Diagnosis.**

* *Non-distance costs* are larger in the 17-sector setup than in the paper's
  32 sectors because of aggregation. With the 37 base sectors and the same
  elasticities the gain from removing them falls from 6.5% to 5.4% (paper:
  4.4%; main model: 4.9%). The paper describes its distance as the mean
  distance between residents, like Albrecht and Tombe; with that measure
  (computed from the census extract, which lacks Yukon) the average
  non-distance cost rises to 14.9% and the gain to 8.9%, further from the
  paper, so the setup keeps distances between centroids. The merged service
  sectors prevent a sharper comparison.
* *The uniform 10% cut.* The paper reports 6.7%. The model gives 3.1% in the
  paper's setup and 4.0% in the main model, and no setting in the bridge comes
  close to 6.7%. The paper's own rule of thumb (its Table 2: network centrality
  times interprovincial import share, summed over sectors) gives 0.31% of GDP
  per 1% cut, about 3.1% for a 10% cut, which is what the model produces. The
  paper's full-model figure must therefore come from features absent here, most
  likely the federal tax-transfer system of Tombe and Winter (2021) and its
  definition of real GDP, or from a different experiment; it cannot be
  diagnosed further without the paper's code.
* *Asymmetries* are smaller in the model (11% average contribution against the
  paper's 22%), so removing them yields less.
* *Labour mobility* adds little to national gains (run `mli_no_migration`:
  3.04 instead of 3.10 for the uniform cut, 6.21 instead of 6.52 for
  non-distance costs) but more than doubles Alberta's own gains in the
  unilateral experiments (uniform cut 5.1% with mobility, 2.2% without;
  non-distance costs 7.7% and 3.3%; asymmetries 5.6% and 2.4%), as people move
  to the liberalizing province.

## Bridges from the papers' setups to the main model

Canada-wide real income (%), one change at a time, cumulative.

**From Albrecht and Tombe:**

| Step | 10% internal | 10% imports | Measured internal 10% | Asymmetries | Non-distance | All measured | Gains from external trade |
|---|---:|---:|---:|---:|---:|---:|---:|
| Paper setup (2010) | 3.44 | 2.63 | 0.84 | 4.77 | 6.97 | 53.1 | 8.42 |
| + value-added and final-demand shares from the 2010 supply-use tables | 3.31 | 2.42 | 0.84 | 4.77 | 7.51 | 54.2 | 7.39 |
| + distances between population centroids | 3.31 | 2.42 | 0.83 | 5.23 | 5.80 | 54.3 | 7.39 |
| + observed trade imbalances | 3.25 | 2.40 | 0.82 | 5.01 | 5.93 | 54.7 | n.a. |
| + province-specific input-output structure | 3.17 | 2.38 | 0.80 | 4.90 | 5.77 | 54.3 | n.a. |
| + territories and the United States | 3.20 | 2.35 | 0.81 | 5.76 | 4.53 | 55.4 | n.a. |
| + 37 sectors (paper elasticities) | 3.12 | 2.34 | 0.75 | 5.06 | 5.03 | 55.7 | n.a. |
| + Bank of Canada-rule elasticities | 3.53 | 2.88 | 0.63 | 4.26 | 4.05 | 46.0 | n.a. |
| + adjacency, symmetric index | 3.53 | 2.88 | 0.69 | 4.20 | 5.32 | 43.9 | n.a. |
| + labour mobility (elasticity 1.5) | 3.71 | 2.75 | 0.71 | 4.42 | 5.78 | 49.0 | n.a. |
| + 2022 data, 2010-2022 panel, income weights (main model) | 4.01 | 3.08 | 0.71 | 4.83 | 4.90 | 46.2 | n.a. |

The elasticities are the main source of differences between the main model and
the paper; the distance measure moves the non-distance experiment, the
input-output data the external ones, and the other choices move results by
less than 10%. The main model with the paper's elasticities
(`config/sensitivity_theta_papers.yml`) gives 3.23, 2.76, 0.84, 5.63, 6.68
and 61.0, against the paper's 3.6, 2.9, 0.9, 3.3, 6.8 and 51.9.

**From Alvarez, Krznar and Tombe** (eliminating non-geographic barriers for
goods, internal):

| Step | Result |
|---|---:|
| Paper setup (2015) | 5.62 |
| Albrecht-Tombe gravity specification | 0.84 |
| + observed trade imbalances | 0.91 |
| + province-specific input-output | 0.92 |
| + 37 sectors (paper elasticities) | 0.67 |
| + BoC-rule elasticities | 0.52 |
| + 2022 data (main model) | 0.46 |

**From Manucha and Tombe:**

| Step | Uniform 10% | Non-distance | Asymmetries | Non-distance, services |
|---|---:|---:|---:|---:|
| Paper setup (2018) | 3.10 | 6.52 | 5.12 | 6.25 |
| + US as a separate region | 3.11 | 6.53 | 5.13 | 6.26 |
| + 37 sectors, BoC-rule elasticities | 3.51 | 4.09 | 4.99 | 3.76 |
| + adjacency, pooled panel | 3.51 | 5.08 | 4.80 | 4.59 |
| + 2022 data (main model) | 4.01 | 4.90 | 4.83 | 4.38 |

## What changed in the model

* Exporter-specific (asymmetric) trade costs and the augmented Head-Ries index,
  and the experiment that removes asymmetries (A&T, MLI).
* The gravity specification of Alvarez et al. as an option, with international
  pairs, an interprovincial indicator by year and optional within-region pairs;
  `config/sensitivity_gravity_levels.yml` applies it to the main model.
* The papers' distance measure, the mean distance between residents
  (`distances$method: pairwise`).
* Balanced trade with the observed trade shares (`calibration$deficits:
  balanced`), as in A&T and AKT.
* Published value-added and final-demand shares (`io_parameters$sector_values`)
  and elasticities used only to measure trade costs
  (`trade_costs$measurement_elasticities`).
* Gains-from-trade (autarky) experiments.
* Measured-cost experiments for any set of importers and exporters (external
  costs, unilateral liberalization, blocs) and partial eliminations.
* A floor on the geographic component: where geography predicts costs below
  within-province costs, eliminating non-geographic barriers cut more than
  eliminating all measured costs (64 pairs, 1.2% of interprovincial trade in
  2022).
* The main model's internal-trade scenarios follow the papers' definitions
  (all sectors, as in A&T; goods, as in AKT; services, as in MLI) and include
  asymmetries and an import-cost variant of the external experiment.

## Remaining differences

| Difference | Cause | What would resolve it |
|---|---|---|
| A&T gains from external trade 10% lower | input-output coefficients (OECD STAN in the paper) | the paper's input-output table |
| A&T asymmetries larger, MLI asymmetries smaller | exporter-specific costs in our data | finer sectors (MLI) |
| AKT non-geographic gains 1.5 (internal) to 3 (external) times the paper's | the paper's measured costs are lower than the data give; US block from the ICIO | the paper's data |
| MLI uniform 10% cut: 6.7 vs 3.1-4.0 | model features absent here (fiscal transfers) or experiment definition | the paper's code |
| Main model distance measure | centroids, not the papers' mean distance between residents | the raw 2021 census file, which includes Yukon (`distances$method: pairwise`) |

## References

* Bemrose, R. K., W. M. Brown and J. Tweedle (2017). "Going the distance:
  Estimating the effect of provincial borders on trade when geography matters."
  Statistics Canada, Analytical Studies Branch Research Paper 394.
* Fontagné, L., H. Guimbard and G. Orefice (2022). "Tariff-based product-level
  trade elasticities." *Journal of International Economics* 137: 103593.
* Head, K. and T. Mayer (2002). "Illusory border effects: Distance
  mismeasurement inflates estimates of home bias in trade." CEPII Working
  Paper 2002-01.
* Tombe, T. and J. Winter (2021). "Fiscal integration with internal trade:
  Quantifying the effects of federal transfers in Canada." *Canadian Journal of
  Economics* 54(2): 522-556.
* Waugh, M. E. (2010). "International trade and income differences." *American
  Economic Review* 100(5): 2093-2124.
