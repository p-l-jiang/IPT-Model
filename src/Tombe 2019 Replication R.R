# 0. Setup 
## 0.1 Install/load required packages
library(purrr)
packages <- c(
  "dplyr", "tidyr", "janitor", "readr", "stringr", "fixest", "geosphere",
  "cansim", "Matrix", "data.table", "arrow", "qs", "parallelly", "here",
  "tidyverse", "stringdist", "tibble", "scales", "tidyverse", "knitr")

install_if_missing <- function(pkg) if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
walk(packages, install_if_missing)
walk(packages, library, character.only = TRUE)

setwd("C:/Users/JiangPe/Documents/R/Tombe Replication")

options(scipen = 999)

# save.image(file = "2019-replication-07-23.RData")
# load(file = "2019-replication-07-23.RData")

## 0.2 Definitions
provs <- c("AB","BC","MB","NB","NL","NS","ON","PE","QC","SK")
provsplus <- c("AB","BC","MB","NB","NL","NS","ON","PE","QC","SK","YT","NT","NU")
provinces <- c("Newfoundland and Labrador", "Prince Edward Island", "Nova Scotia", "New Brunswick", "Quebec", 
               "Ontario", "Manitoba", "Saskatchewan", "Alberta", "British Columbia")
provincesplus <- c("Newfoundland and Labrador", "Prince Edward Island", "Nova Scotia", "New Brunswick", "Quebec", 
                   "Ontario", "Manitoba", "Saskatchewan", "Alberta", "British Columbia", 
                   "Yukon", "Northwest Territories", "Nunavut")

supc_to_sector <- tribble(
  ~supc_sector,                                                   ~sector,
  "Grains and other crop products"                                , "Agriculture, hunting, forestry, fishing and aquaculture",
  "Live animals"                                                  , "Agriculture, hunting, forestry, fishing and aquaculture",
  "Other farm products"                                           , "Agriculture, hunting, forestry, fishing and aquaculture",
  "Forestry products and services"                                , "Agriculture, hunting, forestry, fishing and aquaculture",
  "Fish, crustaceans, shellfish and other fishery products"       , "Agriculture, hunting, forestry, fishing and aquaculture",
  "Support services related to farming and forestry"              , "Agriculture, hunting, forestry, fishing and aquaculture",
  "Mineral fuels"                                                 , "Mining and quarrying, energy producing products",
  "Metal ores and concentrates"                                   , "Mining and quarrying, non-energy producing products",
  "Non-metallic minerals"                                         , "Mining and quarrying, non-energy producing products",
  "Mining and oil and gas support services"                       , "Mining support service activities",
  "Oil and gas and mineral exploration"                           , "Mining support service activities",
  "Utilities"                                                     , "Utilities",
  "Residential buildings"                                         , "Construction",
  "Non-residential buildings (except mine buildings)"            , "Construction",
  "Engineering works"                                             , "Construction",
  "Repair construction services"                                  , "Construction",
  "Food and non-alcoholic beverages"                              , "Food products, beverages and tobacco",
  "Alcoholic beverages and tobacco products"                      , "Food products, beverages and tobacco",
  "Textile products, clothing, and products of leather and similar materials" , "Textiles, textile products, leather and footwear",
  "Wood products"                                                 , "Wood and products of wood and cork",
  "Wood pulp, paper and paper products and paper stock"           , "Paper products and printing",
  "Printed products and services"                                 , "Paper products and printing",
  "Chemical products"                                             , "Chemical and pharmaceutical products",
  "Plastic and rubber products"                                   , "Rubber and plastics products",
  "Non-metallic mineral products"                                 , "Other non-metallic mineral products",
  "Fabricated metallic products"                                  , "Fabricated metal products",
  "Computers and electronic products"                             , "Computer, electronic and optical equipment",
  "Transportation equipment"                                      , "Other transport equipment",
  "Furniture and related products"                                , "Manufacturing nec; repair and installation of machinery and equipment",
  "Other manufactured products and custom work"                  , "Manufacturing nec; repair and installation of machinery and equipment",
  "Wholesale margins and commissions"                             , "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins, sales of used goods and commissions"          , "Wholesale and retail trade; repair of motor vehicles",
  "Transportation and related services"                           , "Transportation and related services",
  "Information and cultural services"                             , "Publishing, audiovisual and broadcasting activities",
  "Published products and recorded media (except software)"       , "Publishing, audiovisual and broadcasting activities",
  "Telecommunications, broadcasting distribution and related services" , "Telecommunications",
  "Depository credit intermediation"                              , "Financial and insurance activities",
  "Other finance and insurance"                                   , "Financial and insurance activities",
  "Real estate, rental and leasing and rights to non-financial intangible assets" , "Real estate activities",
  "Imputed rental of owner-occupied dwellings"                    , "Real estate activities",
  "Professional services (except software and research and development)" , "Professional, scientific and technical activities",
  "Software"                                                      , "IT and other information services",
  "Research and development"                                      , "Professional, scientific and technical activities",
  "Administrative and support, head office, waste management and remediation services" , "Administrative and support services",
  "Education services"                                            , "Education",
  "Health and social assistance services"                         , "Human health and social work activities",
  "Arts, entertainment and recreation services"                   , "Arts, entertainment and recreation",
  "Accommodation and food services"                               , "Accommodation and food service activities",
  "Other services"                                                , "Other service activities",
  "Sales of other services by Non-Profit Institutions Serving Households" , "Public administration and defence; compulsory social security",
  "Sales of other government services"                            , "Public administration and defence; compulsory social security",
  "Transportation margins"                                        , "Transportation and related services",
  "Services provided by Non-Profit Institutions Serving Households"     , "Public administration and defence; compulsory social security",
  "Education services provided by government sector"              , "Education",
  "Health services provided by government sector"                 , "Human health and social work activities",
  "Other federal government services"                             , "Public administration and defence; compulsory social security",
  "Other provincial and territorial government services"          , "Public administration and defence; compulsory social security",
  "Other municipal government services"                           , "Public administration and defence; compulsory social security",
  "Other aboriginal government services"                          , "Public administration and defence; compulsory social security",
  "Primary metallic products"                                     , "Basic metals",
  "Electrical equipment, appliances and components"              , "Electrical equipment",
  "Industrial machinery"                                          , "Machinery and equipment, nec",
  "Refined petroleum products (except petrochemicals)"            , "Coke and refined petroleum products",
  "Motor vehicle parts"                                           , "Motor vehicles, trailers and semi-trailers"
)

supc_to_sector2 <- tribble(
  ~supc_sector2, ~sector,
  "Crop and animal production ==> Total industries", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Forestry and logging ==> Total industries", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Fishing, hunting and trapping ==> Total industries", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Utilities", "Utilities",
  "Other activities of the construction industry ==> Total industries", "Construction",
  "Wholesale trade ==> Total industries", "Wholesale and retail trade; repair of motor vehicles",
  "Retail trade ==> Total industries", "Wholesale and retail trade; repair of motor vehicles",
  "Transportation and warehousing", "Transportation and related services",
  "Information and cultural industries", "Publishing, audiovisual and broadcasting activities",
  "Professional, scientific and technical services", "Professional, scientific and technical activities",
  "Administrative and support, waste management and remediation services", "Administrative and support services",
  "Educational services ==> Total industries", "Education",
  "Health care and social assistance ==> Total industries", "Human health and social work activities",
  "Arts, entertainment and recreation ==> Total industries", "Arts, entertainment and recreation",
  "Accommodation and food services ==> Total industries", "Accommodation and food service activities",
  "Other services (except public administration)", "Other service activities",
  "Non-profit institutions serving households", "Public administration and defence; compulsory social security",
  "Government education services", "Education",
  "Government health services", "Human health and social work activities",
  "Other federal government services ==> Total industries", "Public administration and defence; compulsory social security",
  "Other provincial and territorial government services ==> Total industries", "Public administration and defence; compulsory social security",
  "Other municipal government services ==> Total industries", "Public administration and defence; compulsory social security",
  "Support activities for agriculture and forestry ==> Total industries", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Other aboriginal government services ==> Total industries", "Public administration and defence; compulsory social security",
  "Iron ore mining", "Mining and quarrying, non-energy producing products",
  "Gold and silver ore mining", "Mining and quarrying, non-energy producing products",
  "Copper, nickel, lead and zinc ore mining", "Mining and quarrying, non-energy producing products",
  "Stone mining and quarrying", "Mining and quarrying, non-energy producing products",
  "Sand, gravel, clay, and ceramic and refractory minerals mining and quarrying", "Mining and quarrying, non-energy producing products",
  "Other non-metallic mineral mining and quarrying (except diamond and potash)", "Mining and quarrying, non-energy producing products",
  "Support activities for oil and gas extraction", "Mining support service activities",
  "Support activities for mining", "Mining support service activities",
  "Animal food manufacturing ==> Animal food manufacturing", "Food products, beverages and tobacco",
  "Sugar and confectionery product manufacturing ==> Sugar and confectionery product manufacturing", "Food products, beverages and tobacco",
  "Fruit and vegetable preserving and specialty food manufacturing ==> Fruit and vegetable preserving and specialty food manufacturing", "Food products, beverages and tobacco",
  "Dairy product manufacturing ==> Dairy product manufacturing", "Food products, beverages and tobacco",
  "Meat product manufacturing ==> Meat product manufacturing", "Food products, beverages and tobacco",
  "Seafood product preparation and packaging ==> Seafood product preparation and packaging", "Food products, beverages and tobacco",
  "Bakeries and tortilla manufacturing", "Food products, beverages and tobacco",
  "Other food manufacturing", "Food products, beverages and tobacco",
  "Soft drink and ice manufacturing ==> Soft drink and ice manufacturing", "Food products, beverages and tobacco",
  "Breweries ==> Breweries", "Food products, beverages and tobacco",
  "Wineries and distilleries ==> Wineries and distilleries", "Food products, beverages and tobacco",
  "Textile and textile product mills ==> Textile and textile product mills", "Textiles, textile products, leather and footwear",
  "Clothing and leather and allied product manufacturing ==> Clothing and leather and allied product manufacturing", "Textiles, textile products, leather and footwear",
  "Sawmills and wood preservation", "Wood and products of wood and cork",
  "Veneer, plywood and engineered wood product manufacturing", "Wood and products of wood and cork",
  "Other wood product manufacturing", "Wood and products of wood and cork",
  "Pulp, paper and paperboard mills ==> Pulp, paper and paperboard mills", "Paper products and printing",
  "Converted paper product manufacturing ==> Converted paper product manufacturing", "Paper products and printing",
  "Printing and related support activities ==> Printing and related support activities", "Paper products and printing",
  "Petroleum refineries", "Coke and refined petroleum products",
  "Petroleum and coal product manufacturing (except petroleum refineries)", "Coke and refined petroleum products",
  "Basic chemical manufacturing ==> Basic chemical manufacturing", "Chemical and pharmaceutical products",
  "Soap, cleaning compound and toilet preparation manufacturing", "Chemical and pharmaceutical products",
  "Pharmaceutical and medicine manufacturing ==> Pharmaceutical and medicine manufacturing", "Chemical and pharmaceutical products",
  "Plastic product manufacturing ==> Plastic product manufacturing", "Rubber and plastics products",
  "Rubber product manufacturing ==> Rubber product manufacturing", "Rubber and plastics products",
  "Non-metallic mineral product manufacturing (except cement and concrete products) ==> Non-metallic mineral product manufacturing (except cement and concrete products)", "Other non-metallic mineral products",
  "Cement and concrete product manufacturing ==> Cement and concrete product manufacturing", "Other non-metallic mineral products",
  "Steel product manufacturing from purchased steel", "Basic metals",
  "Non-ferrous metal (except aluminum) production and processing", "Basic metals",
  "Foundries", "Basic metals",
  "Forging and stamping", "Fabricated metal products",
  "Cutlery, hand tools and other fabricated metal product manufacturing", "Fabricated metal products",
  "Architectural and structural metals manufacturing", "Fabricated metal products",
  "Boiler, tank and shipping container manufacturing", "Fabricated metal products",
  "Machine shops, turned product, and screw, nut and bolt manufacturing", "Fabricated metal products",
  "Coating, engraving, cold and heat treating and allied activities", "Fabricated metal products",
  "Agricultural, construction and mining machinery manufacturing", "Machinery and equipment, nec",
  "Industrial machinery manufacturing", "Machinery and equipment, nec",
  "Ventilation, heating, air-conditioning and commercial refrigeration equipment manufacturing", "Machinery and equipment, nec",
  "Metalworking machinery manufacturing", "Machinery and equipment, nec",
  "Other general-purpose machinery manufacturing", "Machinery and equipment, nec",
  "Communications equipment manufacturing", "Computer, electronic and optical equipment",
  "Other electronic product manufacturing", "Computer, electronic and optical equipment",
  "Semiconductor and other electronic component manufacturing", "Computer, electronic and optical equipment",
  "Electric lighting equipment manufacturing", "Electrical equipment",
  "Other electrical equipment and component manufacturing", "Electrical equipment",
  "Motor vehicle gasoline engine and engine parts manufacturing", "Motor vehicles, trailers and semi-trailers",
  "Aerospace product and parts manufacturing ==> Aerospace product and parts manufacturing", "Other transport equipment",
  "Ship and boat building ==> Ship and boat building", "Other transport equipment",
  "Household and institutional furniture and kitchen cabinet manufacturing", "Manufacturing nec; repair and installation of machinery and equipment",
  "Office furniture (including fixtures) manufacturing", "Manufacturing nec; repair and installation of machinery and equipment",
  "Other furniture-related product manufacturing", "Manufacturing nec; repair and installation of machinery and equipment",
  "Medical equipment and supplies manufacturing", "Manufacturing nec; repair and installation of machinery and equipment",
  "Other miscellaneous manufacturing", "Manufacturing nec; repair and installation of machinery and equipment",
  "Telecommunications", "Telecommunications",
  "Coal mining ==> Coal mining", "Mining and quarrying, energy producing products",
  "Potash mining", "Mining and quarrying, non-energy producing products",
  "Grain and oilseed milling", "Food products, beverages and tobacco",
  "Tobacco manufacturing ==> Tobacco manufacturing", "Food products, beverages and tobacco",
  "Resin, synthetic rubber, and artificial and synthetic fibres and filaments manufacturing", "Chemical and pharmaceutical products",
  "Paint, coating and adhesive manufacturing", "Chemical and pharmaceutical products",
  "Pesticide, fertilizer and other agricultural chemical manufacturing ==> Pesticide, fertilizer and other agricultural chemical manufacturing", "Chemical and pharmaceutical products",
  "Iron and steel mills and ferro-alloy manufacturing", "Basic metals",
  "Alumina and aluminum production and processing", "Basic metals",
  "Hardware manufacturing", "Fabricated metal products",
  "Spring and wire product manufacturing", "Fabricated metal products",
  "Commercial and service industry machinery manufacturing", "Machinery and equipment, nec",
  "Engine, turbine and power transmission equipment manufacturing", "Machinery and equipment, nec",
  "Computer and peripheral equipment manufacturing ==> Computer and peripheral equipment manufacturing", "Computer, electronic and optical equipment",
  "Electrical equipment manufacturing", "Electrical equipment",
  "Household appliance manufacturing ==> Household appliance manufacturing", "Machinery and equipment, nec",
  "Automobile and light-duty motor vehicle manufacturing", "Motor vehicles, trailers and semi-trailers",
  "Heavy-duty truck manufacturing", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle body and trailer manufacturing ==> Motor vehicle body and trailer manufacturing", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle electrical and electronic equipment manufacturing", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle steering and suspension components (except spring) manufacturing", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle brake system manufacturing", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle transmission and power train parts manufacturing", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle seating and interior trim manufacturing", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle metal stamping", "Motor vehicles, trailers and semi-trailers",
  "Other motor vehicle parts manufacturing", "Motor vehicles, trailers and semi-trailers",
  "Railroad rolling stock manufacturing ==> Railroad rolling stock manufacturing", "Other transport equipment",
  "Other transportation equipment manufacturing ==> Other transportation equipment manufacturing", "Other transport equipment",
  "Other metal ore mining", "Mining and quarrying, non-energy producing products",
  "Diamond mining", "Mining and quarrying, non-energy producing products",
  "Oil and gas extraction (except oil sands)", "Mining and quarrying, energy producing products",
  "Oil sands extraction", "Mining and quarrying, energy producing products",
  "Other information services", "IT and other information services",
  "Owner occupied dwellings", "Real estate activities",
  "Banking and other depository credit intermediation", "Financial and insurance activities",
  "Local credit unions", "Financial and insurance activities",
  "Insurance carriers ==> Insurance carriers", "Financial and insurance activities",
  "Lessors of real estate ==> Lessors of real estate", "Real estate activities",
  "Automotive equipment rental and leasing", "Financial and insurance activities",
  "Rental and leasing services (except automotive equipment)", "Financial and insurance activities",
  "Lessors of non-financial intangible assets (except copyrighted works)", "Financial and insurance activities",
  "Non-depository credit intermediation", "Financial and insurance activities",
  "Financial investment services, funds and other financial vehicles", "Financial and insurance activities",
  "Agencies, brokerages and other insurance related activities", "Financial and insurance activities",
  "Offices of real estate agents and brokers and activities related to real estate", "Real estate activities",
  "Holding companies", "Financial and insurance activities",
  "Activities related to credit intermediation", "Financial and insurance activities"
)

