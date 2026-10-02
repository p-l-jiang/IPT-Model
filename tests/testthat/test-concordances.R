fixture <- function(f) readLines(test_path("fixtures", f))

test_that("there are 37 base sectors with unique IDs", {
  s <- load_base_sectors()
  expect_equal(nrow(s), 37)
  expect_false(anyDuplicated(s$sector_id) > 0)
  expect_equal(sum(s$goods), 19)
})

test_that("every ICIO industry maps to a base sector", {
  codes <- fixture("icio_industry_codes.txt")
  expect_length(codes, 50)
  mapped <- icio_code_to_base_sector(codes)
  expect_false(anyNA(mapped))
  expect_setequal(unique(mapped), load_base_sectors()$sector_id)
})

test_that("every StatCan product code observed in 2010-2022 is mapped or excluded", {
  codes <- fixture("iopc_product_codes.txt")
  mapped <- product_code_to_base_sector(codes)
  expect_false(anyNA(mapped), info = paste(codes[is.na(mapped)], collapse = ", "))
  expect_true(all(mapped %in% c(load_base_sectors()$sector_id, "EXCLUDE")))
})

test_that("every StatCan industry code observed is mapped", {
  codes <- fixture("ioic_industry_codes.txt")
  mapped <- industry_code_to_base_sector(codes)
  expect_false(anyNA(mapped), info = paste(codes[is.na(mapped)], collapse = ", "))
  expect_true(all(mapped %in% load_base_sectors()$sector_id))
})

test_that("key products and industries follow ISIC Rev. 4", {
  p <- c(MPG336111 = "MTV",  # passenger cars (were 'Other transport equipment' in the legacy map)
         MPG336401 = "OTE",  # aircraft
         MPG513111 = "PUB",  # newspapers (publishing, ISIC 58)
         MPG323001 = "PAP",  # printed products (printing, ISIC 18)
         MPS722001 = "ACC",  # prepared meals (food services, ISIC 56)
         MPG331201 = "BMT",  # steel pipes and tubes (ISIC 24.2)
         MPG325202 = "CHM",  # synthetic rubber (ISIC 20.1)
         MPG332A03 = "MAC",  # bearings (ISIC 28.14)
         MPS562000 = "UTL",  # waste management (ISIC 38-39, ICIO sector E)
         MPS541503 = "ITS",  # computer systems design (ISIC 62)
         MPS532100 = "ADM",  # rental and leasing (ISIC 77)
         MPS488002 = "MFN",  # aircraft maintenance and repair (ISIC 33.15)
         PRM100000 = "EXCLUDE", FIC110000 = "EXCLUDE", FIC300000 = "TRN")
  expect_equal(product_code_to_base_sector(names(p)), unname(p))
  i <- c(BS336110 = "MTV", BS336400 = "OTE", BS541500 = "ITS", BS811100 = "TRD",
         BS811A00 = "MFN", BS213000 = "MIS", GS911100 = "PAD", NP813100 = "OSV")
  expect_equal(industry_code_to_base_sector(names(i)), unname(i))
})

test_that("adjacency is symmetric and uses known regions", {
  adj <- adjacency_function()
  regions <- load_regions()$region_id
  pairs <- expand.grid(a = regions, b = regions, stringsAsFactors = FALSE)
  expect_equal(adj(pairs$a, pairs$b), adj(pairs$b, pairs$a))
  expect_true(all(adj(regions, regions) == 0))
  raw <- readr::read_csv(concordance_path("adjacency.csv"), show_col_types = FALSE)
  expect_true(all(c(raw$region_a, raw$region_b) %in% regions))
  # Legacy asymmetries are resolved: PE-NB is a fixed link, NS-NL a ferry only.
  expect_equal(adj(c("PE", "NB", "BC", "NS", "NT"), c("NB", "PE", "NT", "NL", "MB")), c(1, 1, 1, 0, 0))
})

test_that("the Albrecht-Tombe sector scheme aggregates all base sectors", {
  cfg <- list(sectors = list(scheme = file.path(ipt_root(), "config", "concordances",
                                                "sector_scheme_albrecht_tombe_2016.csv")))
  scheme <- load_sector_scheme(cfg)
  expect_setequal(scheme$base_sector, load_base_sectors()$sector_id)
  expect_length(unique(scheme$sector_id), 22)
})
