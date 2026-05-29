# Fetch and standardize Botswana Master Facility List service data.
#
# Source: https://healthfacilities.gov.bw  (public client API at
#         https://mfldit.bitri-ist.co.bw/api/facility/client/v1/all)
#
# Writes: data/Botswana/botswana_services.csv with columns
#   facility_code, service_category, service_group, service_detail
#
# Run from the project root:
#   Rscript data/Botswana/fetch_botswana_services.R

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(dplyr)
  library(purrr)
  library(tibble)
  library(readr)
})

api_url <- "https://mfldit.bitri-ist.co.bw/api/facility/client/v1/all"
out_path <- "data/Botswana/botswana_services.csv"

message("Fetching ", api_url, " ...")
resp <- httr::GET(api_url, httr::timeout(120),
                  httr::add_headers(Accept = "application/json"))
httr::stop_for_status(resp)
facilities <- jsonlite::fromJSON(httr::content(resp, as = "text",
                                               encoding = "UTF-8"),
                                 simplifyVector = FALSE)
message("Got ", length(facilities), " facilities")

extract_one <- function(f) {
  code <- if (nzchar(f$newFacilityCode %||% "")) f$newFacilityCode else f$id

  clinical <- purrr::map_chr(f$facilityServices %||% list(),
                             ~ .x$name %||% NA_character_)
  clinical_rows <- if (length(clinical))
    tibble::tibble(facility_code = code,
                   service_category = "clinical_services",
                   service_group = "Clinical Services",
                   service_detail = clinical) else NULL

  yn <- f$knownYesNoInfrastructures %||% list()
  yn_avail <- purrr::keep(yn, ~ isTRUE(.x$isAvailable) || isTRUE(.x$available))
  yn_rows <- if (length(yn_avail))
    tibble::tibble(facility_code = code,
                   service_category = "infrastructure",
                   service_group = "Infrastructure",
                   service_detail = purrr::map_chr(yn_avail, "type")) else NULL

  infra <- f$facilityInfrastructures %||% list()
  infra_rows <- if (length(infra)) {
    purrr::map_dfr(infra, function(i) {
      tp <- i$facilityInfrastructureType
      if (is.null(tp$type)) return(NULL)
      detail <- tp$type
      qty <- suppressWarnings(as.integer(i$quantity %||% 0))
      if (!is.na(qty) && qty > 0)
        detail <- sprintf("%s (qty: %d)", tp$type, qty)
      is_staff <- isTRUE(tp$isStaff) || isTRUE(tp$staff)
      tibble::tibble(
        facility_code = code,
        service_category = if (is_staff) "staff" else "infrastructure",
        service_group = if (is_staff) "Staff" else "Infrastructure",
        service_detail = detail
      )
    })
  } else NULL

  dplyr::bind_rows(clinical_rows, yn_rows, infra_rows)
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

services <- purrr::map_dfr(facilities, extract_one)

message("Writing ", nrow(services), " rows for ",
        dplyr::n_distinct(services$facility_code), " facilities -> ", out_path)
readr::write_csv(services, out_path)