theta_data <- tribble(
  ~sector, ~theta,
  # Agriculture group
  "Agriculture, hunting, forestry, fishing and aquaculture", 11.92, 
  
  # Manufacturing groups
  "Mining and quarrying, energy producing products", 11.92,
  "Mining and quarrying, non-energy producing products", 11.92,
  "Mining support service activities", 11.92,
  
  # Manufacturing groups
  "Food products, beverages and tobacco", 4.56, 
  "Textiles, textile products, leather and footwear", 4.56, 
  "Wood and products of wood and cork", 10.83,
  "Paper products and printing", 9.07, # average of paper and printing
  "Coke and refined petroleum products", 19.16,
  "Chemical and pharmaceutical products", 19.16, 
  "Rubber and plastics products", 19.16, 
  "Other non-metallic mineral products", 5.00,
  "Basic metals", 5.02,
  "Fabricated metal products", 5.02, 
  "Computer, electronic and optical equipment", 6.19,
  "Electrical equipment", 6.19, # Group with electronics
  "Machinery and equipment, nec", 6.19,
  "Motor vehicles, trailers and semi-trailers", 6.19,
  "Other transport equipment", 6.19,
  "Manufacturing nec; repair and installation of machinery and equipment", 5.00,
  
  # Services 
  "Utilities", 5.00,
  "Construction", 5.00,
  "Wholesale and retail trade; repair of motor vehicles", 5.00,
  "Transportation and related services", 5.00,
  "Accommodation and food service activities", 5.00,
  "Publishing, audiovisual and broadcasting activities", 5.00,
  "Telecommunications", 5.00,
  "IT and other information services", 5.00,
  "Financial and insurance activities", 5.00,
  "Real estate activities", 5.00,
  "Professional, scientific and technical activities", 5.00,
  "Administrative and support services", 5.00,
  "Public administration and defence; compulsory social security", 5.00,
  "Education", 5.00,
  "Human health and social work activities", 5.00,
  "Arts, entertainment and recreation", 5.00,
  "Other service activities", 5.00
)

## 0.3 Data pull
### Interprovincial trade data
trade_connection <- get_cansim_connection("12-10-0088-01")

trade_raw <- trade_connection %>% 
  filter(REF_DATE >= 2007,
         GEO %in% provincesplus) %>% 
  collect_and_normalize() %>% 
  select(Province = GEO, year = REF_DATE, `Trade flow detail`, Product, VALUE)

trade_rare <- trade_raw %>% 
  filter(
    !`Trade flow detail` %in% c("Total supply and demand",
                                "Total supply",
                                "Total demand"),
    !Product %in% c("Total products",
                    "Total goods", 
                    "Total services", 
                    "Taxes on products",
                    "Fictive materials",
                    "Fictive services",
                    "Subsidies on products",
                    "Subsidies on production",
                    "Taxes on production",
                    "Wages and salaries",
                    "Employers' social contributions",
                    "Gross mixed income",
                    "Gross operating surplus"))

### US-province trade data
us_trade_connection <- get_cansim_connection("12-10-0100-01") 

us_trade_raw <- us_trade_connection %>% 
  filter(GEO %in% provincesplus,
         `Value added exports variable` %in%
           c("Exports", "Re-exports", "Exports from inventories", "Imports"),
         Aggregation %in% c("Summary level", "Detailed level")) %>%
  collect_and_normalize()

us_trade_raw_half <- us_trade_raw %>% 
  filter(`Country Code` == "United States",
         Aggregation == "Summary level",
         !Industry %in% c("Total industries", "Mining, quarrying, and oil and gas extraction",
                          "Manufacturing", "Finance, insurance, real estate, rental and leasing and holding companies"
         )) %>% 
  select(Province = GEO, year = REF_DATE, 
         `Value added exports variable`, Industry, VALUE) %>% 
  mutate(value = VALUE / 1000)

us_trade_raw_other_half <- us_trade_raw %>% 
  filter(`Country Code` == "United States",
         `Classification Code for Industry` %in% 
           c("[BS211110]", "[BS211140]", "[BS212100]", # Mining and quarrying, energy producing products
             "[BS212210]", "[BS212220]", "[BS212230]", "[BS212290]", "[BS212310]", 
             "[BS212320]", "[BS212392]", "[BS21239A]", "[BS212396]", # Mining and quarrying, non-energy producing products
             "[BS21311A]", "[BS21311B]", # Mining support service activities 
             "[BS311100]", "[BS311300]", "[BS311400]", "[BS311500]", "[BS311600]", 
             "[BS311700]", "[BS311200]", "[BS311800]", "[BS311900]", "[BS312110]", 
             "[BS312120]", "[BS3121A0]", "[BS312200]", # Food products, beverages and tobacco
             "[BS31A000]", "[BS31B000]", # Textiles, textile products, leather and footwear   
             "[BS321100]", "[BS321200]", "[BS321900]", # Wood and products of wood and cork 
             "[BS322100]", "[BS322200]", "[BS323000]", # Paper products and printing
             "[BS324110]", "[BS3241A0]", # Coke and refined petroleum products
             "[BS325100]", "[BS325200]", "[BS325500]", "[BS325600]", "[BS325600]", 
             "[BS325300]", "[BS325400]", # Chemical and pharmaceutical products
             "[BS326100]", "[BS326200]", # Rubber and plastics products
             "[BS327A00]", "[BS327300]", # Other non-metallic mineral products
             "[BS331100]", "[BS331200]", "[BS331300]", "[BS331400]", "[BS331500]", # Basic metals
             "[BS332100]", "[BS332A00]", "[BS332300]", "[BS332400]", "[BS332500]", 
             "[BS332600]", "[BS332700]", "[BS332800]", # Fabricated metal products
             "[BS333100]", "[BS333200]", "[BS333300]", "[BS333400]", "[BS333500]", 
             "[BS333600]", "[BS333900]", "[BS335200]", # Machinery and equipment, nec 
             "[BS334100]", "[BS334200]", "[BS334A00]", "[BS334400]", # Computer, electronic and optical equipment
             "[BS335100]", "[BS335300]", "[BS335900]", # Electrical equipment
             "[BS336110]", "[BS336120]", "[BS336200]", "[BS336310]", "[BS336320]",
             "[BS336330]", "[BS336340]", "[BS336350]", "[BS336360]", "[BS336370]",
             "[BS336390]", # Motor vehicles, trailers and semi-trailers
             "[BS336400]", "[BS336500]", "[BS336600]", "[BS336900]", # Other transport equipment
             "[BS337100]", "[BS337200]", "[BS337900]", "[BS339100]", "[BS339900]", # Manufacturing nec; repair and installation of machinery and equipment
             "[BS517000]", # Telecommunications
             "[BS519000]", # IT and other information services
             "[BS5221A0]", "[BS522130]", "[BS524100]", "[BS532100]", "[BS532A00]", 
             "[BS533000]", "[BS522200]", "[BS522300]", "[BS52A000]", "[BS524200]", 
             "[BS551113]", "[BS521000]", # Financial and insurance activities
             "[BS531A00]", "[BS531100]" # Real estate activities
           )) %>% 
  select(Province = GEO, year = REF_DATE, 
         `Value added exports variable`, Industry, VALUE) %>% 
  mutate(value = VALUE / 1000)

us_trade_rare <- bind_rows(us_trade_raw_half, us_trade_raw_other_half)

### GDP data
gdp_connection <- get_cansim_connection("36-10-0221-01")

gdp_raw <- gdp_connection %>% 
  filter(REF_DATE == 2015,
         GEO %in% provincesplus,
         `Estimates` == "Gross domestic product at market prices") %>% 
  collect_and_normalize() 

### Spatial price data
price_connection <- get_cansim_connection("18-10-0003-01")

price_raw <- price_connection %>% 
  filter(REF_DATE == 2015,
         `Products and product groups` == "All-items") %>% 
  collect_and_normalize() 

## 0.4 Cleaning raw data
dest_cols <- unique(trade_rare$`Trade flow detail`) %>% str_subset("^To ")

int_exp <- trade_rare %>%
  filter(`Trade flow detail` == "International exports") %>% 
  mutate(dest = "ROW") %>% 
  select(origin = Province, dest, Product, year, value = VALUE)

int_imp <- trade_rare %>% 
  filter(`Trade flow detail` == "International imports") %>% 
  mutate(origin = "ROW") %>% 
  select(origin, dest = Province, Product, year, value = VALUE)

internal_flows <- trade_rare %>% 
  filter(`Trade flow detail` %in% dest_cols) %>% 
  mutate(dest = str_sub(`Trade flow detail`, 4)) %>% 
  filter(dest %in% provincesplus) %>% 
  select(origin = Province, dest, Product, year, value = VALUE)

flows <- bind_rows(internal_flows, int_exp, int_imp) %>% 
  mutate(
    origin = recode(origin,
                    "Alberta" = "AB", 
                    "British Columbia" = "BC", 
                    "Manitoba" = "MB",
                    "New Brunswick" = "NB", 
                    "Newfoundland and Labrador" = "NL",
                    "Nova Scotia" = "NS", 
                    "Ontario" = "ON", 
                    "Prince Edward Island" = "PE",
                    "Quebec" = "QC",
                    "Saskatchewan" = "SK",
                    "ROW" = "ROW",
                    "Yukon" = "YT", 
                    "Northwest Territories" = "NT",
                    "Nunavut" = "NU"
    ),
    dest   = recode(dest,
                    "Alberta" = "AB", 
                    "British Columbia" = "BC", 
                    "Manitoba" = "MB",
                    "New Brunswick" = "NB", 
                    "Newfoundland and Labrador" = "NL",
                    "Nova Scotia" = "NS", 
                    "Ontario" = "ON", 
                    "Prince Edward Island" = "PE",
                    "Quebec" = "QC",
                    "Saskatchewan" = "SK",
                    "ROW" = "ROW",
                    "Yukon" = "YT", 
                    "Northwest Territories" = "NT",
                    "Nunavut" = "NU"
    ),
    supc_sector = Product) %>% 
  clean_names()

flows_isic <- flows %>% 
  left_join(supc_to_sector, by = "supc_sector")

trade_flows_final <- flows_isic %>%
  group_by(origin, dest, sector, year) %>%
  summarise(value = sum(value, na.rm = TRUE), .groups = "drop")

us_exp <- us_trade_rare %>%
  filter(`Value added exports variable` %in% c("Exports", "Re-exports", "Exports from inventories")) %>% 
  # Group by all identifying characteristics
  group_by(Province, year, Industry) %>%
  # Sum the values to get the total export value
  summarise(value = sum(value, na.rm = TRUE), .groups = "drop") %>%
  # Add the origin and destination columns
  mutate(dest = "USA") %>% 
  select(origin = Province, dest, Industry, year, value)

us_imp <- us_trade_rare %>% 
  filter(`Value added exports variable` == "Imports") %>% 
  mutate(origin = "USA") %>% 
  select(origin, dest = Province, Industry, year, value)

us_flows <- bind_rows(us_exp, us_imp) %>% 
  mutate(
    origin = recode(origin,
                    "Alberta" = "AB", 
                    "British Columbia" = "BC", 
                    "Manitoba" = "MB",
                    "New Brunswick" = "NB", 
                    "Newfoundland and Labrador" = "NL",
                    "Nova Scotia" = "NS", 
                    "Ontario" = "ON", 
                    "Prince Edward Island" = "PE",
                    "Quebec" = "QC",
                    "Saskatchewan" = "SK",
                    "USA" = "USA",
                    "Yukon" = "YT", 
                    "Northwest Territories" = "NT",
                    "Nunavut" = "NU"
    ),
    dest   = recode(dest,
                    "Alberta" = "AB", 
                    "British Columbia" = "BC", 
                    "Manitoba" = "MB",
                    "New Brunswick" = "NB", 
                    "Newfoundland and Labrador" = "NL",
                    "Nova Scotia" = "NS", 
                    "Ontario" = "ON", 
                    "Prince Edward Island" = "PE",
                    "Quebec" = "QC",
                    "Saskatchewan" = "SK",
                    "USA" = "USA",
                    "Yukon" = "YT", 
                    "Northwest Territories" = "NT",
                    "Nunavut" = "NU"
    ),
    supc_sector2 = Industry) %>% 
  clean_names()

us_flows_isic <- us_flows %>% 
  left_join(supc_to_sector2, by = "supc_sector2")

