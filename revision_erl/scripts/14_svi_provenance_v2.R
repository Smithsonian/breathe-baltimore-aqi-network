# 14_svi_provenance_v2.R
# Verifies CDC/ATSDR SVI 2020 RPL_THEMES (US/national comparison) against the OFFICIAL CDC service and adds
# street-address tract assignments.
# Sources (retrieved 2026-11-23 via the user's browser; workspace cannot reach census.gov / cdc.gov):
#  * inputs_derived/cdc_svi2020_baltimore_tracts.csv: all 199 Baltimore City tracts, field Overall_SVI_Percentile,
#    ReleaseYear=2020, GeoLevel='tract', Comparison='national', from
#    https://onemap.cdc.gov/onemapservices/rest/services/SVI/SVI_consolidated_data/MapServer/0 (CDC/ATSDR GRASP).
#    -999 (no population) stored as NA.
#  * inputs_derived/site_address_geocodes.csv: US Census Geocoder (benchmark 4 = Public_AR_Current,
#    vintage 4 = Current_Current), street addresses from the MiddleBranchAQ "Site Info and Deployment" sheet,
#    and coordinate lookups; boundary distances from point-in-polygon on 2020 tract polygons
#    (profrobwells/Baltimore balt_demos.geojson). Nothing here changes any site's recorded coordinates or tract.
suppressPackageStartupMessages(library(tidyverse))
REV_DIR <- normalizePath(Sys.getenv("REV_DIR", "."))
cdc  <- read_csv(file.path(REV_DIR, "inputs_derived/cdc_svi2020_baltimore_tracts.csv"), col_types = "cd")
prov <- read_csv(file.path(REV_DIR, "inputs_derived/svi_provenance.csv"), show_col_types = FALSE)
geo  <- read_csv(file.path(REV_DIR, "inputs_derived/site_address_geocodes.csv"), col_types = cols(.default = "c"))
rec_tract <- prov %>% transmute(site, recorded_tract = ifelse(grepl("^2451", nri_match_tract), nri_match_tract, coord_tract_census_geocoder))
lk <- function(g) cdc$RPL_THEMES_2020_national[match(g, cdc$GEOID)]
cat_cdc <- function(x) cut(x, c(-Inf, .25, .5, .75, Inf), labels = c("Low", "Low-Medium", "Medium-High", "High"))
grp3 <- function(x) factor(ifelse(x <= .25, "Low", ifelse(x <= .75, "Medium (merged)", "High")), levels = c("Low", "Medium (merged)", "High"))
v2 <- prov %>% select(site, recorded_score, recorded_group, nri_sovi_score_recorded_tract, nri_sovi_score_coord_tract,
                      esri_cdc_recorded = cdc_svi2020_rpl_recorded_tract, esri_cdc_coord = cdc_svi2020_rpl_coord_tract) %>%
  left_join(rec_tract, by = "site") %>% left_join(geo, by = "site") %>%
  mutate(addr_tract_census_geocoder = ifelse(is.na(addr_tract_census_geocoder), recorded_tract, addr_tract_census_geocoder),
         cdc_rpl_recorded = lk(recorded_tract), cdc_rpl_address = lk(addr_tract_census_geocoder), cdc_rpl_coord = lk(coord_tract_census_geocoder),
         official_matches_esri = abs(cdc_rpl_recorded - esri_cdc_recorded) < 1e-9 & abs(cdc_rpl_coord - esri_cdc_coord) < 1e-9,
         cdc_cat_recorded = cat_cdc(cdc_rpl_recorded), grp_recorded = grp3(cdc_rpl_recorded),
         grp_address = grp3(cdc_rpl_address), grp_coord = grp3(cdc_rpl_coord),
         tract_status = case_when(recorded_tract == addr_tract_census_geocoder & recorded_tract == coord_tract_census_geocoder ~ "consistent",
                                  site == "FortMcHenry" & recorded_tract == coord_tract_census_geocoder ~ "consistent (no street address on file)",
                                  TRUE ~ "NEEDS CONFIRMATION"))
stopifnot(all(v2$official_matches_esri))
write_csv(v2, file.path(REV_DIR, "inputs_derived/svi_provenance_v2.csv"))
print(v2 %>% select(site, recorded_tract, addr_tract_census_geocoder, coord_tract_census_geocoder, cdc_rpl_recorded, cdc_rpl_address, cdc_rpl_coord,
                    grp_recorded, grp_address, grp_coord, tract_status), n = 20, width = 250)
print(table(v2$grp_recorded)); print(table(v2$grp_address)); print(table(v2$grp_coord))
