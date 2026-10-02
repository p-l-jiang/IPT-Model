# General helpers used across the library.

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Repository root (set by src/load.R), used to locate configuration files
#' independently of the working directory.
ipt_root <- function() getOption("ipt.root", ".")

#' Print a time-stamped progress message.
log_info <- function(...) {
  message(format(Sys.time(), "[%H:%M:%S] "), paste0(...))
}

#' Stop with a formatted message and no call trace.
stopf <- function(fmt, ...) stop(sprintf(fmt, ...), call. = FALSE)

#' Warn with a formatted message and no call trace.
warnf <- function(fmt, ...) warning(sprintf(fmt, ...), call. = FALSE)

ensure_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

#' Extract the classification code in square brackets at the end of a
#' Statistics Canada member name, e.g. "Wood products [MPG321908]" -> "MPG321908".
#' Returns NA when there is no code.
extract_code <- function(x) {
  out <- sub("^.*\\[([A-Za-z0-9]+)\\]\\s*$", "\\1", x)
  out[!grepl("\\[[A-Za-z0-9]+\\]\\s*$", x)] <- NA_character_
  out
}

#' Remove a trailing " [CODE]" from Statistics Canada member names.
strip_code <- function(x) sub("\\s*\\[[A-Za-z0-9]+\\]\\s*$", "", x)

#' Longest-prefix lookup.
#'
#' For each code, returns the value attached to the longest matching prefix in
#' `prefixes`, or NA when no prefix matches.
match_longest_prefix <- function(codes, prefixes, values) {
  stopifnot(length(prefixes) == length(values))
  ord <- order(-nchar(prefixes))
  prefixes <- prefixes[ord]
  values <- values[ord]
  out <- rep(NA_character_, length(codes))
  for (k in seq_along(prefixes)) {
    hit <- is.na(out) & startsWith(codes, prefixes[k])
    out[hit] <- values[k]
  }
  out
}

#' Great-circle distance in kilometres (haversine formula). The default radius
#' (6378.137 km, the WGS84 equatorial radius) matches geosphere::distHaversine,
#' which the legacy scripts used.
haversine_km <- function(lon1, lat1, lon2, lat2, radius_km = 6378.137) {
  to_rad <- pi / 180
  dlat <- (lat2 - lat1) * to_rad
  dlon <- (lon2 - lon1) * to_rad
  a <- sin(dlat / 2)^2 + cos(lat1 * to_rad) * cos(lat2 * to_rad) * sin(dlon / 2)^2
  2 * radius_km * asin(pmin(1, sqrt(a)))
}

#' Numerically stable log(sum(exp(x))) that treats -Inf entries as zeros.
log_sum_exp <- function(x) {
  m <- max(x)
  if (!is.finite(m)) return(-Inf)
  m + log(sum(exp(x - m)))
}

#' Fail if any element of `x` is missing or non-finite.
assert_finite <- function(x, what) {
  bad <- !is.finite(x)
  if (any(bad)) stopf("%s contains %d missing or non-finite values.", what, sum(bad))
  invisible(x)
}

#' Fail if any element of `x` is negative (beyond a small tolerance).
assert_nonnegative <- function(x, what, tol = 1e-9) {
  if (any(x < -tol, na.rm = TRUE)) {
    stopf("%s contains negative values (min = %g).", what, min(x, na.rm = TRUE))
  }
  invisible(x)
}

#' Write a data frame as CSV, creating the parent directory if needed.
write_table <- function(df, path) {
  ensure_dir(dirname(path))
  readr::write_csv(df, path, na = "")
  invisible(path)
}