us_trade_flows_final <- us_flows_isic %>%
  group_by(origin, dest, sector, year) %>%
  summarise(value = sum(value, na.rm = TRUE), .groups = "drop")

# Isolate the inter-provincial flows 
provincial_flows <- trade_flows_final %>% 
  filter(origin != "ROW" & dest != "ROW")

# Isolate the international flows 
international_flows <- trade_flows_final %>% 
  filter(origin == "ROW" | dest == "ROW")

# Perform the subtraction.
row_flows_corrected <- international_flows %>%
  left_join(
    us_trade_flows_final,
    by = c("origin", "dest", "sector", "year"),
    suffix = c("_total_intl", "_us") 
  ) %>%
  mutate(value_us = ifelse(is.na(value_us), 0, value_us)) %>%
  # Calculate the new, corrected flow value
  mutate(value = value_total_intl - value_us) %>%
  # Keep only the essential columns
  select(origin, dest, sector, year, value) %>%
  # Filter out any flows that are now zero or negative after subtraction
  filter(value > 0)

# The corrected flows dataset.
#    This now contains three distinct sets of flows:
#    a) Canadian inter-provincial
#    b) Canada-USA
#    c) Canada-ROW (where ROW no longer includes the USA)
flows_final <- bind_rows(provincial_flows, us_trade_flows_final, row_flows_corrected)
rm(provincial_flows, international_flows, row_flows_corrected)

gdp_data <- gdp_raw %>% 
  mutate(
    Province = recode(GEO,
                      "Alberta" = "AB", 
                      "British Columbia" = "BC", 
                      "Manitoba" = "MB",
                      "New Brunswick" = "NB", 
                      "Newfoundland and Labrador" = "NL",
                      "Nova Scotia" = "NS", 
                      "Ontario" = "ON", 
                      "Prince Edward Island" = "PE",
                      "Quebec" = "QC",
                      "Saskatchewan" = "SK",
                      "Yukon" = "YT",
                      "Northwest Territories" = "NT",
                      "Nunavut" = "NU"),
    gdp_value = VALUE) %>% 
  select(Province, gdp_value)

spatial_price_data <- price_raw %>% 
  mutate(
    Province = recode(GEO,
                      "Calgary, Alberta" = "AB",
                      "Edmonton, Alberta" = "AB", 
                      "Vancouver, British Columbia" = "BC", 
                      "Winnipeg, Manitoba" = "MB",
                      "Saint John, New Brunswick" = "NB", 
                      "St. John's, Newfoundland and Labrador" = "NL",
                      "Halifax, Nova Scotia" = "NS", 
                      "Ottawa-Gatineau, Ontario part, Ontario/Quebec" = "ON",
                      "Toronto, Ontario" = "ON",
                      "Charlottetown and Summerside, Prince Edward Island" = "PE",
                      "Montréal, Quebec" = "QC",
                      "Regina, Saskatchewan" = "SK")) %>% 
  group_by(Province) %>% 
  mutate(
    price_index = mean(VALUE)) %>% 
  select(Province, price_index) %>% 
  distinct()

territory_spatial_price <- tribble(
  ~Province, ~price_index,
  "YT", 103, # 2017 value; 2015 not available
  "NT", 112, # 2017 value; 2015 not available
  "NU", 112, # NT's 2017 value; no all-items values available
)

spatial_price_data <- bind_rows(spatial_price_data, territory_spatial_price)

## 0.5 US and ROW production data
load("ICIO2023econZ.RData")
load("ICIO2023econFD.RData")
load("ICIO2023econVA.RData")
load("ICIO2023econGTR.RData") 
load("ICIO2023econX.RData")
fx_data <- read_csv("FXUSDCAD.csv", show_col_types = FALSE)

# Define the years for the analysis
years_full <- 1995:2020
years_needed <- 2007:2019

TARGET_YEAR <- 2015 

ind_map <- c(
  "01T02" = "Agriculture, hunting, forestry, fishing and aquaculture",
  "03" = "Agriculture, hunting, forestry, fishing and aquaculture",
  "05T06" = "Mining and quarrying, energy producing products",
  "07T08" = "Mining and quarrying, non-energy producing products",
  "09" = "Mining support service activities",
  "10T12" = "Food products, beverages and tobacco",
  "13T15" = "Textiles, textile products, leather and footwear",
  "16" = "Wood and products of wood and cork",
  "17T18" = "Paper products and printing",
  "19" = "Coke and refined petroleum products",
  "20" = "Chemical and pharmaceutical products",
  "21" = "Chemical and pharmaceutical products",
  "22" = "Rubber and plastics products",
  "23" = "Other non-metallic mineral products",
  "24" = "Basic metals",
  "25" = "Fabricated metal products",
  "26" = "Computer, electronic and optical equipment",
  "27" = "Electrical equipment",
  "28" = "Machinery and equipment, nec",
  "29" = "Motor vehicles, trailers and semi-trailers",
  "30" = "Other transport equipment",
  "31T33" = "Manufacturing nec; repair and installation of machinery and equipment",
  "35" = "Utilities",
  "36T39" = "Utilities",
  "41T43" = "Construction",
  "45T47" = "Wholesale and retail trade; repair of motor vehicles",
  "49" = "Transportation and related services",
  "50" = "Transportation and related services",
  "51" = "Transportation and related services",
  "52" = "Transportation and related services",
  "53" = "Transportation and related services",
  "55T56" = "Accommodation and food service activities",
  "58T60" = "Publishing, audiovisual and broadcasting activities",
  "61" = "Telecommunications",
  "62T63" = "IT and other information services",
  "64T66" = "Financial and insurance activities",
  "68" = "Real estate activities",
  "69T75" = "Professional, scientific and technical activities",
  "77T82" = "Administrative and support services",
  "84" = "Public administration and defence; compulsory social security",
  "85" = "Education",
  "86T88" = "Human health and social work activities",
  "90T93" = "Arts, entertainment and recreation",
  "94T96" = "Other service activities",
  "97T98" = "Other service activities"
)

# Convert the mapping to a more usable data frame
ind_map_df <- data.frame(
  Industry_Code_User = names(ind_map),
  Agg_Industry = unname(ind_map)
)

#----------------------------------------------------------------#
# Step 1: Load and Prepare Auxiliary Data
#----------------------------------------------------------------#
# Map for origins (rows of both Z and FD matrices)
rows_agg_map <- tibble(RowCode = dimnames(ICIO2023econZ)[[2]]) %>%
  mutate(
    Country = str_extract(RowCode, "^[A-Z]{3}"),
    Industry_Code_User = str_remove(RowCode, "^[A-Z]{3}_")
  ) %>%
  filter(Country != "CAN", !Country %in% c("CN1", "CN2", "MX1", "MX2")) %>%
  mutate(origin = if_else(Country == "USA", "USA", "ROW")) %>%
  left_join(ind_map_df, by = "Industry_Code_User") %>%
  select(RowCode, origin, Agg_Industry) %>%
  filter(!is.na(Agg_Industry))

# Map for intermediate dests (columns of Z matrix)
cols_z_agg_map <- tibble(ColCode = dimnames(ICIO2023econZ)[[3]]) %>%
  mutate(
    Country = str_extract(ColCode, "^[A-Z]{3}")
  ) %>%
  filter(Country != "CAN", !Country %in% c("CN1", "CN2", "MX1", "MX2")) %>%
  mutate(dest = if_else(Country == "USA", "USA", "ROW")) %>%
  select(ColCode, dest)

# Map for final demand dests (columns of FD matrix are just country codes)
cols_fd_agg_map <- tibble(ColCode = dimnames(ICIO2023econFD)[[3]]) %>%
  filter(ColCode != "CAN", !ColCode %in% c("CN1", "CN2", "MX1", "MX2")) %>%
  mutate(dest = if_else(ColCode == "USA", "USA", "ROW"))

#----------------------------------------------------------------#
# Step 2: Load and Process ICIO Data
#----------------------------------------------------------------#
# --- Process Intermediate Demand (Z) ---
# Define the years of analysis from the data dimensions
years <- as.integer(dimnames(ICIO2023econZ)[[1]])

process_year <- function(year_index) {
  current_year <- years[year_index]
  
  # --- Process Intermediate Demand (Z) ---
  z_long_year <- as.data.frame.table(ICIO2023econZ[year_index, , ], responseName = "Value_USD")
  names(z_long_year) <- c("RowCode", "ColCode", "Value_USD")
  
  # Use left_join to keep all industries, even those with zero trade
  intermediate_year <- z_long_year %>%
    left_join(rows_agg_map, by = "RowCode") %>%
    left_join(cols_z_agg_map, by = "ColCode") %>%
    # Filter out rows that didn't match our regions of interest (USA/ROW)
    filter(!is.na(origin), !is.na(dest)) %>%
    group_by(origin, dest, sector = Agg_Industry) %>%
    summarise(Intermediate_Value = sum(Value_USD, na.rm = TRUE), .groups = 'drop')
  
  # --- Process Final Demand (FD) ---
  fd_long_year <- as.data.frame.table(ICIO2023econFD[year_index, , ], responseName = "Value_USD")
  names(fd_long_year) <- c("RowCode", "ColCode", "Value_USD")
  
  # Use left_join here as well for robustness
  final_year <- fd_long_year %>%
    left_join(rows_agg_map, by = "RowCode") %>%
    left_join(cols_fd_agg_map, by = "ColCode") %>%
    filter(!is.na(origin), !is.na(dest)) %>%
    group_by(origin, dest, sector = Agg_Industry) %>%
    summarise(Final_Value = sum(Value_USD, na.rm = TRUE), .groups = 'drop')
  
  # --- Combine flows ---
  year_results <- full_join(intermediate_year, final_year, by = c("origin", "dest", "sector")) %>%
    mutate(
      year = current_year,
      Value_USD = (if_else(is.na(Intermediate_Value), 0, Intermediate_Value) + 
                     if_else(is.na(Final_Value), 0, Final_Value))
    ) %>%
    select(year, origin, dest, sector, Value_USD)
  
  return(year_results)
}

# Run for all years
all_years_data <- map_df(1:length(years), process_year)

#----------------------------------------------------------------#
# Step 3 & 4: Final Conversion and Display
#----------------------------------------------------------------#

fx_annual <- fx_data %>%
  mutate(year = as.integer(format(as.Date(date, format = "%m/%d/%Y"), "%Y"))) %>%
  group_by(year) %>%
  summarise(FX_USDCAD = mean(value), .groups = 'drop')

non_can_flows_final <- all_years_data %>%
  left_join(fx_annual, by = "year") %>%
  mutate(value = Value_USD * FX_USDCAD) %>%
  filter(value != 0) %>%
  select(year, origin, dest, sector, value) %>%
  arrange(year, origin, dest, sector)

panel <- rbindlist(list(flows_final, non_can_flows_final), use.names = TRUE, fill = TRUE)

## 0.6 Define neighboring provinces and interprovincial agreements
neighbours <- list(
  "AB" = c("BC", "SK", "NT"),
  "BC" = c("AB", "YT"),
  "MB" = c("SK", "ON", "NU"),
  "NB" = c("QC", "NS"),
  "NL" = c("QC"),
  "NS" = c("NB", "NL"),
  "NT" = c("YT", "BC", "AB", "SK", "MB", "NU"),
  "NU" = c("MB", "NT"),
  "ON" = c("MB", "QC"),
  "PE" = c("NB"),
  "QC" = c("ON", "NB", "NL"),
  "SK" = c("AB", "MB", "NT"),
  "YT" = c("BC", "NT")
)

panel_neighbours <- panel %>%
  rowwise() %>%
  mutate(neighbour = if_else(dest %in% neighbours[[origin]], 1, 0)) %>%
  ungroup()

panel_full <- panel_neighbours %>% 
  left_join(theta_data, by = "sector") 

write_csv(panel_full, "2019_replication_panel_full.csv")
panel_full <- read_csv("2019_replication_panel_full.csv")

# 1. Calculate expenditure shares
## 1.1 expenditure shares  π_{ni}^j
shares <- panel_full %>% 
  group_by(dest, sector, year) %>% 
  mutate(pi = value / sum(value, na.rm = TRUE)) %>% 
  ungroup()

## 1.2 self-shares π_nn^j  and  π_ii^j
self_pi <- shares %>% 
  filter(origin == dest) %>% 
  select(prov = origin, sector, year, pi_self = pi) 

shares <- shares %>% 
  left_join(self_pi,  by = c("dest"   = "prov", "sector", "year")) %>% 
  rename(pi_nn = pi_self) %>% 
  left_join(self_pi,  by = c("origin" = "prov", "sector", "year")) %>% 
  rename(pi_ii = pi_self)

## 1.3 reverse-flow share π_{in}^j
shares <- shares %>% 
  left_join(
    shares %>% 
      select(origin_rev = origin, dest_rev = dest, sector, year, pi_rev = pi),
    by = c("origin" = "dest_rev", "dest" = "origin_rev", "sector", "year")
  ) %>% 
  rename(pi_in = pi_rev, pi_ni = pi) 

## 1.4 τ̄_{ni}^j
shares_clean <- shares %>%
  filter(pi_ni > 0, pi_in > 0, pi_nn > 0, pi_ii > 0) %>%
  mutate(
    tau_bar = ((pi_nn * pi_ii) / (pi_ni * pi_in))^(1/(2*theta))
  )

# 2. Distance calculation
## 2.1 Load the Dissemination Area data from 2021
da_raw <- read.csv("2006_92-151-XBB.csv", stringsAsFactors=TRUE)

names(da_raw) <- toupper(names(da_raw))

da_data <- da_raw %>%
  select(PRENAME, lat = DALAT, lon = DALONG, Population = DBPOP2006) %>%
  mutate(
    prov = recode(PRENAME,
                  "Alberta"="AB",
                  "British Columbia"="BC",
                  "Manitoba"="MB",
                  "New Brunswick"="NB",
                  "Newfoundland and Labrador"="NL",
                  "Nova Scotia"="NS",
                  "Ontario"="ON",
                  "Prince Edward Island"="PE",
                  "Quebec"="QC",
                  "Saskatchewan"="SK",
                  "Yukon Territory"="YT",
                  "Nunavut"="NU",
                  "Northwest Territories"="NT"
    ),) %>%
  filter(prov %in% provsplus, !is.na(prov), !is.na(Population)) %>% 
  mutate(
    Population = as.numeric(Population),
    lat = as.numeric(lat),
    lon = as.numeric(lon)
  ) %>%
  filter(!is.na(lat) & !is.na(lon) & !is.na(Population))

## 2.3 Calculate population-weighted provincial centroids
prov_centroids <- da_data %>%
  group_by(prov) %>%
  summarise(
    lon = weighted.mean(lon, Population, na.rm = TRUE),
    lat = weighted.mean(lat, Population, na.rm = TRUE)
  )

