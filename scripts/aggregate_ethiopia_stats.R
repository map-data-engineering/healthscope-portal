# =============================================================
# aggregate_ethiopia_stats.R
# Pre-aggregate Ethiopia services for the country page.
#
# The Ethiopia services CSV is 84 MB; loading it inside the
# Quarto render exhausts virtual memory on the build machine.
# This script reads it once with data.table::fread, computes the
# two summary tables the country page needs (top-15 services +
# domain coverage), and persists them as small .rds files.
#
# Run after a fresh ETL refresh:
#   Rscript scripts/aggregate_ethiopia_stats.R
# =============================================================

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
})

src <- "etl/data/processed/country_standardized/ethiopia_services_standardized.csv"
out_dir <- "data/Ethiopia"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

svc <- data.table::fread(
  src,
  select = c("facility_code", "service_domain", "service_name",
             "include_in_analysis")
) |>
  dplyr::as_tibble() |>
  dplyr::filter(include_in_analysis == "TRUE" | include_in_analysis == TRUE)

n_facilities <- dplyr::n_distinct(svc$facility_code)

top_services <- svc |>
  dplyr::distinct(facility_code, service_name) |>
  dplyr::count(service_name, name = "facilities") |>
  dplyr::mutate(pct = facilities / n_facilities) |>
  dplyr::arrange(dplyr::desc(facilities)) |>
  utils::head(15)

domain_coverage <- svc |>
  dplyr::distinct(facility_code, service_domain) |>
  dplyr::count(service_domain, name = "facilities") |>
  dplyr::mutate(pct = facilities / n_facilities) |>
  dplyr::arrange(dplyr::desc(facilities))

saveRDS(list(
  n_facilities    = n_facilities,
  top_services    = top_services,
  domain_coverage = domain_coverage
), file.path(out_dir, "ethiopia_services_summary.rds"))

cat(sprintf("Wrote %s — %d facilities aggregated\n",
            file.path(out_dir, "ethiopia_services_summary.rds"),
            n_facilities))
