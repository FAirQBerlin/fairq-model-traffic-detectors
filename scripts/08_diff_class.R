library(Metrics)
library(caret)
library(fairqDbtools)
library(fairqModelTrafficDetectors)
library(data.table)
library(terra)
library(leaflet)
library(raster)
# rm(list=ls())
devtools::load_all()

dat <- as.data.frame(send_query("scripts_street_class_preds_2023"))

prio <- c("strassenklasse_0", "strassenklasse_I", "strassenklasse_II",
          "strassenklasse_III", "strassenklasse_IV", "strassenklasse_V") # keep that order!

M <- as.matrix(dat[prio])
M[is.na(M)] <- 0

B <- M > 0

# find first street class (entry # from prio list) > 0. `1` in apply() is for cols.
index <- apply(B, 1, function(street_class) if (any(street_class)) which(street_class)[1] else NA_integer_)

dat$strassenklasse <- ifelse(is.na(index), NA_character_, prio[index])
dat[prio] <- NULL # remove cols we dont need anymore

dat <- dat[complete.cases(dat), ]

# we take the mean quotient of obs/ preds and calculate the scaling faktor for preds of
# strasasenklasse V
dat_V <- dat[dat$strassenklasse == "strassenklasse_V", ]
mean <- mean(dat_V$kfz_per_24h / dat_V$kfz_per_24h_pred) # 0.5333

## Visualization
# change object
obs_xyz <- as.data.table(dat)[, .(
  x = as.numeric(x),
  y = as.numeric(y),
  obs = as.numeric(kfz_per_24h)
)]

pred_xyz <- as.data.table(dat)[, .(
  x = as.numeric(x),
  y = as.numeric(y),
  pred = as.numeric(kfz_per_24h_pred)
)]

# rasters with terra
r_obs  <- rast(obs_xyz[, .(x,y,obs)],  type="xyz", crs="EPSG:25833")
r_pred <- rast(pred_xyz[,.(x,y,pred)], type="xyz", crs="EPSG:25833")

# abs Diff (need code from 07)
r_diff <- r_obs - r_pred
names(r_diff) <- "diff"

diff_vals <- values(r_diff)
diff_vals <- diff_vals[is.finite(diff_vals)]

max_abs_val <- max(abs(quantile(diff_vals, c(0.01, 0.99), na.rm = TRUE)))

pal_diff <- colorNumeric(
  palette = "RdBu",
  domain = c(-max_abs_val, max_abs_val),
  reverse = TRUE,
  na.color = "transparent"
)

r_diff_rl <- raster(r_diff)

m_diff <- leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addRasterImage(r_diff_rl, colors = pal_diff, opacity = 0.8, project = TRUE) %>%
  addLegend(
    "bottomright",
    pal = pal_diff,
    values = c(-max_abs_val, max_abs_val),
    title = "Differenz (Obs - Pred)",
    labFormat = labelFormat(digits = 0)
  )

m_diff

# rel Diff
r_rel <- ((r_obs - r_pred) / r_obs) * 100
names(r_rel) <- "rel_error_pct"

rel_vals <- values(r_rel)
rel_vals <- rel_vals[is.finite(rel_vals)]

limit_pct <- as.numeric(quantile(abs(rel_vals), 0.95, na.rm = TRUE))

pal_rel <- colorNumeric(
  palette = "RdBu",
  domain = c(-limit_pct, limit_pct),
  reverse = TRUE,
  na.color = "transparent"
)


r_rel_rl <- raster(r_rel)

m_rel <- leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addRasterImage(r_rel_rl, colors = pal_rel, opacity = 0.8, project = TRUE) %>%
  addLegend(
    "bottomright",
    pal = pal_rel,
    values = c(-limit_pct, limit_pct),
    title = "Rel. Fehler (%)<br>(Obs-Pred)/Obs",
    labFormat = labelFormat(suffix = "%", digits = 0)
  )

m_rel

# visualize streetclass
dat$x <- as.numeric(dat$x)
dat$y <- as.numeric(dat$y)

dat_clean <- na.omit(dat[, c("x", "y", "strassenklasse")])
dat_clean$class_id <- match(dat_clean$strassenklasse, prio)
dat_unique <- dat_clean[!duplicated(dat_clean[, c("x", "y")]), ]
r_class <- rast(dat_unique[, c("x", "y", "class_id")], type="xyz", crs="EPSG:25833")

pal <- colorFactor("Set2", domain = 1:length(prio), na.color = "transparent")

leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addRasterImage(raster(r_class), colors = pal, opacity = 0.8, project = TRUE, method = "ngb") %>%
  addLegend(pal = pal, values = 1:length(prio), title = "Klasse",
            labFormat = labelFormat(transform = function(x) prio[x]))


# rel error / street class
dat$error <- dat$kfz_per_24h - dat$kfz_per_24h_pred
dat$relative_error <- (dat$kfz_per_24h - dat$kfz_per_24h_pred) / dat$kfz_per_24h * 100

tapply(dat$error, dat$strassenklasse, mean, na.rm = TRUE)
tapply(dat$relative_error, dat$strassenklasse, mean, na.rm = TRUE)

R2(dat$kfz_per_24h_pred, dat$kfz_per_24h, formula = "traditional")
rmse(dat$kfz_per_24h, dat$kfz_per_24h_pred)
mae(dat$kfz_per_24h, dat$kfz_per_24h_pred)

# as the mean for 2024 is 0.53333, we multiply all values in dat -> strassenklasse_V
# by it -> reavaluate this dat with the diff maps
dat <- dat %>% mutate(
  kfz_per_24h_pred = ifelse(
    strassenklasse == "strassenklasse_V",
    kfz_per_24h_pred * mean,
    kfz_per_24h_pred
  )
)

# after multiplying, redo the visualization from above