almaty_coords <- tribble(
  ~prov, ~lat, ~lon,
  "ROW", 43.238949, 76.889709)

us_centroid <- tribble(
  ~prov, ~lon, ~lat,
  "USA", -91.809567, 37.696987)

all_centroids <- bind_rows(prov_centroids, us_centroid, almaty_coords)

## 2.4 Calculate within-province distances (d_nn)
# This is the population-weighted average distance from each DA to its provincial centroid.
d_nn_calc <- da_data %>%
  left_join(prov_centroids, by = "prov", suffix = c("_da", "_prov")) %>%
  mutate(
    dist_to_centroid = distHaversine(cbind(lon_da, lat_da), cbind(lon_prov, lat_prov)) / 1000
  ) %>%
  group_by(prov) %>%
  summarise(
    d_nn = weighted.mean(dist_to_centroid, Population, na.rm = TRUE)
  )

## 2.5 Create the final distance matrix for Canada
dist_mat <- expand_grid(origin = c(provsplus, "USA"), dest = c(provsplus, "USA")) %>%
  left_join(all_centroids, by = c("origin" = "prov")) %>% rename(lat_o = lat, lon_o = lon) %>%
  left_join(all_centroids, by = c("dest"   = "prov")) %>% rename(lat_d = lat, lon_d = lon) %>%
  mutate(
    # Between-province distance (d_ni) is centroid-to-centroid
    distance = distHaversine(cbind(lon_o, lat_o), cbind(lon_d, lat_d)) / 1000
  ) %>%
  # Join the within-province distances (d_nn and d_ii)
  left_join(d_nn_calc, by = c("origin" = "prov")) %>% rename(d_nn_o = d_nn) %>%
  left_join(d_nn_calc, by = c("dest"   = "prov")) %>% rename(d_nn_d = d_nn) %>%
  # For intra-province pairs, distance is d_nn. For others, it's centroid-to-centroid.
  mutate(
    distance = ifelse(origin == dest, d_nn_o, distance)
  )

## 2.6. U.S. Data
us_land_area_sq_km <- 9525067 
d_nn_us <- (2/3) * sqrt(us_land_area_sq_km / pi)

dist_us_us <- data.frame(origin = "USA", dest = "USA", distance = d_nn_us, d_nn_o = d_nn_us, d_nn_d = d_nn_us)

## 2.8 Add ROW (Almaty, Kazakhstan)
row_land_area_sq_km <- 490562263 # total land area sub US and CAN 
d_nn_row <- (2/3) * sqrt(row_land_area_sq_km / pi)
dist_row_row <- data.frame(origin = "ROW", dest = "ROW", distance = d_nn_row, d_nn_o = d_nn_row, d_nn_d = d_nn_row)

dist_can_row <- prov_centroids %>%
  ungroup() %>%
  mutate(
    distance = distHaversine(cbind(lon, lat), c(almaty_coords$lon, almaty_coords$lat)) / 1000
  ) %>%
  select(origin = prov, distance) %>%
  mutate(dest = "ROW") %>%
  left_join(d_nn_calc, by = c("origin" = "prov")) %>%
  rename(d_nn_o = d_nn) %>%
  mutate(d_nn_d = d_nn_row)

dist_row_can <- dist_can_row %>%
  rename(dest = origin, origin = dest) %>%
  mutate(d_nn_o = d_nn_row, d_nn_d = d_nn_o) %>%
  select(origin, dest, distance, d_nn_o, d_nn_d)

dist_us_row_val <- distHaversine(c(us_centroid$lon, us_centroid$lat), c(almaty_coords$lon, almaty_coords$lat)) / 1000

dist_us_row <- data.frame(origin = "USA", dest = "ROW", distance = dist_us_row_val, d_nn_o = d_nn_us, d_nn_d = d_nn_row)
dist_row_us <- data.frame(origin = "ROW", dest = "USA", distance = dist_us_row_val, d_nn_o = d_nn_row, d_nn_d = d_nn_us)

## 2.9 Append all matrices
dist_mat_final <- bind_rows(dist_mat, dist_us_us, dist_can_row, dist_row_can, dist_us_row, dist_row_us, dist_row_row) %>% 
  filter(!is.na(distance))

# 3. Regressions
shares_dist <- shares_clean  %>% 
  left_join(dist_mat_final, by = c("origin", "dest")) %>% 
  filter(!sector %in% c(
    "Construction", 
    "Public administration and defence; compulsory social security", 
    "Utilities"))

shares_dist <- shares_dist %>%
  mutate(
    log_tau = log(tau_bar),
    log_dist = log(distance),
    intra_dummy = if_else(origin %in% provsplus & dest %in% provsplus & origin == dest, 1, 0),
  ) %>%
  mutate(
    expyr = interaction(origin, year, drop = TRUE),
    impyr = interaction(dest,   year, drop = TRUE),
  )

# Extract geographic and non-geographic components
non_distance_cost_results_final <- data.frame()

# Get a list of sectors to loop over
sectors_to_regress <- unique(shares_dist$sector)

for (s in sectors_to_regress) {
  
  sector_data <- shares_dist %>% filter(sector == s)
  
  # Run the cost gravity model
  geo_mod <- feols(
    log_tau ~ distance + neighbour + intra_dummy
    | expyr + impyr,
    cluster = ~ origin + dest,
    data     = sector_data
  )
  
  # Calculate the purely geographic component of cost
  # 1. Extract the raw coefficients
  beta_dist <- coef(geo_mod)["distance"]
  gamma_neigh <- coef(geo_mod)["neighbour"]

  # 2. Calculate the non-distance cost factor in one step
  # Formula: (Total Cost / Geographic Cost) - 1
  # Geographic Cost = exp(beta*dist + gamma*neigh)
  sector_data <- sector_data %>%
    mutate(
      tau_NG = (tau_bar / exp(beta_dist * distance
                              + gamma_neigh * neighbour))
    )
    
  sector_data <- sector_data %>%
    mutate(
      tau_cf_raw = exp(beta_dist * distance +
                                 gamma_neigh * neighbour),
      tau_counterfactual = pmin(tau_cf_raw, tau_bar)
    )
  
  non_distance_cost_results_final <- rbind(non_distance_cost_results_final, sector_data)
}
  
write_csv(shares_dist, "2019_replication_full_data.csv")
shares_dist <- read_csv("2019_replication_full_data.csv")

write_csv(non_distance_cost_results_final, "2019_replication_non_distance.csv")
non_distance_cost_results_final <- read_csv("2019_replication_non_distance.csv")
# ===================================================================================
# ADAPTED MODEL SOLVER FOR TOMBE IMPROVEMENT (2015)
# Replace everything after line 1044 in "Tombe Improvement R.R"
# ===================================================================================

# ===================================================================================
# 1. DATA PREPARATION
# ===================================================================================
# Extract 2015 data slice (Year 2015 is index 25 in the 1995-2020 array)

Z_2015 <- ICIO2023econZ[21, , ]
FD_2015 <- ICIO2023econFD[21, , ]
X_2015 <- ICIO2023econX[21, ]
VA_2015 <- ICIO2023econVA[21, ]

TARGET_YEAR <- 2015
REGIONS <- c(provsplus, "USA", "ROW")

sut_product_to_sector_map <- tribble(
  ~sut_product, ~sector,
  "Grains and other crop products", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Live animals", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Other farm products", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Forestry products and services", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Fish, crustaceans, shellfish and other fishery products", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Support services related to farming and forestry", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Mineral fuels", "Mining and quarrying, energy producing products",
  "Metal ores and concentrates", "Mining and quarrying, non-energy producing products",
  "Non-metallic minerals", "Mining and quarrying, non-energy producing products",
  "Mineral support services", "Mining support service activities",
  "Mineral and oil and gas exploration", "Mining support service activities",
  "Utilities", "Utilities",
  "Residential construction", "Construction", 
  "Non-residential buildings", "Construction",
  "Engineering construction", "Construction", 
  "Repair construction services", "Construction",
  "Food and non-alcoholic beverages", "Food products, beverages and tobacco",
  "Alcoholic beverages and tobacco products", "Food products, beverages and tobacco",
  "Textile products, clothing, and products of leather and similar materials", "Textiles, textile products, leather and footwear",
  "Wood products", "Wood and products of wood and cork",
  "Wood pulp, paper and paper products and paper stock", "Paper products and printing",
  "Printed products and services", "Paper products and printing",
  "Refined petroleum products (except petrochemicals)", "Coke and refined petroleum products",
  "Chemical products", "Chemical and pharmaceutical products",
  "Plastic and rubber products", "Rubber and plastics products",
  "Non-metallic mineral products", "Other non-metallic mineral products",
  "Primary metallic products", "Basic metals",
  "Fabricated metallic products", "Fabricated metal products",
  "Industrial machinery", "Machinery and equipment, nec",
  "Computers and electronic products", "Computer, electronic and optical equipment",
  "Electrical equipment, appliances and components", "Electrical equipment",
  "Transportation equipment", "Other transport equipment",
  "Motor vehicle parts", "Motor vehicles, trailers and semi-trailers",
  "Furniture and related products", "Manufacturing nec; repair and installation of machinery and equipment",
  "Other manufactured products and custom work", "Manufacturing nec; repair and installation of machinery and equipment",
  "Wholesale margins and commissions", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins, sales of used goods and commissions", "Wholesale and retail trade; repair of motor vehicles",
  "Transportation and related services", "Transportation and related services",
  "Published and recorded media products", "Publishing, audiovisual and broadcasting activities",
  "Information and cultural services", "Publishing, audiovisual and broadcasting activities",
  "Telecommunications", "Telecommunications",
  "Depository credit intermediation", "Financial and insurance activities",
  "Other finance and insurance", "Financial and insurance activities",
  "Imputed rental of owner-occupied dwellings", "Real estate activities",
  "Real estate, rental and leasing and rights to non-financial intangible assets", "Real estate activities",
  "Professional services (except software and research and development)", "Professional, scientific and technical activities",
  "Software", "IT and other information services",
  "Research and development", "Professional, scientific and technical activities",
  "Administrative and support, head office, waste management and remediation services", "Administrative and support services",
  "Educational services", "Education", 
  "Health and social assistance services", "Human health and social work activities",
  "Arts, entertainment and recreation services", "Arts, entertainment and recreation",
  "Accommodation and food services", "Accommodation and food service activities",
  "Other services", "Other service activities",
  "Sales of other services by Non-Profit Institutions Serving Households", "Public administration and defence; compulsory social security",
  "Services provided by Non-Profit Institutions Serving Households", "Public administration and defence; compulsory social security",
  "Education services provided by government sector", "Education",
  "Sales of other government services", "Public administration and defence; compulsory social security",
  "Health services provided by government sector", "Human health and social work activities",
  "Other federal government services", "Public administration and defence; compulsory social security",
  "Other provincial and territorial government services", "Public administration and defence; compulsory social security",
  "Other municipal government services", "Public administration and defence; compulsory social security",
  "Other aboriginal government services", "Public administration and defence; compulsory social security"
)

