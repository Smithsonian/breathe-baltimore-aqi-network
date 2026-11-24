# 30_maps_fig1_figS4.R (2026-11-23, Round 6l). Figures 1 and S4 from script 21 (same data and style); only changes:
# true minus signs in the SVI colour-bar labels, and a three-line SVI legend title in Fig S4 so it is not clipped.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))
suppressPackageStartupMessages({ library(sf); library(ggplot2); library(patchwork); library(ggrepel)
  library(lme4); library(lmerTest); library(emmeans); library(scales) })
emm_options(lmer.df = "satterthwaite", lmerTest.limit = 1e5)
FIG <- file.path(REV_DIR, "figures_final"); dir.create(FIG, showWarnings = FALSE)
is_mac <- Sys.info()[["sysname"]] == "Darwin"
SANS  <- if (is_mac) "Helvetica" else "TeX Gyre Heros"
SERIF <- if (is_mac) "Times New Roman" else "TeX Gyre Termes"
save_fig <- function(p, name, w, h) {
  ggsave(file.path(FIG, paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf)
  ggsave(file.path(FIG, paste0(name, ".png")), p, width = w, height = h, dpi = 600, bg = "white")
}
d  <- readRDS(file.path(OUT_DIR, "20_daily_final_cdc.rds"))   # corrected Stage 2 (scripts 18_stage2_refit -> 19_apply_stage2_fix -> 15 PFX=20)
R  <- readRDS(file.path(OUT_DIR, "20_results.rds"))
pv <- read_csv(file.path(REV_DIR, "inputs_derived/svi_provenance_v2.csv"), show_col_types = FALSE)
holc_colors <- c("C: Declining" = "#FFC107", "D: Hazardous" = "#F44336", "IC: Industrial" = "#89C4E1", "Not Graded" = "#757575",
                 "A: Best" = "#4CAF50", "B: Still Desirable" = "#2196F3")
grade_lab <- c(A = "A: Best", B = "B: Still Desirable", C = "C: Declining", D = "D: Hazardous", IC = "IC: Industrial", `Not Graded` = "Not Graded")
site_order <- c("ALotMatter", "Ark", "BayBrook", "Bilingual", "FederalHillPrep", "Filbert", "ToolBank", "ConventionCenter",
                "Stillmeadow", "StrengthToLove", "Waterfront", "BUGS", "FortMcHenry", "WestCovingtonPark", "Barclay")
site_num <- setNames(paste0("Site ", seq_along(site_order)), site_order)   # numbering used in the submission
fmt <- function(x, n = 2) { s <- formatC(signif(x, n), digits = n, format = "g", flag = "#"); sub("[.]$", "", s) }
sgn <- function(x, n = 2) ifelse(x >= 0, paste0("+", fmt(x, n)), paste0("−", fmt(abs(x), n)))

# ============================== Figures 1 and S4: maps ==============================
cdc <- read_csv(file.path(REV_DIR, "inputs_derived/cdc_svi2020_baltimore_tracts.csv"), col_types = "cd")
tr <- st_read(file.path(REV_DIR, "inputs_derived/geo/balt_demos.geojson"), quiet = TRUE) %>%
  left_join(cdc, by = c("geoid" = "GEOID")) %>%
  mutate(vuln_local = (RPL_THEMES_2020_national - mean(RPL_THEMES_2020_national, na.rm = TRUE)) / sd(RPL_THEMES_2020_national, na.rm = TRUE)) %>%
  st_transform(2248)
bnd <- st_union(tr) %>% st_sf()
md <- st_read(file.path(REV_DIR, "inputs_derived/geo/us_states.json"), quiet = TRUE) %>% filter(name == "Maryland") %>% st_transform(2248)
holc_site <- d %>% distinct(site, housing_grade) %>% mutate(holc = grade_lab[as.character(housing_grade)])
sites_sf <- pv %>% select(site, lon = recorded_lon, lat = recorded_lat) %>% left_join(holc_site, by = "site") %>%
  mutate(label = site_num[site]) %>% st_as_sf(coords = c("lon", "lat"), crs = 4326) %>% st_transform(2248)
pa <- tibble(site = c("PA_A", "PA_B"), label = c("PurpleAir Site 1", "PurpleAir Site 2"), holc = c("A: Best", "B: Still Desirable"),
             lon = c(-76.59696, -76.53066), lat = c(39.341824, 39.34763)) %>%   # from data/bmore_daily_avg_filtered.csv (source = purple_air)
  st_as_sf(coords = c("lon", "lat"), crs = 4326) %>% st_transform(2248)
make_map <- function(pts, grades, svi_title = "Social Vulnerability Index\n(CDC/ATSDR SVI 2020;\nlocal z-score)") {
  bb <- st_bbox(bnd); ft <- 3000 / 0.3048006   # 3 km in US survey feet
  x0 <- bb[["xmin"]] + 0.30 * (bb[["xmax"]] - bb[["xmin"]]); y0 <- bb[["ymin"]] - 0.02 * (bb[["ymax"]] - bb[["ymin"]])
  sb <- tibble(x = x0 + c(0, 1, 2) * ft / 3, xe = x0 + c(1, 2, 3) * ft / 3, f = c("black", "white", "black"))
  ax <- x0 + ft / 2; ay <- y0 + 0.10 * (bb[["ymax"]] - bb[["ymin"]]); ah <- 0.06 * (bb[["ymax"]] - bb[["ymin"]])
  arrow_df <- tibble(x = c(ax, ax - ah * 0.3, ax, ax + ah * 0.3), y = c(ay + ah, ay - ah * 0.2, ay, ay - ah * 0.2))
  ggplot() +
    geom_sf(data = tr, aes(fill = vuln_local), color = "white", linewidth = 0.3) +
    scale_fill_gradient2(low = "#F3E5F5", mid = "#B39DDB", high = "#4A148C", midpoint = 0, limits = c(-2.5, 2.5), oob = squish,
      breaks = c(-2, -1, 0, 1, 2), labels = c("\u22122\n(Less)", "\u22121", "0\n(Baltimore\navg)", "1", "2\n(More)"), na.value = "grey90",
      name = svi_title,
      guide = guide_colorbar(direction = "horizontal", title.position = "top", barwidth = unit(7, "cm"), barheight = unit(0.5, "cm"),
                             frame.colour = "black", frame.linewidth = 0.4, ticks.colour = "black", order = 2)) +
    geom_sf(data = bnd, fill = NA, color = "gray30", linewidth = 1.8, alpha = 0.3) +
    geom_sf(data = bnd, fill = NA, color = "black", linewidth = 1.2) +
    geom_sf(data = pts, color = "black", shape = 19, size = 4.0) +
    geom_sf(data = pts, aes(color = holc), shape = 19, size = 2.6) +
    scale_color_manual(values = holc_colors[grades], breaks = grades, name = "Housing Grade",
                       guide = guide_legend(title.position = "top", ncol = 2, override.aes = list(size = 3.5), order = 1)) +
    geom_label_repel(data = pts, aes(label = label, geometry = geometry), stat = "sf_coordinates", size = 4.2, family = SERIF,
      fill = alpha("white", 0.88), label.size = 0.12, label.padding = unit(0.12, "lines"), label.r = unit(0.08, "lines"),
      box.padding = 0.5, point.padding = 0.3, segment.color = "gray35", segment.size = 0.35, min.segment.length = 0.15,
      max.overlaps = Inf, force = 8, force_pull = 0.5, seed = 99) +
    geom_rect(data = sb, aes(xmin = x, xmax = xe, ymin = y0, ymax = y0 + ft * 0.08), fill = sb$f, color = "black", linewidth = 0.4) +
    annotate("text", x = x0 + ft * 1.08, y = y0 + ft * 0.04, label = "3 km", hjust = 0, family = SERIF, size = 4.5) +
    geom_polygon(data = arrow_df[c(1, 2, 3), ], aes(x, y), fill = "white", color = "black", linewidth = 0.4) +
    geom_polygon(data = arrow_df[c(1, 3, 4), ], aes(x, y), fill = "black", color = "black", linewidth = 0.4) +
    annotate("text", x = ax, y = ay + ah * 1.25, label = "N", family = SERIF, size = 4.5) +
    coord_sf(crs = 2248, datum = NA, clip = "off") +
    labs(caption = "Coordinate Reference System: NAD83 / Maryland State Plane (EPSG:2248)") +
    theme_void(base_family = SERIF, base_size = 14) +
    theme(legend.title = element_text(face = "bold", size = 14), legend.text = element_text(size = 12),
          legend.position = "bottom", legend.box = "horizontal", legend.justification = "left", plot.caption = element_text(color = "grey45", size = 10, hjust = 0.5), plot.caption.position = "plot",
          plot.margin = margin(5, 10, 5, 10),
          plot.background = element_rect(fill = "white", color = NA))
}
inset <- ggplot() + geom_sf(data = md, fill = "grey95", color = "grey50", linewidth = 0.3) +
  geom_sf(data = st_as_sfc(st_bbox(bnd)), fill = NA, color = "red", linewidth = 0.6) + theme_void() +
  theme(plot.background = element_rect(fill = "white", color = NA))
m1 <- make_map(sites_sf, c("C: Declining", "D: Hazardous", "IC: Industrial", "Not Graded")) +
  inset_element(inset, left = 0.01, bottom = 0.24, right = 0.26, top = 0.42, align_to = "full")
save_fig(m1, "Fig1_site_map_cdc_svi", 7.2, 7.6)
ms4 <- make_map(bind_rows(sites_sf %>% select(label, holc), pa %>% select(label, holc)),
                c("A: Best", "B: Still Desirable", "C: Declining", "D: Hazardous", "IC: Industrial", "Not Graded"),
                svi_title = "Social Vulnerability Index\n(CDC/ATSDR SVI 2020;\nlocal z-score)") +
  inset_element(inset, left = 0.01, bottom = 0.24, right = 0.26, top = 0.42, align_to = "full")
save_fig(ms4, "FigS4_site_map_purpleair", 7.2, 7.6)
message("maps done")
