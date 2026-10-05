# Data sources and construction

All values are in millions of current Canadian dollars at basic prices. The
calibration year is 2022 in the main configuration.

## Sources

| Source | Content | Years | Where | How obtained |
|---|---|---|---|---|
| Statistics Canada, table [12-10-0101-01](https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1210010101) | Interprovincial and international trade flows, basic prices, **detail level** (about 500 products), including each province's purchases from itself | 2010-2022 | `data/raw/statcan/` (cache) | downloaded by `scripts/01_download_data.R` |
| Statistics Canada, table [12-10-0100-01](https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1210010001) | Exports and imports by trading partner (United States, all countries) and industry, by province | 2007-2024 | cache | downloaded |
| Statistics Canada, catalogue [15-602-X](https://www150.statcan.gc.ca/n1/en/catalogue/15-602-X) | Provincial and territorial supply and use tables, detail level | 2010-2022 | cache | downloaded (CSV archive per year) |
| Statistics Canada, table [17-10-0005-01](https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1710000501) | Population on July 1 | 1971- | cache | downloaded |
| Statistics Canada, table [18-10-0003-01](https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1810000301) | Inter-city indexes of price differentials (all items) | 2000-2019 | cache | downloaded |
| OECD [Inter-Country Input-Output tables](https://oe.cd/icio), 2025 edition, extended version | Intermediate and final use by country and industry (USD millions) | 1995-2022 | `data/raw/icio/<year>.csv` | committed |
| Bank of Canada, series [FXUSDCAD](https://www.bankofcanada.ca/valet/observations/FXUSDCAD/csv) | Daily CAD per USD | May 2007 - May 2025 | `data/raw/fx/FXUSDCAD.csv` | committed |
| Statistics Canada, census Geographic Attribute File (92-151-X), 2021 | Dissemination-block population and dissemination-area representative points | 2021 | `data/raw/census/2021_92-151_X.csv`; `data/raw/census/2021_da_extract.csv` | raw file git-ignored (the distances built from it are committed); extract committed (Yukon missing; see below) |
| Charbonneau and Landry (2018), Table 1 | Sectoral trade elasticities | 1993 and 2016 estimates | `config/parameters/boc2018_trade_elasticities.csv` | transcribed |
| Albrecht and Tombe (2016, working paper of May 2015), Alvarez, Krznar and Tombe (2019), Manucha and Tombe (2022) | Published results, measured trade costs and gravity estimates used for the replication comparison | 2010, 2015, 2018 | `config/benchmarks/published_results.csv` | transcribed (see `docs/replication.md`) |

Statistics Canada downloads are cached in `data/raw/statcan/` (git-ignored),
together with compact extracts that later runs read instead of the full files.
Processed model inputs for the main configuration are committed in
`data/processed/default/`, so that `scripts/05_*` to `07_*` can be run without
any download.

## Sectors

The model uses 37 sectors that aggregate the 50 industries of the ICIO 2025
edition (ISIC Rev. 4); see `config/concordances/sectors.csv`. Statistics Canada
data are mapped to these sectors **by classification code**, not by name,
using longest-prefix rules:

* products (IOPC codes such as `MPG336111`, used by the trade-flow tables and
  the supply and use tables): `config/concordances/product_prefix_to_sector.csv`;
* industries (IOIC codes such as `BS336110`): `config/concordances/industry_prefix_to_sector.csv`;
* ICIO industries: `config/concordances/icio_industry_to_sector.csv`.

The rules follow ISIC Rev. 4 so that Canadian sectors match the ICIO sectors
used for the United States and the rest of the world. For example, passenger
cars and light trucks are motor vehicles (ISIC 29), newspapers and books are
publishing (ISIC 58), prepared meals are food services (ISIC 56), rental and
leasing is administrative services (ISIC 77), computer systems design is IT
services (ISIC 62) and waste management is grouped with utilities (ICIO sector
E). The test suite checks that every product and industry code that appears in
the 2010-2022 data maps to a sector. Taxes on products, primary inputs and the
fictive commodities of the 2010-2016 vintages (whose inputs are recorded under
the underlying products) are excluded; transportation margins are part of
transportation services.

Older supply and use tables (before the 2022 release) omit codes from member
names; codes are recovered from the member IDs in each row's `COORDINATE` and
the table's metadata file.

## Regions

13 provinces and territories (`NL` ... `NU`), the United States (`USA`) and the
rest of the world (`ROW`): all ICIO economies other than Canada and the United
States. In the extended ICIO the `CHN` and `MEX` rows and intermediate-use
columns are empty and China and Mexico appear as `CN1`/`CN2` and `MX1`/`MX2`;
all four belong to `ROW`. Flows to "Canadian territorial enclaves abroad" are
dropped (they are a few hundred million dollars).

## Bilateral trade flows

* **Between and within provinces/territories**: "To <province>" flows of table
  12-10-0101-01. The flow from a province to itself is its purchases from its
  own producers; "Total supply" in the table is the province's total use of the
  product and "Total demand" the total demand for its output.
* **Province - foreign**: "International exports" and "International imports".
  These are split between the United States and the rest of the world with US
  shares computed **within** table 12-10-0100-01 at the detailed industry level,
  by province, sector and year: exports use "Exports" plus "Exports from
  inventories" (whose sum equals "International exports" of 12-10-0101-01), and
  imports use "Imports". Where a province-sector has no trade in 12-10-0100-01
  the Canada-wide sector share is used, then the province's all-sector share.
  Re-exports are excluded, consistent with the trade-flow table.
* **Among foreign regions** (USA-USA, USA-ROW, ROW-USA, ROW-ROW): intermediate
  plus final use from the ICIO, converted to CAD at the annual-average Bank of
  Canada rate (2022: 1.3013).

The resulting matrix is complete for 2022 and the implied trade deficits sum to
zero.

## Production and demand parameters

* **Provinces and territories** (default `io_parameters$source: regional`):
  from the basic-price supply and use tables of the calibration year. Gross
  output is industry output from the supply table; value added is the use
  table's GVA row; intermediate inputs are the product rows of the use table by
  using industry; final demand is the sum of household, NPISH and government
  consumption, gross fixed capital formation (construction, machinery and
  equipment, intellectual property) and inventory changes. Net taxes on
  products paid on inputs are part of $(1-\phi)$ and allocated across inputs in
  proportion to $\gamma$. Sectors that do not exist in a province use the
  Canada-wide coefficients. Value-added shares outside (0.01, 1] would be
  clamped (none in 2022).
* **United States and rest of the world**: from the ICIO (value added and output
  by industry; intermediate inputs from all origins by using industry; final
  demand by source industry).
* `national` uses Canada-wide coefficients for every province (as in Albrecht
  and Tombe, 2016) and `global` the world average for all regions (the legacy
  behaviour).

As a check, the Canada-wide value-added shares from the supply and use tables
are within a few points of the ICIO's Canada block in every sector, and total
value added is CAD 2,675 billion (SUT) against 2,631 billion (ICIO).

## Distances

Provinces and territories are represented by dissemination-area
representative points weighted by dissemination-block population. Two
measures are available (`distances$method`):

* `centroid` (main model): distance between population-weighted centroids;
  internal distance is the population-weighted mean distance from the
  dissemination areas to the centroid (`data/processed/distances_2021.csv`,
  from the raw 2021 file).
* `pairwise`: population-weighted mean distance between the residents of two
  regions, and within a region (Head and Mayer, 2002), the measure of
  Albrecht and Tombe (2016) and Manucha and Tombe (2022). Points are
  aggregated to a 0.05-degree grid first. Internal distances are 1.3-1.5 times
  the centroid-based ones (Ontario 209 km against 137 km), so normalized
  distances are about a quarter smaller. `data/processed/distances_2021_pairwise.csv`
  is built from the committed extract, which lacks Yukon; it is used by the
  Albrecht and Tombe replication (ten provinces).

Normalized distance is $d_{ni}/\sqrt{d_{nn}d_{ii}}$. Great-circle distances
use the haversine formula with the WGS84 equatorial radius.

Adjacency (`config/concordances/adjacency.csv`) is symmetric: shared land
borders plus the Confederation Bridge (PE-NB). Ferry links (NS-NL, NS-PE) and
the single-point contacts at the Four Corners (MB-NT, SK-NU) are not adjacency.

The foreign regions (USA at the 2000 US mean centre of population, ROW at
Almaty) and their internal distances (disc formula with land areas) are only
used when the gravity sample includes international pairs.

## Known data limitations

* **Census file not committed.** The distances are built from the raw 2021
  Geographic Attribute File (`2021_92-151_X.csv`), which is too large to commit;
  the resulting `data/processed/distances_2021.csv` is committed, and step 2
  keeps it when the raw file is absent. The legacy extract
  (`data/raw/census/2021_da_extract.csv`) lacks Yukon, which is why Yukon had no
  distances before 5 October 2026, and why pairwise distances are only
  available for the other twelve regions until they are rebuilt from the raw
  file (`--set distances.method=pairwise --set paths.distances=...`).
* **2006 distances.** The raw 2006 file is not in the repository; the
  normalized distances produced by the legacy script are kept in
  `data/raw/legacy/2006_dist_mat_legacy.csv` for reference. They are within
  about 6% of correctly weighted 2021 values, so they do not appear to be
  affected by the factor-code bug that corrupted the legacy 2011 matrix
  (removed), but they could not be regenerated. All configurations, including
  the Albrecht and Tombe (2016) replication, use the 2021 census distances.
* **Inter-city price indexes** end in 2019 and do not cover Iqaluit; they are
  only used when Canada-wide results are weighted by real income
  (`aggregation$canada_weights: real_income`).
* **Industry-based US shares.** The US/ROW split applies industry-based shares
  (12-10-0100-01) to product-based totals (12-10-0101-01). Using shares rather
  than subtracting levels keeps flows non-negative and consistent with the
  trade-flow table, but a residual classification mismatch remains.