sut_product_to_sector_map_use <- tribble(
  ~sut_product, ~sector,
  
  # --- Agriculture, Forestry, Fishing ---
  "Canola (including rapeseed)", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Oilseeds (except canola)", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Wheat", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Grains (except wheat)", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Fresh potatoes", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Fresh fruits and nuts", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Other miscellaneous crop products", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Fresh vegetables (except potatoes)", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Imputed feed (animal feed produced for own consumption)", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Fuel wood", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Support services for crop production", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Nursery and floriculture products (except cannabis)", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Cannabis plants, seeds and flowering tops", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Cattle and calves", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Unprocessed fluid milk", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Hogs", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Eggs in shell", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Poultry", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Other live animals", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Raw furskins, and animal products n.e.c.", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Imputed fertilizer (fertilizer produced for own consumption)", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Support services for animal production, hunting and fishing", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Fish, crustaceans, shellfish and other fishery products", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Logs and bolts", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Pulpwood", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Rough untreated poles, posts and piling", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Custom work services for forestry", "Agriculture, hunting, forestry, fishing and aquaculture",
  "Support services for forestry", "Agriculture, hunting, forestry, fishing and aquaculture",
  
  # --- Mining & Quarrying ---
  "Conventional crude oil", "Mining and quarrying, energy producing products",
  "Natural gas", "Mining and quarrying, energy producing products",
  "Natural gas liquids and related products", "Mining and quarrying, energy producing products",
  "Synthetic crude oil", "Mining and quarrying, energy producing products",
  "Crude and diluted bitumen", "Mining and quarrying, energy producing products",
  "Coal", "Mining and quarrying, energy producing products",
  "Iron ores and concentrates", "Mining and quarrying, non-energy producing products",
  "Gold and silver ores and concentrates", "Mining and quarrying, non-energy producing products",
  "Copper ores and concentrates", "Mining and quarrying, non-energy producing products",
  "Lead and zinc ores and concentrates", "Mining and quarrying, non-energy producing products",
  "Nickel ores and concentrates", "Mining and quarrying, non-energy producing products",
  "Other metal ores and concentrates", "Mining and quarrying, non-energy producing products",
  "Radioactive ores and concentrates", "Mining and quarrying, non-energy producing products",
  "Stone", "Mining and quarrying, non-energy producing products",
  "Sand, gravel, clay, and refractory minerals", "Mining and quarrying, non-energy producing products",
  "Uncut and industrial diamonds", "Mining and quarrying, non-energy producing products",
  "Potash", "Mining and quarrying, non-energy producing products",
  "Non-metallic minerals (except diamonds)", "Mining and quarrying, non-energy producing products",
  
  # --- Mining Support ---
  "Mineral and oil and gas exploration", "Mining support service activities",
  "Support services for mining and quarrying (except exploration)", "Mining support service activities",
  "Support services for oil and gas extraction (except exploration)", "Mining support service activities",
  
  # --- Utilities ---
  "Electricity", "Utilities",
  "Steam and heated or cooled air or water", "Utilities",
  "Natural gas distribution", "Utilities",
  "Water delivered by water works and irrigation systems", "Utilities",
  "Sewage and dirty water disposal and cleaning services", "Utilities",
  
  # --- Construction ---
  "Residential construction", "Construction",
  "Industrial buildings", "Construction",
  "Office buildings", "Construction",
  "Shopping centers, plazas, malls and stores", "Construction",
  "Other commercial buildings", "Construction",
  "Schools, colleges, universities and other educational buildings", "Construction",
  "Health care buildings", "Construction",
  "Other institutional buildings", "Construction",
  "Highways, roads, streets, bridges and tunnels", "Construction",
  "Other transportation construction", "Construction",
  "Production facilities in oil and gas extraction", "Construction",
  "Other oil and gas engineering construction", "Construction",
  "Electric power engineering construction", "Construction",
  "Communication engineering construction", "Construction",
  "Marine engineering construction", "Construction",
  "Waterworks engineering construction", "Construction",
  "Sewage engineering construction", "Construction",
  "Mining engineering construction", "Construction",
  "Other engineering construction", "Construction",
  "Repair construction services", "Construction",
  
  # --- Food, Beverages & Tobacco ---
  "Dog and cat food", "Food products, beverages and tobacco",
  "Other animal feed", "Food products, beverages and tobacco",
  "Flour and other grain mill products", "Food products, beverages and tobacco",
  "Margarine and cooking oils", "Food products, beverages and tobacco",
  "Grain and oilseed products, n.e.c.", "Food products, beverages and tobacco",
  "Fresh and frozen poultry of all types", "Food products, beverages and tobacco",
  "Processed meat products, other miscellaneous meats and animal by-products", "Food products, beverages and tobacco",
  "Prepared and packaged seafood products", "Food products, beverages and tobacco",
  "Cookies, crackers and baked sweet goods", "Food products, beverages and tobacco",
  "Flour mixes, dough and dry pasta", "Food products, beverages and tobacco",
  "Snack food products", "Food products, beverages and tobacco",
  "Coffee and tea", "Food products, beverages and tobacco",
  "Flavouring syrups, seasonings and dressings", "Food products, beverages and tobacco",
  "Other food products, n.e.c.", "Food products, beverages and tobacco",
  "Breakfast cereal and other cereal products", "Food products, beverages and tobacco",
  "Confectionery products", "Food products, beverages and tobacco",
  "Butter and dry and canned dairy products", "Food products, beverages and tobacco",
  "Sugar and sugar mill by-products", "Food products, beverages and tobacco",
  "Chocolate (except confectionery)", "Food products, beverages and tobacco",
  "Preserved fruit and vegetables and frozen foods", "Food products, beverages and tobacco",
  "Fresh, frozen and canned fruit and vegetable juices", "Food products, beverages and tobacco",
  "Bottled water, soft drinks and ice", "Food products, beverages and tobacco",
  "Processed fluid milk and milk products", "Food products, beverages and tobacco",
  "Cheese and cheese products", "Food products, beverages and tobacco",
  "Ice cream, sherbet and similar frozen desserts", "Food products, beverages and tobacco",
  "Fresh and frozen beef and veal", "Food products, beverages and tobacco",
  "Fresh and frozen pork", "Food products, beverages and tobacco",
  "Bread, rolls and flatbreads", "Food products, beverages and tobacco",
  "Beer", "Food products, beverages and tobacco",
  "Wine and brandy", "Food products, beverages and tobacco",
  "Distilled liquor", "Food products, beverages and tobacco",
  "Stemmed, redried or reconstituted tobacco", "Food products, beverages and tobacco",
  "Cigarettes, cigars, chewing and smoking tobacco", "Food products, beverages and tobacco",
  "Prepared meals", "Food products, beverages and tobacco",
  "Alcoholic beverages for immediate consumption", "Food products, beverages and tobacco",
  
  # --- Textiles, Leather ---
  "Fibre, yarn and thread", "Textiles, textile products, leather and footwear",
  "Fabrics", "Textiles, textile products, leather and footwear",
  "Carpets, rugs and mats", "Textiles, textile products, leather and footwear",
  "Other textile furnishings", "Textiles, textile products, leather and footwear",
  "Textile products, n.e.c.", "Textiles, textile products, leather and footwear",
  "Textile and fabric finishing and coating services", "Textiles, textile products, leather and footwear",
  "Men's, women's, boys' and girls' clothing", "Textiles, textile products, leather and footwear",
  "Clothing accessories", "Textiles, textile products, leather and footwear",
  "Infant clothing", "Textiles, textile products, leather and footwear",
  "Leather and dressed furs", "Textiles, textile products, leather and footwear",
  "Footwear", "Textiles, textile products, leather and footwear",
  "Suitcases, handbags and other leather and allied products", "Textiles, textile products, leather and footwear",
  
  # --- Wood Products ---
  "Hardwood lumber", "Wood and products of wood and cork",
  "Softwood lumber", "Wood and products of wood and cork",
  "Other sawmill products and treated wood products", "Wood and products of wood and cork",
  "Veneer and plywood", "Wood and products of wood and cork",
  "Wood trusses and engineered wood members", "Wood and products of wood and cork",
  "Wood containers and pallets", "Wood and products of wood and cork",
  "Wood products, n.e.c.", "Wood and products of wood and cork",
  "Reconstituted wood products", "Wood and products of wood and cork",
  "Prefabricated wood and manufactured (mobile) buildings and components", "Wood and products of wood and cork",
  "Wood windows and doors", "Wood and products of wood and cork",
  "Wood kitchen cabinets and counter tops", "Wood and products of wood and cork",
  "Wood chips", "Wood and products of wood and cork",
  "Waste and scrap of wood and wood by-products", "Wood and products of wood and cork",
  
  # --- Paper & Printing ---
  "Contract printing services for publishers", "Paper products and printing",
  "Other converted paper products", "Paper products and printing",
  "Printed products", "Paper products and printing",
  "Support services for printing", "Paper products and printing",
  "Wood pulp", "Paper products and printing",
  "Paper (except newsprint)", "Paper products and printing",
  "Newsprint", "Paper products and printing",
  "Paperboard", "Paper products and printing",
  "Paperboard containers", "Paper products and printing",
  "Sanitary paper products", "Paper products and printing",
  "Waste and scrap of paper and paperboard", "Paper products and printing",
  "Paper office supplies", "Paper products and printing",
  "Disposable diapers and feminine hygiene products", "Paper products and printing",
  "Newspapers", "Paper products and printing",
  "Periodicals", "Paper products and printing",
  "Books", "Paper products and printing",
  "Other published products", "Paper products and printing",
  
  # --- Coke & Refined Petroleum ---
  "Coke and other coke oven products", "Coke and refined petroleum products",
  "Gasoline", "Coke and refined petroleum products",
  "Diesel and biodiesel fuels", "Coke and refined petroleum products",
  "Light fuel oils", "Coke and refined petroleum products",
  "Jet fuel", "Coke and refined petroleum products",
  "Heavy fuel oils", "Coke and refined petroleum products",
  "Lubricants and other petroleum refinery products", "Coke and refined petroleum products",
  "Asphalt (except natural) and asphalt products", "Coke and refined petroleum products",
  "Solid fuel products, n.e.c.", "Coke and refined petroleum products",
  
  # --- Chemicals & Pharmaceuticals ---
  "Ammonia and chemical fertilizers", "Chemical and pharmaceutical products",
  "Pharmaceutical and medicinal products", "Chemical and pharmaceutical products",
  "Chemical products, n.e.c.", "Chemical and pharmaceutical products",
  "Paints, coatings and adhesive products", "Chemical and pharmaceutical products",
  "Basic organic chemicals, n.e.c.", "Chemical and pharmaceutical products",
  "Plastic resins", "Chemical and pharmaceutical products",
  "Artificial and synthetic fibres and filaments", "Chemical and pharmaceutical products",
  "Petrochemicals", "Chemical and pharmaceutical products",
  "Industrial gases", "Chemical and pharmaceutical products",
  "Dyes and pigments", "Chemical and pharmaceutical products",
  "Pesticides and other agricultural chemicals", "Chemical and pharmaceutical products",
  "Soaps and cleaning compounds", "Chemical and pharmaceutical products",
  "Perfumes and toiletries", "Chemical and pharmaceutical products",
  "Other basic inorganic chemicals", "Chemical and pharmaceutical products",
  
  # --- Rubber & Plastics ---
  "Rubber and plastic hoses and belts", "Rubber and plastics products",
  "Plastic bags", "Rubber and plastics products",
  "Plastic products, n.e.c.", "Rubber and plastics products",
  "Rubber products, n.e.c.", "Rubber and plastics products",
  "Plastic and foam building and construction materials", "Rubber and plastics products",
  "Plastic films and non-rigid sheets", "Rubber and plastics products",
  "Rubber and rubber compounds and mixtures", "Rubber and plastics products",
  "Foam products (except for construction)", "Rubber and plastics products",
  "Plastic profile shapes", "Rubber and plastics products",
  "Plastic bottles", "Rubber and plastics products",
  "Motor vehicle plastic parts", "Rubber and plastics products",
  "Tires", "Rubber and plastics products",
  "Waste and scrap of plastic and rubber", "Rubber and plastics products",
  
  # --- Other Non-Metallic Mineral Products ---
  "Non-metallic mineral products, n.e.c.", "Other non-metallic mineral products",
  "Glass (including automotive), glass products and glass containers", "Other non-metallic mineral products",
  "Lime and gypsum products", "Other non-metallic mineral products",
  "Clay and ceramic products and refractories", "Other non-metallic mineral products",
  "Cement", "Other non-metallic mineral products",
  "Ready-mixed concrete", "Other non-metallic mineral products",
  "Concrete products", "Other non-metallic mineral products",
  "Waste and scrap of glass", "Other non-metallic mineral products",
  
  # --- Basic Metals ---
  "Basic and semi-finished products of non-ferrous metals and alloys (except aluminum)", "Basic metals",
  "Waste and scrap of non-ferrous metals", "Basic metals",
  "Iron and steel basic shapes and ferro-alloy products", "Basic metals",
  "Wire and other rolled and drawn steel products", "Basic metals",
  "Waste and scrap of iron and steel", "Basic metals",
  "Ferrous metal castings", "Basic metals",
  "Bauxite and aluminum oxide", "Basic metals",
  "Unwrought aluminum including alloys", "Basic metals",
  "Basic and semi-finished products of aluminum and alloys", "Basic metals",
  "Other unwrought non-ferrous metals including alloys", "Basic metals",
  "Non-ferrous metal castings", "Basic metals",
  "Unwrought copper including alloys", "Basic metals",
  "Unwrought nickel including alloys", "Basic metals",
  "Unwrought precious metals including alloys", "Basic metals",
  
  # --- Fabricated Metals ---
  "Boilers, tanks and heavy gauge metal containers", "Fabricated metal products",
  "Springs and wire products", "Fabricated metal products",
  "Hand tools, kitchen utensils and cutlery (except precious metal)", "Fabricated metal products",
  "Metal valves and pipe fittings", "Fabricated metal products",
  "Threaded metal fasteners and other turned metal products including automotive", "Fabricated metal products",
  "Fabricated metal products, n.e.c.", "Fabricated metal products",
  "Prefabricated metal buildings and components", "Fabricated metal products",
  "Fabricated steel plates and other fabricated structural metal", "Fabricated metal products",
  "Iron and steel pipes and tubes (except castings)", "Fabricated metal products",
  "Metal windows and doors", "Fabricated metal products",
  "Other architectural metal products", "Fabricated metal products",
  "Builders, motor vehicle and other hardware", "Fabricated metal products",
  "Light gauge metal containers, crowns and closures", "Fabricated metal products",
  "Forged and stamped metal products", "Fabricated metal products",
  "Coating, engraving, heat treating and similar metal processing services", "Fabricated metal products",
  "Guns, ammunition and other munitions", "Fabricated metal products",
  
  # --- Machinery & Equipment ---
  "Logging, mining and construction machinery and equipment", "Machinery and equipment, nec",
  "Other industry-specific machinery", "Machinery and equipment, nec",
  "Pumps and compressors (except fluid power)", "Machinery and equipment, nec",
  "Other miscellaneous general-purpose machinery", "Machinery and equipment, nec",
  "Commercial and service industry machinery", "Machinery and equipment, nec",
  "Material handling equipment", "Machinery and equipment, nec",
  "Industrial and commercial fans, blowers and air purification equipment", "Machinery and equipment, nec",
  "Metalworking machinery and industrial moulds", "Machinery and equipment, nec",
  "Agricultural, lawn and garden machinery and equipment", "Machinery and equipment, nec",
  "Ball and roller bearings", "Machinery and equipment, nec",
  "Heating and cooling equipment (except household refrigerators and freezers)", "Machinery and equipment, nec",
  "Other engine and power transmission equipment", "Machinery and equipment, nec",
  "Turbines, turbine generators, and turbine generator sets", "Machinery and equipment, nec",
  
  # --- Computer & Electronic Equipment ---
  "Computers, computer peripherals and parts", "Computer, electronic and optical equipment",
  "Other communications equipment", "Computer, electronic and optical equipment",
  "Measuring, control and scientific instruments", "Computer, electronic and optical equipment",
  "Printed and integrated circuits, semiconductors and printed circuit assemblies", "Computer, electronic and optical equipment",
  "Other electronic components", "Computer, electronic and optical equipment",
  "Navigational and guidance instruments", "Computer, electronic and optical equipment",
  "Telephone apparatus", "Computer, electronic and optical equipment",
  "Audio and video equipment and unrecorded media", "Computer, electronic and optical equipment",
  
  # --- Electrical Equipment ---
  "Electric motors and generators", "Electrical equipment",
  "Switchgear, switchboards, relays and industrial control apparatus", "Electrical equipment",
  "Power, distribution and other transformers", "Electrical equipment",
  "Communication and electric wire and cable", "Electrical equipment",
  "Other electrical equipment and components", "Electrical equipment",
  "Wiring devices", "Electrical equipment",
  "Lighting fixtures", "Electrical equipment",
  "Small electric appliances", "Electrical equipment",
  "Major appliances", "Electrical equipment",
  "Electric light bulbs and tubes", "Electrical equipment",
  "Batteries", "Electrical equipment",
  
  # --- Motor Vehicles ---
  "Other miscellaneous motor vehicle parts", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle interior trim, seats and seat parts", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle metal stamping", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle steering and suspension components", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle gasoline engines and engine parts", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle electrical and electronic equipment and instruments", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle brakes and brake systems", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle transmission and power train parts", "Motor vehicles, trailers and semi-trailers",
  "Freight and utility trailers", "Motor vehicles, trailers and semi-trailers",
  "Motor vehicle bodies and special purpose motor vehicles", "Motor vehicles, trailers and semi-trailers",
  "Motor homes, travel trailers and camping trailers", "Motor vehicles, trailers and semi-trailers",
  "Passenger cars", "Motor vehicles, trailers and semi-trailers",
  "Light-duty trucks, vans and sport utility vehicles (SUVs)", "Motor vehicles, trailers and semi-trailers",
  "Medium and heavy-duty trucks and chassis", "Motor vehicles, trailers and semi-trailers",
  "Buses", "Motor vehicles, trailers and semi-trailers",
  
  # --- Other Transport Equipment ---
  "Locomotives, railway rolling stock, and rapid transit equipment", "Other transport equipment",
  "Parts of railway rolling stock", "Other transport equipment",
  "Ships", "Other transport equipment",
  "Aircraft", "Other transport equipment",
  "Aircraft parts and other aerospace equipment", "Other transport equipment",
  "Other transportation equipment and related parts", "Other transport equipment",
  "Aircraft engines", "Other transport equipment",
  "Boats and personal watercraft", "Other transport equipment",
  "Aircraft maintenance and repair services", "Other transport equipment",
  
  # --- Other Manufacturing & Repair ---
  "Other miscellaneous manufactured products", "Manufacturing nec; repair and installation of machinery and equipment",
  "Custom work manufacturing services (except printing, finishing textiles and metals)", "Manufacturing nec; repair and installation of machinery and equipment",
  "Mattresses and foundations", "Manufacturing nec; repair and installation of machinery and equipment",
  "Jewellery and silverware", "Manufacturing nec; repair and installation of machinery and equipment",
  "Sporting and athletic goods", "Manufacturing nec; repair and installation of machinery and equipment",
  "Signs", "Manufacturing nec; repair and installation of machinery and equipment",
  "Medical, dental and personal safety supplies, instruments and equipment", "Manufacturing nec; repair and installation of machinery and equipment",
  "Household furniture", "Manufacturing nec; repair and installation of machinery and equipment",
  "Institutional and other furniture, n.e.c.", "Manufacturing nec; repair and installation of machinery and equipment",
  "Office furniture", "Manufacturing nec; repair and installation of machinery and equipment",
  "Office and store fixtures", "Manufacturing nec; repair and installation of machinery and equipment",
  "Office supplies (except paper)", "Manufacturing nec; repair and installation of machinery and equipment",
  "Blinds and shades", "Manufacturing nec; repair and installation of machinery and equipment",
  "Toys and games", "Manufacturing nec; repair and installation of machinery and equipment",
  "Repair and maintenance services (except for buildings and motor vehicles)", "Manufacturing nec; repair and installation of machinery and equipment",
  "Medical devices", "Manufacturing nec; repair and installation of machinery and equipment",
  
  # --- Wholesale & Retail Trade ---
  "Wholesale margins - miscellaneous products", "Wholesale and retail trade; repair of motor vehicles",
  "Wholesale margins - food, beverages and tobacco products", "Wholesale and retail trade; repair of motor vehicles",
  "Wholesale trade commissions", "Wholesale and retail trade; repair of motor vehicles",
  "Wholesale margins - personal and household goods", "Wholesale and retail trade; repair of motor vehicles",
  "Wholesale margins - building materials and supplies", "Wholesale and retail trade; repair of motor vehicles",
  "Wholesale margins - petroleum and petroleum products", "Wholesale and retail trade; repair of motor vehicles",
  "Wholesale margins - motor vehicles, motor vehicle parts and accessories", "Wholesale and retail trade; repair of motor vehicles",
  "Wholesale margins - machinery, equipment and supplies", "Wholesale and retail trade; repair of motor vehicles",
  "Wholesale margins - farm products", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins - miscellaneous products (except cannabis)", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins - household fuels", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins - health and personal care products", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins - motor vehicles and parts", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins - electronics and appliances", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins - building materials, garden equipment and supplies", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins - food and beverages", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins - automotive fuels", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins - clothing and clothing accessories", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins - sporting and leisure products", "Wholesale and retail trade; repair of motor vehicles",
  "Retail trade commissions", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins - furniture and home furnishings", "Wholesale and retail trade; repair of motor vehicles",
  "Retail margins - cannabis products (unlicensed)", "Wholesale and retail trade; repair of motor vehicles",
  "Motor vehicle repair and maintenance services", "Wholesale and retail trade; repair of motor vehicles",
  
  # --- Transportation & Warehousing ---
  "Truck transportation services for specialized freight", "Transportation and related services",
  "Truck transportation services for general freight", "Transportation and related services",
  "Air specialty services", "Transportation and related services",
  "Air passenger transportation services", "Transportation and related services",
  "Air freight transportation services", "Transportation and related services",
  "Air transportation support services", "Transportation and related services",
  "Rail passenger transportation services", "Transportation and related services",
  "Rail freight transportation services", "Transportation and related services",
  "Rail transportation support, maintenance and repair services", "Transportation and related services",
  "Water passenger transportation services", "Transportation and related services",
  "Water freight transportation services", "Transportation and related services",
  "Water transportation support, maintenance and repair services", "Transportation and related services",
  "Road transportation support services", "Transportation and related services",
  "Urban transit services", "Transportation and related services",
  "Interurban and rural bus passenger transportation services", "Transportation and related services",
  "School bus services", "Transportation and related services",
  "Other transit and passenger transportation services by road", "Transportation and related services",
  "Scenic and sightseeing tour services", "Transportation and related services",
  "Parking services", "Transportation and related services",
  "Taxi and limousine services", "Transportation and related services",
  "Transportation of crude oil and other commodities by pipeline", "Transportation and related services",
  "Transportation of natural gas by pipeline", "Transportation and related services",
  "Freight transportation arrangement and customs brokering services", "Transportation and related services",
  "Other transportation support services", "Transportation and related services",
  "Postal services", "Transportation and related services",
  "Courier, parcel, and local messenger and delivery services", "Transportation and related services",
  "Grain storage", "Transportation and related services",
  "Warehousing and storage services (except grain storage)", "Transportation and related services",
  "Moving services", "Transportation and related services",
  
  # --- Information & Broadcasting ---
  "General purpose software", "Publishing, audiovisual and broadcasting activities",
  "Recorded movies, television programs and videos", "Publishing, audiovisual and broadcasting activities",
  "Recorded music and other sound recordings", "Publishing, audiovisual and broadcasting activities",
  "Advertising space in printed newspapers", "Publishing, audiovisual and broadcasting activities",
  "Advertising space in printed periodicals and in other printed publications", "Publishing, audiovisual and broadcasting activities",
  "Licensing of rights to use literary works and artistic works (except software licensing)", "Publishing, audiovisual and broadcasting activities",
  "Subscriptions for online content", "Publishing, audiovisual and broadcasting activities",
  "Internet advertising", "Publishing, audiovisual and broadcasting activities",
  "Movie, television program and video production, post-production and editing services", "Publishing, audiovisual and broadcasting activities",
  "Licensing of rights to use audiovisual works", "Publishing, audiovisual and broadcasting activities",
  "Audio recording services and copyright administration", "Publishing, audiovisual and broadcasting activities",
  "Licensing of rights to use musical works and sound recordings", "Publishing, audiovisual and broadcasting activities",
  "Advertising air time on radio", "Publishing, audiovisual and broadcasting activities",
  "Advertising air time on television", "Publishing, audiovisual and broadcasting activities",
  "Broadcast and other media rights", "Publishing, audiovisual and broadcasting activities",
  "Other information services", "Publishing, audiovisual and broadcasting activities",
  
  # --- Telecommunications ---
  "Cable, satellite and other program distribution services", "Telecommunications",
  "Fees for the distribution of television and radio program channels (affiliation payments)", "Telecommunications",
  "Fixed telecommunications services (except Internet access)", "Telecommunications",
  "Mobile telecommunications services", "Telecommunications",
  "Fixed Internet access services", "Telecommunications",
  
  # --- IT Services ---
  "Own-account software design and development services", "IT and other information services",
  "Data processing, hosting, and related services", "IT and other information services",
  "Custom software design and development services", "IT and other information services",
  "Computer systems design and related services (except software development)", "IT and other information services",
  
  # --- Finance & Insurance ---
  "Central banking services", "Financial and insurance activities",
  "Banking and other depository credit intermediation services - explicit charges", "Financial and insurance activities",
  "Non-depository credit intermediation services - explicit charges (fees)", "Financial and insurance activities",
  "Investment banking services", "Financial and insurance activities",
  "Security brokerage and securities dealing services", "Financial and insurance activities",
  "Portfolio management services", "Financial and insurance activities",
  "Deposit intermediation services indirectly measured (FISIM)", "Financial and insurance activities",
  "Residential mortgage intermediation services indirectly measured (FISIM)", "Financial and insurance activities",
  "Other loan intermediation services indirectly measured (FISIM)", "Financial and insurance activities",
  "Local credit union services - explicit charges (fees)", "Financial and insurance activities",
  "Other services related to credit intermediation", "Financial and insurance activities",
  "Investment counselling services", "Financial and insurance activities",
  "Holding company services and other financial investment and related activities", "Financial and insurance activities",
  "Trusteed pension fund services", "Financial and insurance activities",
  "Mutual funds (cost of service) and other similar services", "Financial and insurance activities",
  "Life insurance services", "Financial and insurance activities",
  "Accident and sickness insurance services", "Financial and insurance activities",
  "Automotive insurance services", "Financial and insurance activities",
  "Property insurance services", "Financial and insurance activities",
  "Liability and other property and casualty insurance services", "Financial and insurance activities",
  "Brokerage and other insurance related services", "Financial and insurance activities",
  "Motor vehicle rental and leasing services", "Financial and insurance activities",
  "Computer equipment rental and leasing services", "Financial and insurance activities",
  "Office machinery and equipment (except computer equipment) rental and leasing services", "Financial and insurance activities",
  "Commercial and industrial machinery and equipment (except office equipment) rental and leasing services", "Financial and insurance activities",
  "Rental and leasing services of other goods", "Financial and insurance activities",
  
  # --- Real Estate ---
  "Rental of non-residential real estate", "Real estate activities",
  "Rental of residential real estate", "Real estate activities",
  "Real estate brokerage and other services related to real estate", "Real estate activities",
  "Imputed rental of owner-occupied dwellings", "Real estate activities",
  
  # --- Professional, Scientific, Technical ---
  "Own-account research and development (except software development)", "Professional, scientific and technical activities",
  "Management, scientific and technical consulting services", "Professional, scientific and technical activities",
  "Advertising, public relations and related services", "Professional, scientific and technical activities",
  "Architectural, engineering and related services", "Professional, scientific and technical activities",
  "Legal services", "Professional, scientific and technical activities",
  "Research and development services", "Professional, scientific and technical activities",
  "Specialized design services", "Professional, scientific and technical activities",
  "Other professional, scientific and technical services", "Professional, scientific and technical activities",
  "Accounting, tax preparation, bookkeeping and payroll services", "Professional, scientific and technical activities",
  "Photographic services", "Professional, scientific and technical activities",
  "Veterinary services", "Professional, scientific and technical activities",
  
  # --- Administrative & Support Services ---
  "Head office services (imputed)", "Administrative and support services",
  "Office administrative services", "Administrative and support services",
  "Business support services", "Administrative and support services",
  "Holding company services (imputed)", "Administrative and support services",
  "Employment services", "Administrative and support services",
  "Travel arrangement, reservation and planning services", "Administrative and support services",
  "Investigation and security services", "Administrative and support services",
  "Services to buildings and dwellings", "Administrative and support services",
  "Waste management and remediation services", "Administrative and support services",
  "Facilities and other support services", "Administrative and support services",
  "Licensing of rights to non-financial produced intangible assets (except software and other copyright licensing)", "Administrative and support services",
  
  # --- Education ---
  "Tuition and similar fees for trade, technical and professional training", "Education",
  "Other educational training and services", "Education",
  "Tuition and similar fees for elementary and secondary schools", "Education",
  "Tuition and similar fees for colleges and C.E.G.E.P.s", "Education",
  "Tuition and similar fees for universities", "Education",
  "Elementary and secondary school services provided by governments", "Education",
  "Community college and C.E.G.E.P services provided by governments", "Education",
  "University services provided by governments", "Education",
  "Other educational services provided by governments", "Education",
  "Educational services provided by Non-Profit Institutions Serving Households", "Education",
  
  # --- Health & Social Work ---
  "Medical laboratory diagnostic and testing services", "Human health and social work activities",
  "Ambulance services", "Human health and social work activities",
  "Nursing and residential care services", "Human health and social work activities",
  "Child day-care services", "Human health and social work activities",
  "Other ambulatory health care services and social assistance services", "Human health and social work activities",
  "Physician services", "Human health and social work activities",
  "Dental services", "Human health and social work activities",
  "Other health practitioner services", "Human health and social work activities",
  "Babysitting services", "Human health and social work activities",
  "Hospital services", "Human health and social work activities",
  "Hospital services provided by governments", "Human health and social work activities",
  "Residential care facility services provided by governments", "Human health and social work activities",
  "Ambulatory health care services provided by Non-Profit Institutions Serving Households", "Human health and social work activities",
  "Social assistance services provided by Non-Profit Institutions Serving Households", "Human health and social work activities",
  
  # --- Arts, Entertainment & Recreation ---
  "Admissions to motion picture film exhibitions", "Arts, entertainment and recreation",
  "Amusement and recreation services", "Arts, entertainment and recreation",
  "Admissions to live performing arts performances", "Arts, entertainment and recreation",
  "Career management and representation services of public figures", "Arts, entertainment and recreation",
  "Contract production of live performing arts performances, live sporting events and copyrighted works", "Arts, entertainment and recreation",
  "Admissions to live sporting events", "Arts, entertainment and recreation",
  "Sport and performing arts event organization and support services", "Arts, entertainment and recreation",
  "Heritage institution services", "Arts, entertainment and recreation",
  "Gambling (net wagers)", "Arts, entertainment and recreation",
  "Recreational vehicle park and recreational camp services", "Arts, entertainment and recreation",
  "Arts, entertainment and recreation services provided by Non-Profit Institutions Serving Households", "Arts, entertainment and recreation",
  
  # --- Accommodation & Food Services ---
  "Rooming and boarding services", "Accommodation and food service activities",
  "Room or unit accommodation services for travellers", "Accommodation and food service activities",
  
  # --- Other Services ---
  "Other personal and personal care services", "Other service activities",
  "Laundry and dry-cleaning services", "Other service activities",
  "Hair care and aesthetic services", "Other service activities",
  "Funeral services", "Other service activities",
  "Other membership services", "Other service activities",
  "Private household services (except babysitting)", "Other service activities",
  "Gold, store of value", "Other service activities",
  "Used motor vehicles", "Other service activities",
  "Other used consumer goods", "Other service activities",
  
  # --- Public Administration ---
  "Religious services", "Public administration and defence; compulsory social security",
  "Grant-making, civic, and professional and similar organization services", "Public administration and defence; compulsory social security",
  "Labour organization membership services", "Public administration and defence; compulsory social security",
  "Political organization services", "Public administration and defence; compulsory social security",
  "Other services provided by Non-Profit Institutions Serving Households", "Public administration and defence; compulsory social security",
  "Defence services", "Public administration and defence; compulsory social security",
  "Other federal government services", "Public administration and defence; compulsory social security",
  "Other provincial and territorial government services", "Public administration and defence; compulsory social security",
  "Other municipal government services", "Public administration and defence; compulsory social security",
  "Other aboriginal government services", "Public administration and defence; compulsory social security",
  "Sales of other services by Non-Profit Institutions Serving Households", "Public administration and defence; compulsory social security",
  "Sales of other government services", "Public administration and defence; compulsory social security",
  
  # --- Items to Exclude (Not Products) ---
  "All products", NA,
  "Subsidies on products", NA,
  "Gross value-added at basic prices", NA,
  "Subsidies on production", NA,
  "Taxes on production", NA,
  "Wages and salaries", NA,
  "Employers' social contributions", NA,
  "Gross mixed income", NA,
  "Gross operating surplus", NA,
  "Taxes on products", NA
)

ind_map <- tribble(
  ~oecd_code, ~paper_sector,
  "01T02", "Agriculture, hunting, forestry, fishing and aquaculture",
  "03", "Agriculture, hunting, forestry, fishing and aquaculture",
  "05T06", "Mining and quarrying, energy producing products",
  "07T08", "Mining and quarrying, non-energy producing products",
  "09", "Mining support service activities",
  "10T12", "Food products, beverages and tobacco",
  "13T15", "Textiles, textile products, leather and footwear",
  "16", "Wood and products of wood and cork",
  "17T18", "Paper products and printing",
  "19", "Coke and refined petroleum products",
  "20", "Chemical and pharmaceutical products",
  "21", "Chemical and pharmaceutical products",
  "22", "Rubber and plastics products",
  "23", "Other non-metallic mineral products",
  "24", "Basic metals",
  "25", "Fabricated metal products",
  "26", "Computer, electronic and optical equipment",
  "27", "Electrical equipment",
  "28", "Machinery and equipment, nec",
  "29", "Motor vehicles, trailers and semi-trailers",
  "30", "Other transport equipment",
  "31T33", "Manufacturing nec; repair and installation of machinery and equipment",
  "35", "Utilities",
  "36T39", "Utilities",
  "41T43", "Construction",
  "45T47", "Wholesale and retail trade; repair of motor vehicles",
  "49", "Transportation and related services",
  "50", "Transportation and related services",
  "51", "Transportation and related services",
  "52", "Transportation and related services",
  "53", "Transportation and related services",
  "55T56", "Accommodation and food service activities",
  "58T60", "Publishing, audiovisual and broadcasting activities",
  "61", "Telecommunications",
  "62T63", "IT and other information services",
  "64T66", "Financial and insurance activities",
  "68", "Real estate activities",
  "69T75", "Professional, scientific and technical activities",
  "77T82", "Administrative and support services",
  "84", "Public administration and defence; compulsory social security",
  "85", "Education",
  "86T88", "Human health and social work activities",
  "90T93", "Arts, entertainment and recreation",
  "94T96", "Other service activities",
  "97T98", "Other service activities"
)

SECTORS <- unique(sut_product_to_sector_map$sector)

# Calculate World VA Shares for CAN, USA, ROW from ICIO data ---
fx <- fread("FXUSDCAD.csv")
fx[, date := as.IDate(date, format = "%m/%d/%Y")]
fx[, year := year(date)]

fx_rate_2015 <- fx[year == 2015,
                   .(cad_per_usd = mean(value, na.rm = TRUE)),
                   by = year] %>%
  pull(cad_per_usd)

vadd_cad <- VA_2015 * fx_rate_2015

oecd_country_codes <- substr(names(vadd_cad), 1, 3)

oecd_region_map <- case_when(
  oecd_country_codes == "CAN" ~ "CAN",
  oecd_country_codes == "USA" ~ "USA",
  TRUE                        ~ "ROW"
)

cou_map <- data.frame(
  country = unique(oecd_country_codes),
  stringsAsFactors = FALSE
) %>%
  mutate(region = case_when(
    country == "CAN" ~ "CAN",
    country == "USA" ~ "USA",
    TRUE ~ "ROW"
  ))

# --- Load Provincial and Trade Data ---
shares_dist <- read_csv("2019_replication_full_data.csv")

# --- Load 2015 Provincial SUT Data ---
clean_sut_names <- function(names_vector) { gsub("\\s*\\[.*\\]$", "", names_vector) }

sut_folder <- "15-602-x_csv-scsv_2015_eng/"
sut_supply_raw <- read_csv(paste0(sut_folder, "SUT_C2015_S.csv"), show_col_types = FALSE) %>%
  mutate(Industry = clean_sut_names(Industry), Product = clean_sut_names(Product),
         VALUE = ifelse(SCALAR_FACTOR == "millions", VALUE, VALUE * 1e3))

sut_use_raw <- read_csv(paste0(sut_folder, "SUT_C2015_D.csv"), show_col_types = FALSE) %>%
  mutate(Industry = clean_sut_names(Industry), Product = clean_sut_names(Product),
         VALUE = ifelse(SCALAR_FACTOR == "millions", VALUE, VALUE * 1e3))

# ===================================================================================
# SECTION 2: MODEL PARAMETER CONSTRUCTION (2015 DATA)
# ===================================================================================
# This script constructs all required model parameters for the target year 2015
# using the 2015 Canadian provincial SUTs and 2015 OECD ICIO global tables.
# ===================================================================================

## 2.1 Omega (ω): Regional Income Shares
# ===================================================================================

# Aggregate the CAD value added by region
world_va_cad <- data.frame(region = oecd_region_map, va = vadd_cad) %>%
  group_by(region) %>%
  summarise(total_va_cad = sum(va, na.rm = TRUE)) %>%
  mutate(world_share = total_va_cad / sum(total_va_cad))

# --- c) Calculate Provincial Shares within Canada ---
# This assumes `gdp_data` and `spatial_price_data` for 2015 have been loaded.
omega_data <- gdp_data %>%
  left_join(spatial_price_data, by = "Province") %>%
  mutate(RealGDP = gdp_value / (price_index / 100)) %>%
  mutate(omega_can_share = RealGDP / sum(RealGDP)) %>%
  select(Province, omega_can_share)

# --- d) Combine for final omega_vec ---
can_world_share <- world_va_cad$world_share[world_va_cad$region == "CAN"]
usa_world_share <- world_va_cad$world_share[world_va_cad$region == "USA"]
row_world_share <- world_va_cad$world_share[world_va_cad$region == "ROW"]

# Calculate each province's share of the world total
prov_world_shares <- setNames(
  omega_data$omega_can_share * can_world_share,
  omega_data$Province
)

# Combine into the final vector
omega_full_vec <- c(prov_world_shares, "USA" = usa_world_share, "ROW" = row_world_share)

# Ensure the final vector is ordered correctly according to the REGIONS constant
omega_full_vec <- omega_full_vec[REGIONS]
omega_full_vec[is.na(omega_full_vec)] <- 0 # Set any missing regions (e.g., if a territory has no GDP data) to 0

# --- 2.2 Gamma (γ): Input-Output Matrix ---
# The matrix of intermediate input shares. The element gamma[k, j] is the
# share of user j's inputs that come from provider k.
# --- a) Define the Aggregation Map ---
# This maps each of the 3420 OECD country-industry rows/columns to a model sector.
oecd_industry_codes <- substr(colnames(Z_2015), 5, 9)
oecd_sector_map <- ind_map$paper_sector[match(oecd_industry_codes, ind_map$oecd_code)]

# --- b) Aggregate the Global Z-Matrix ---
# This is a two-step process: first aggregate the rows (providers), then the columns (users).

# Step 1: Aggregate the 3,420 rows (providers) into model's sectors.
# The result is a [number_of_sectors x 3420] matrix.
Z_agg_rows <- rowsum(Z_2015, group = oecd_sector_map, reorder = TRUE, na.rm = TRUE)

# Step 2: Aggregate the 3,420 columns (users) into model's sectors.
# We transpose, aggregate the new rows, and transpose back.
Z_agg_final <- t(rowsum(t(Z_agg_rows), group = oecd_sector_map, reorder = TRUE, na.rm = TRUE))

# --- c) Normalize to get the Final Gamma Matrix ---
# Ensure the matrix is complete and ordered correctly before normalizing.
gamma_matrix_unaligned <- Z_agg_final
gamma_matrix <- matrix(0, nrow=length(SECTORS), ncol=length(SECTORS), dimnames=list(SECTORS, SECTORS))
common_dims <- intersect(rownames(gamma_matrix_unaligned), SECTORS)
gamma_matrix[common_dims, common_dims] <- gamma_matrix_unaligned[common_dims, common_dims]

# Normalize by column sum to get the technical coefficients
gamma_matrix <- sweep(gamma_matrix, 2, colSums(gamma_matrix, na.rm = TRUE), FUN = "/")
gamma_matrix[is.na(gamma_matrix)] <- 0

# --- 2.3 Phi (φ): Value-Added Share Matrix [region, sector] ---
# Calculate Total Output and Value Added
OUTPUT_vec <- X_2015
OUTPUT_matrix <- matrix(OUTPUT_vec, ncol = 1, dimnames = list(names(OUTPUT_vec), "OUTPUT"))

output_map <- ind_map$paper_sector[match(substr(names(OUTPUT_vec), 5, 9), ind_map$oecd_code)]

OUTPUT_agg <- rowsum(OUTPUT_matrix, group = output_map, reorder = TRUE, na.rm = TRUE)

VADD_vec <- VA_2015
VADD_matrix <- matrix(VADD_vec, ncol = 1, dimnames = list(names(VADD_vec), "VADD"))

VADD_agg <- rowsum(VADD_matrix, group = output_map, reorder = TRUE, na.rm = TRUE)


# Create the final phi_matrix by broadcasting the sector ratios across all regions
phi_j_ratios <- VADD_agg / OUTPUT_agg

phi_j_ordered <- phi_j_ratios[SECTORS, 1]

# Replicate the vector of ratios for each region to build the matrix
phi_matrix <- matrix(
  data = phi_j_ordered,
  nrow = length(REGIONS),
  ncol = length(SECTORS),
  byrow = TRUE, # Replicate the row vector for each region
  dimnames = list(REGIONS, SECTORS)
)

phi_matrix[is.na(phi_matrix) | is.infinite(phi_matrix)] <- 0

# --- 2.4 Beta (β): Final Demand Share Matrix (Direct Measurement Version) ---

# a) Define patterns to identify all final demand categories using grepl.
# This is more robust than listing every single unique category name.
final_demand_patterns <- c(
  "final consumption expenditure",
  "Gross fixed capital formation",
  "Changes in inventories",
  "^Construction,", # Captures GFCF in construction
  "^Machinery and equipment,", # Captures GFCF in M&E
  "^Intellectual property products," # Captures GFCF in IPP
)

# Combine patterns into a single regex string with OR operators `|`
search_pattern <- paste(final_demand_patterns, collapse = "|")

# b) Calculate provincial final demand levels by sector from the SUT Use table
prov_fd_levels <- sut_use_raw %>%
  # Filter for rows where the 'Industry' column matches one of our patterns
  filter(
    Valuation == "Basic price",
    grepl(search_pattern, Industry), 
    GEO %in% provincesplus) %>%
  # Map the detailed SUT products to your model's sectors
  left_join(sut_product_to_sector_map_use, by = c("Product" = "sut_product")) %>%
  filter(!is.na(sector)) %>%
  # Sum the values to get total final demand for each sector in each province
  group_by(origin = GEO, sector) %>%
  summarise(fd_value = sum(VALUE, na.rm = TRUE), .groups = "drop") %>%
  # Recode province names to your two-letter abbreviations
  mutate(origin = recode(origin, !!!setNames(provsplus, provincesplus)))

# c) Normalize to get provincial expenditure shares (the provincial part of beta)
prov_beta_shares <- prov_fd_levels %>%
  group_by(origin) %>%
  mutate(share = fd_value / sum(fd_value, na.rm = TRUE)) %>%
  ungroup()

# d) Reshape into a wide matrix [sectors x provinces]
prov_beta_matrix <- prov_beta_shares %>%
  select(origin, sector, share) %>%
  pivot_wider(
    names_from = origin,
    values_from = share,
    values_fill = 0
  ) %>%
  column_to_rownames("sector") %>%
  as.matrix()

# e) Create and populate the final, complete beta_matrix (Same as before)
beta_matrix <- matrix(0, nrow = length(SECTORS), ncol = length(REGIONS), 
                      dimnames = list(SECTORS, REGIONS))

# Use intersect() for a robust assignment of the provincial data
common_rows <- intersect(rownames(beta_matrix), rownames(prov_beta_matrix))
common_cols <- intersect(colnames(beta_matrix), colnames(prov_beta_matrix))
beta_matrix[common_rows, common_cols] <- prov_beta_matrix[common_rows, common_cols]

# f) Populate USA & ROW shares from the aggregated OECD data (same as before)
# Create the region map for the 81 columns
# This is the key fix for your error
oecd_country_codes <- dimnames(ICIO2023econFD)[[3]]

oecd_region_map <- case_when(
  oecd_country_codes == "CAN" ~ "CAN",
  oecd_country_codes == "USA" ~ "USA",
  TRUE                      ~ "ROW"
)

# --- Step 2: Perform the aggregation ---

# Extract the final demand matrix for a single year (e.g., 2015, which is the 21st year)
FD_2015 <- ICIO2023econFD[21, , ]

# Aggregate rows by providing sector (this should work now)
fd_agg_by_provider <- rowsum(FD_2015, group = oecd_sector_map, reorder = TRUE, na.rm = TRUE)

# Aggregate columns by destination region (this is the step that previously failed)
# It will now work because oecd_region_map has the correct length (81)
fd_agg_final <- t(rowsum(t(fd_agg_by_provider), group = oecd_region_map, reorder = TRUE, na.rm = TRUE))

# Clean up any potential NA values that result from removing Canada
fd_agg_final[is.na(fd_agg_final)] <- 0

beta_shares_agg <- sweep(fd_agg_final, 2, colSums(fd_agg_final, na.rm = TRUE), FUN = "/")
beta_matrix[, "USA"] <- beta_shares_agg[SECTORS, "USA"]
beta_matrix[, "ROW"] <- beta_shares_agg[SECTORS, "ROW"]

# Final cleanup 
beta_matrix[beta_matrix < 0] <- 0
beta_matrix <- sweep(beta_matrix, 2, colSums(beta_matrix, na.rm = TRUE), FUN = "/")
beta_matrix[is.na(beta_matrix)] <- 0

## 2.5 Pi (π): Trade Share Array (Simplified and Corrected)
# ===================================================================================

# Initialize the 3D array
pi_array <- array(0, dim = c(length(REGIONS), length(REGIONS), length(SECTORS)),
                  dimnames = list(dest = REGIONS, origin = REGIONS, sector = SECTORS))

# --- Step 1: Calculate all expenditure shares from your complete trade flow data ---
pi_shares <- shares_dist %>%
  filter(year == TARGET_YEAR) %>%
  # For each destination and sector, calculate the share of spending for each origin
  group_by(dest, sector) %>%
  mutate(share = value / sum(value, na.rm = TRUE)) %>%
  ungroup() %>%
  # Ensure we only use regions and sectors defined in the model
  filter(dest %in% REGIONS, origin %in% REGIONS, sector %in% SECTORS)

# --- Step 2: Fill the entire pi_array from these shares ---
# This correctly populates all off-diagonal (trade) and diagonal (home) shares.
for (i in 1:nrow(pi_shares)) {
  row <- pi_shares[i, ]
  # Check to prevent errors if a value is somehow NA
  if (!is.na(row$share)) {
    pi_array[row$dest, row$origin, row$sector] <- row$share
  }
}

# --- Step 3: Final Normalization (optional but good practice) ---
# This ensures all destination-sector slices sum exactly to 1, correcting for any minor rounding errors.
for (d in REGIONS) {
  for (s in SECTORS) {
    total <- sum(pi_array[d, , s], na.rm = TRUE)
    if (total > 0) {
      pi_array[d, , s] <- pi_array[d, , s] / total
    } else {
      # If a region has no expenditure in a sector, set its home share to 1.
      # This prevents NaNs and assumes it is self-sufficient in products it doesn't trade.
      pi_array[d, d, s] <- 1
    }
  }
}

pi_array[is.na(pi_array)] <- 0 # Final cleanup

# --- 2.6 Theta (θ) Vector ---
theta_vec <- setNames(theta_data$theta, theta_data$sector)[SECTORS]

# ===================================================================================
# 3. MODEL SOLVER AND HELPER FUNCTIONS (FINAL REVISION)
# ===================================================================================

# --- 3.1 The Model Solver ---
solve_model_matrix <- function(tau_hat_array, pi_array, gamma_matrix, phi_matrix, 
                               theta_vec, beta_matrix, omega_vec, experiment_name,
                               migration_elasticity = 0, # NEW: Set to > 0 to enable migration
                               max_iter = 5000, tolerance = 1e-9) {
  
  region_names <- dimnames(pi_array)[[1]]
  sector_names <- dimnames(pi_array)[[3]]
  num_regions <- length(region_names)
  num_sectors <- length(sector_names)
  
  # Identify Canadian provinces for the migration calculation
  canadian_provinces <- region_names[region_names %in% provsplus]
  
  # Initialize variables
  w_hat <- rep(1, num_regions)
  names(w_hat) <- region_names
  
  # NEW: Initialize labor supply change vector (L_hat)
  L_hat <- rep(1, num_regions)
  names(L_hat) <- region_names
  
  p_hat <- matrix(1, nrow = num_regions, ncol = num_sectors, 
                  dimnames = list(region_names, sector_names))
  initial_income <- setNames(omega_vec, region_names)
  
  cat(paste("Starting solver for:", experiment_name, 
            "| Migration Elasticity:", migration_elasticity, "\n"))
  
  for (iter in 1:max_iter) {
    w_hat_old <- w_hat
    
    # --- Inner loop to find p_hat for given w_hat and L_hat ---
    for (p_iter in 1:100) {
      p_hat_old_inner <- p_hat
      
      term1_log_wages <- log(w_hat) %o% rep(1, num_sectors)
      term2_log_prices_sum <- log(p_hat) %*% gamma_matrix
      term2_full <- term2_log_prices_sum * (1 - phi_matrix)
      c_hat <- exp(term1_log_wages * phi_matrix + term2_full)
      dimnames(c_hat) <- list(region_names, sector_names)
      
      p_hat_numerator_terms <- array(0, dim = dim(pi_array), dimnames = dimnames(pi_array))
      for (s in sector_names) {
        c_hat_mat_s <- matrix(c_hat[, s], nrow = num_regions, ncol = num_regions, byrow = FALSE)
        cost_shock_term <- (tau_hat_array[, , s] * t(c_hat_mat_s))^(-theta_vec[s])
        p_hat_numerator_terms[, , s] <- pi_array[, , s] * cost_shock_term
      }
      
      p_hat_sum_term <- apply(p_hat_numerator_terms, c("dest", "sector"), sum, na.rm = TRUE)
      theta_matrix <- matrix(theta_vec[sector_names], nrow = num_regions, ncol = num_sectors, byrow = TRUE)
      p_hat_new <- p_hat_sum_term^(-1 / theta_matrix)
      p_hat_new[is.infinite(p_hat_new) | is.na(p_hat_new)] <- 1
      
      if (max(abs(p_hat_new - p_hat_old_inner), na.rm = TRUE) < 1e-10) break
      p_hat <- p_hat_new
    }
    
    # --- Calculate new trade shares (pi_prime) ---
    p_hat_sum_array <- array(0, dim = dim(p_hat_numerator_terms), dimnames = dimnames(p_hat_numerator_terms))
    for (o_idx in 1:dim(p_hat_sum_array)[2]) {
      p_hat_sum_array[, o_idx, ] <- p_hat_sum_term
    }
    pi_prime <- p_hat_numerator_terms / p_hat_sum_array
    pi_prime[is.na(pi_prime)] <- 0
    
    # --- Calculate counterfactual expenditures ---
    # NEW: Counterfactual income now depends on BOTH wage changes and labor supply changes.
    I_prime <- w_hat * L_hat * initial_income
    
    Xf_prime <- I_prime * t(beta_matrix[sector_names, region_names])
    dimnames(Xf_prime) <- list(region_names, sector_names)
    
    X_prime <- Xf_prime
    for (i in 1:50) {
      R_prime_list <- vapply(sector_names, function(j) {
        t(pi_prime[, , j]) %*% X_prime[, j]
      }, FUN.VALUE = numeric(num_regions))
      R_prime <- matrix(R_prime_list, nrow = num_regions, dimnames = list(region_names, sector_names))
      R_prime[is.na(R_prime) | is.infinite(R_prime)] <- 0
      
      Xi_prime <- (R_prime * (1 - phi_matrix)) %*% t(gamma_matrix)
      dimnames(Xi_prime) <- list(region_names, sector_names)
      Xi_prime[is.na(Xi_prime) | is.infinite(Xi_prime)] <- 0
      
      X_prime_new <- Xf_prime + Xi_prime
      if (max(abs(X_prime_new - X_prime), na.rm = TRUE) < 1e-10) break
      X_prime <- X_prime_new
    }
    
    # --- NEW: Labor Supply Update ---
    if (migration_elasticity > 0) {
      # Calculate real wage change (utility change) for this iteration
      beta_ordered <- beta_matrix[dimnames(p_hat)[[2]], dimnames(p_hat)[[1]]]
      log_p_hat <- log(p_hat)
      log_p_hat[is.infinite(log_p_hat) | is.na(log_p_hat)] <- 0
      log_price_level_change <- diag(log_p_hat %*% beta_ordered)
      price_level_change <- exp(log_price_level_change)
      u_hat <- w_hat / price_level_change
      
      # Calculate national average utility change (U_hat) for Canadian provinces
      can_omega <- omega_vec[canadian_provinces]
      can_u_hat_sum <- sum((can_omega / sum(can_omega)) * u_hat[canadian_provinces]^migration_elasticity)
      U_hat_can <- can_u_hat_sum^(1 / migration_elasticity)
      
      # Update provincial labor supply (L_hat)
      L_hat[canadian_provinces] <- (u_hat[canadian_provinces] / U_hat_can)^migration_elasticity
      
      # L_hat for USA and ROW remains 1 (no migration)
      L_hat[!(names(L_hat) %in% canadian_provinces)] <- 1
    }
    
    # --- Update Wages ---
    Generated_VA_prime <- rowSums(R_prime * phi_matrix, na.rm = TRUE)
    
    # NEW: The update ratio now also includes the change in labor supply
    update_ratio <- Generated_VA_prime / (L_hat * initial_income)
    w_hat_new <- update_ratio
    w_hat_new[is.na(w_hat_new) | is.infinite(w_hat_new)] <- 1
    
    # Normalize wages using world income shares
    w_hat_new <- w_hat_new / sum(w_hat_new * L_hat * omega_vec, na.rm = TRUE)
    
    # Dampening
    w_hat <- 0.1 * w_hat_new + 0.9 * w_hat_old
    
    if (max(abs(w_hat - w_hat_old), na.rm = TRUE) < tolerance) {
      cat("Converged after", iter, "iterations.\n")
      
      # Return the final L_hat vector along with the solution
      return(list(w_hat = w_hat, p_hat = p_hat, L_hat = L_hat))
    }
  }
  
  warning("Solver did not converge after ", max_iter, " iterations.")
  return(list(w_hat = w_hat, p_hat = p_hat, L_hat = L_hat))
}

# ===================================================================================
# 4. EXPERIMENT EXECUTION
# ===================================================================================
analyze_and_display_results <- function(solution_object, experiment_name,
                                        beta_matrix, omega_vector,
                                        regions_vector, provinces_vector) {
  
  # --- 1. Calculate Core Outcome Variables ---
  
  # Calculate the change in the aggregate price level for each region
  price_level_change <- exp(diag(log(solution_object$p_hat) %*% beta_matrix[dimnames(solution_object$p_hat)[[2]], regions_vector]))
  
  # Calculate Per-Capita GDP Gain (Real Wage Change)
  gdp_gain_per_capita <- solution_object$w_hat / price_level_change
  
  # Calculate Aggregate Real GDP Change (Accounts for population change)
  gdp_gain_aggregate <- (solution_object$w_hat * solution_object$L_hat) / price_level_change
  
  # --- 2. Create the Detailed Results Table ---
  
  results_detailed <- data.frame(
    Region = regions_vector,
    `Per-Capita GDP Gain (%)` = (gdp_gain_per_capita[regions_vector] - 1) * 100,
    `Population Change (%)` = (solution_object$L_hat[regions_vector] - 1) * 100,
    `Aggregate Real GDP Change (%)` = (gdp_gain_aggregate[regions_vector] - 1) * 100,
    check.names = FALSE
  )
  
  # --- 3. Calculate the Canada-wide Aggregate Change ---
  
  agg_gdp_change_pct <- (gdp_gain_aggregate[regions_vector] - 1) * 100
  canada_gdp_change <- agg_gdp_change_pct[provinces_vector]
  canada_weights <- omega_vector[provinces_vector]
  canada_weights_normalized <- canada_weights / sum(canada_weights)
  canada_aggregate_change <- sum(canada_gdp_change * canada_weights_normalized)
  
  # --- 4. Print Formatted Output ---
  
  cat("\n-------------------------------------------------------------------\n")
  # Use knitr::kable for clean, markdown-ready tables
  print(knitr::kable(results_detailed, digits = 4, caption = experiment_name))
  cat("\nCanada Aggregate Real GDP Change (Initial GDP-weighted):", round(canada_aggregate_change, 4), "%\n")
  cat("-------------------------------------------------------------------\n")
}

# Define the migration elasticity. A value of 1.5 is 2019 paper assumption
# Set this to 0 to replicate the no-migration results.
elasticity_of_migration <- 1.5

# --- Replicate Table 5 Policy Experiments ---

# T5, Col 4: 10% Lower Internal Canadian Trade Costs
tau_t5_c4 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (d in REGIONS) {
  for (o in REGIONS) {
    if (d %in% provsplus && o %in% provsplus && d != o) {
      tau_t5_c4[d, o, ] <- 0.9
    }
  }
}

solution_t5_c4 <- solve_model_matrix(
  tau_hat_array = tau_t5_c4, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "10% Lower Internal Canadian Trade Costs",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_t5_c4,
  experiment_name = "10% Lower Internal Canadian Trade Costs",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# T5, Col 5: 10% Lower External Trade Costs (Canada-US-ROW)
tau_t5_c5 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (d in REGIONS) {
  for (o in REGIONS) {
    # External means: not both Canadian provinces
    if (!(d %in% provsplus && o %in% provsplus) && d != o) {
      tau_t5_c5[d, o, ] <- 0.9
    }
  }
}

solution_t5_c5 <- solve_model_matrix(
  tau_hat_array = tau_t5_c5, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "10% Lower External Canadian Trade Costs",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_t5_c5,
  experiment_name = "10% Lower External Canadian Trade Costs",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# --- 4.3 Replicate Table 6 Policy Experiments ---

GOODS_SECTORS <- c("Agriculture, hunting, forestry, fishing and aquaculture",              
                   "Mining and quarrying, energy producing products",               
                   "Mining and quarrying, non-energy producing products",              
                   "Food products, beverages and tobacco",             
                   "Textiles, textile products, leather and footwear",            
                   "Wood and products of wood and cork",           
                   "Paper products and printing",          
                   "Coke and refined petroleum products",         
                   "Chemical and pharmaceutical products",        
                   "Rubber and plastics products",       
                   "Other non-metallic mineral products",      
                   "Basic metals",     
                   "Fabricated metal products",    
                   "Machinery and equipment, nec",   
                   "Computer, electronic and optical equipment",  
                   "Electrical equipment", 
                   "Motor vehicles, trailers and semi-trailers",
                   "Other transport equipment",
                   "Manufacturing nec; repair and installation of machinery and equipment")

# T6, Col 1: 10% Lower Measured Internal Costs
tau_t6_c1 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (i in 1:nrow(shares_dist)) {
  row <- shares_dist[i, ]
  if (row$origin %in% provsplus && row$dest %in% provsplus && 
      row$origin != row$dest && !is.na(row$tau_bar) && row$tau_bar > 1) {
    tau_hat <- (1 + 0.9 * (row$tau_bar - 1)) / row$tau_bar
    if (row$sector %in% GOODS_SECTORS) {
      tau_t6_c1[row$dest, row$origin, row$sector] <- tau_hat
    }
  }
}

solution_t6_c1 <- solve_model_matrix(
  tau_hat_array = tau_t6_c1, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "10% Lower Measured Internal Trade Costs",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_t6_c1,
  experiment_name = "10% Lower Measured Internal Trade Costs",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# T6, Col 4: Eliminate Non-Distance Barriers for Goods
tau_t6_c4 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (i in 1:nrow(non_distance_cost_results_final)) {
  row <- non_distance_cost_results_final[i, ]
  if (!is.na(row$tau_counterfactual)&& row$sector %in% GOODS_SECTORS &&
      row$origin %in% provsplus && row$dest %in% provsplus) {
    tau_t6_c4[row$dest, row$origin, row$sector] <- row$tau_counterfactual
  }
}

solution_t6_c4 <- solve_model_matrix(
  tau_hat_array = tau_t6_c4, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "Eliminate Non-Distance Barriers for Goods",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_t6_c4,
  experiment_name = "Eliminate Non-Distance Barriers for Goods",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# T6, Col 5: Eliminate All Measured Internal Costs
tau_t6_c5 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (i in 1:nrow(shares_dist)) {
  row <- shares_dist[i, ]
  if (row$origin %in% provsplus && row$dest %in% provsplus && 
      row$origin != row$dest && !is.na(row$tau_bar) && row$tau_bar > 0) {
    if (row$sector %in% GOODS_SECTORS) {
      tau_t6_c5[row$dest, row$origin, row$sector] <- 1 / row$tau_bar
    }
  }
}

solution_t6_c5 <- solve_model_matrix(
  tau_hat_array = tau_t6_c5, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "Eliminate All Measured Internal Costs",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_t6_c5,
  experiment_name = "Eliminate All Measured Internal Costs",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)
