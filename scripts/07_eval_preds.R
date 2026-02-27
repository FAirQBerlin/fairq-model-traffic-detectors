library(Metrics)
library(caret)
library(fairqDbtools)
library(fairqModelTrafficDetectors)
library(data.table)
library(terra)
library(leaflet)
library(raster)
# rm(list=ls())

### In here we do the evaluation of raw or scaled preds vs obs for q_kfz detectors.
devtools::load_all()
pred_obs <- send_query("scripts_compare_det_obs_pred_2023")

# getting raw scaling (old scaling)
scales <- send_query("scripts_scale_2023")

# Putting weighted scales onto raw_pred_obs
pred_obs_scaling <- merge(pred_obs,
             scales[, c("x","y","scaling_raw")],
             by = c("x","y"),
             all.x = TRUE)


if (nrow(pred_obs_scaling) != nrow(pred_obs)) {
  stop("inequal number of data points")
}

# Calculate the fit without scaling
rmse(pred_obs$obs, pred_obs$pred) # 130.66
mae(pred_obs$obs, pred_obs$pred) # 78.61
R2(pred_obs$pred, pred_obs$obs, formula = "traditional") # caret R2, 0.88

# Using sapply() and 0.05-steps to search for best w:
w <- seq(0.2, 3.0, by = 0.05)

rmse_w <- sapply(w, function(weight) {
  rmse(actual = pred_obs_scaling$obs,
       predicted = pred_obs_scaling$pred * pred_obs_scaling$scaling_raw * weight)
})

mae_w <- sapply(w, function(weight) {
  mae(actual = pred_obs_scaling$obs,
      predicted = pred_obs_scaling$pred * pred_obs_scaling$scaling_raw * weight)
})

r2_w <- sapply(w, function(weight) {
  R2(pred = pred_obs_scaling$pred * pred_obs_scaling$scaling_raw * weight,
     obs  = pred_obs_scaling$obs,
     formula = "traditional")
})

eval_df <- data.frame(
  w = w,
  rmse = rmse_w,
  mae  = mae_w,
  r2   = r2_w
)

# Best w by RMSE
best_i <- which.min(eval_df$rmse)
best_w <- eval_df$w[best_i]
best_w
eval_df[best_i, ]

# Plots
plot(eval_df$w, eval_df$rmse, type = "l",
     xlab = "w", ylab = "RMSE", main = "RMSE in Abhängigkeit von w")
plot(eval_df$w, eval_df$mae, type = "l", xlab = "w", ylab = "MAE", main = "MAE vs w")
plot(eval_df$w, eval_df$r2,  type = "l", xlab = "w", ylab = "R²",  main = "R² vs w", log ="y") # log scale

### Plot the values for pred and obs at all grids, where kfz_per_24h > 0
map <- send_query("scripts_map_pred_obs_2023")

# build datatables with terra-friendly types as it doesnt allow non numeric
obs_xyz <- as.data.table(map)[, .(
  x = as.numeric(x),
  y = as.numeric(y),
  obs = as.numeric(kfz_per_24h)
)]

pred_xyz <- as.data.table(map)[, .(
  x = as.numeric(x),
  y = as.numeric(y),
  pred = as.numeric(kfz_per_24h_pred)
)]

# rasters with terra
r_obs  <- rast(obs_xyz[, .(x,y,obs)],  type="xyz", crs="EPSG:25833")
r_pred <- rast(pred_xyz[,.(x,y,pred)], type="xyz", crs="EPSG:25833")
names(r_obs)  <- "obs"
names(r_pred) <- "pred"

# shared palette for both plots without extreme outliers
vals <- c(values(r_obs), values(r_pred))
vals <- vals[is.finite(vals)]
lo <- as.numeric(quantile(vals, 0.01, na.rm = TRUE))
hi <- as.numeric(quantile(vals, 0.99, na.rm = TRUE))
pal <- colorNumeric("viridis", domain = c(lo, hi), na.color = "transparent") # leaflet palette

# leaflet wants RasterLayer, so we do it with raster package
r_obs_rl  <- raster(r_obs)
r_pred_rl <- raster(r_pred)

m_obs <- leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addRasterImage(r_obs_rl,  colors = pal, opacity = 0.85, project = TRUE) %>%
  addLegend("bottomright", pal = pal, values = c(lo, hi), title = "obs (kfz_per_24h)")

m_pred <- leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addRasterImage(r_pred_rl, colors = pal, opacity = 0.85, project = TRUE) %>%
  addLegend("bottomright", pal = pal, values = c(lo, hi), title = "pred (kfz_per_24h_pred)")

m_obs
m_pred

### maps where we multiply our preds with 2
pred_xyz <- as.data.table(map)[, .(
  x = as.numeric(x),
  y = as.numeric(y),
  pred = as.numeric(kfz_per_24h_pred*2)
)]

# rasters with terra
r_pred <- rast(pred_xyz[,.(x,y,pred)], type="xyz", crs="EPSG:25833")
names(r_pred) <- "pred"

# shared palette for both plots without extreme outliers
vals <- c(values(r_obs), values(r_pred))
vals <- vals[is.finite(vals)]
lo <- as.numeric(quantile(vals, 0.01, na.rm = TRUE))
hi <- as.numeric(quantile(vals, 0.99, na.rm = TRUE))
pal <- colorNumeric("viridis", domain = c(lo, hi), na.color = "transparent")

r_pred_rl <- raster(r_pred)

m_pred <- leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addRasterImage(r_pred_rl, colors = pal, opacity = 0.85, project = TRUE) %>%
  addLegend("bottomright", pal = pal, values = c(lo, hi), title = "pred (kfz_per_24h_pred)")

m_obs # same as for non-scaling
m_pred # watch the color grading scale in the legend!

### R² of TEUs vs VMK
te <- pred_obs[!duplicated(pred_obs$mq_name), c("mq_name", "x", "y")]

res <- merge(
  te, map,
  by = c("x", "y"),
  all.x = TRUE
)

res <- res[, c("mq_name", "x", "y", "kfz_per_24h", "kfz_per_24h_pred")]
rmse(res$kfz_per_24h, res$kfz_per_24h_pred)
mae(res$kfz_per_24h, res$kfz_per_24h_pred)
R2(res$kfz_per_24h_pred, res$kfz_per_24h, formula = "traditional")

### Here we model the average error per street class of our preds compared to the Verkehrsmengenkarte.
# Retrieving 24h preds and obs (Verkehrsmengenkarte). We need to keep only the largest street
# class with value > 0.

dat <- as.data.frame(send_query("scripts_street_class_preds_2023"))

prio <- c("strassenklasse_0", "strassenklasse_I", "strassenklasse_II",
          "strassenklasse_III", "strassenklasse_IV", "strassenklasse_V") # keep that order!

M <- as.matrix(dat[prio])
M[is.na(M)] <- 0

B <- M > 0

# find first street class (entry # from prio list) > 0. `1` in apply() is for cols, `2` for rows.
index <- apply(B, 1, function(street_class) if (any(street_class)) which(street_class)[1] else NA_integer_)

dat$strassenklasse <- ifelse(is.na(index), NA_character_, prio[index])
dat[prio] <- NULL # remove cols we dont need anymore

# calculate ratios to see how far we are off
m_obs  <- tapply(dat$kfz_per_24h,      dat$strassenklasse, mean, na.rm = TRUE)
m_pred <- tapply(dat$kfz_per_24h_pred, dat$strassenklasse, mean, na.rm = TRUE)

ratio <- m_obs / m_pred
ratio <- ratio[prio]

# New map where grid cells are scaled by straßenklasse (straßenklasse_V excluded).
map <- send_query("scripts_scale_2023")

# Below we multiply the preds with the ratio
dat$scal <- as.numeric(ratio[as.character(dat$strassenklasse)])
dat$scal[is.na(dat$scal)] <- 1
dat$scal[dat$strassenklasse == "strassenklasse_V"] <- 1
dat$kfz_per_24h_pred <- dat$kfz_per_24h_pred * dat$scal

dat_fin <-dat

# Same as above
obs_xyz <- as.data.table(map)[, .(
  x = as.numeric(x),
  y = as.numeric(y),
  obs = as.numeric(kfz_per_24h)
)]

pred_xyz <- as.data.table(dat)[, .(
  x = as.numeric(x),
  y = as.numeric(y),
  pred = as.numeric(kfz_per_24h_pred)
)]

# (optional but safe) collapse duplicates per (x,y)
obs_xyz  <- obs_xyz[,  .(obs  = mean(obs,  na.rm=TRUE)), by=.(x,y)]
pred_xyz <- pred_xyz[, .(pred = mean(pred, na.rm=TRUE)), by=.(x,y)]

r_obs  <- rast(obs_xyz[, .(x,y,obs)],  type="xyz", crs="EPSG:25833")
r_pred <- rast(pred_xyz[,.(x,y,pred)], type="xyz", crs="EPSG:25833")
names(r_obs)  <- "obs"
names(r_pred) <- "pred"

# shared palette for both plots without extreme outliers
vals <- c(terra::values(r_obs), terra::values(r_pred))
vals <- vals[is.finite(vals)]
lo <- as.numeric(quantile(vals, 0.01, na.rm = TRUE))
hi <- as.numeric(quantile(vals, 0.99, na.rm = TRUE))

pal <- leaflet::colorNumeric("viridis", domain = c(lo, hi), na.color = "transparent")

# leaflet wants RasterLayer
r_obs_rl  <- raster::raster(r_obs)
r_pred_rl <- raster::raster(r_pred)

m_obs <- leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addRasterImage(r_obs_rl,  colors = pal, opacity = 0.85, project = TRUE) %>%
  addLegend("bottomright", pal = pal, values = c(lo, hi), title = "obs (kfz_per_24h)")

m_pred <- leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addRasterImage(r_pred_rl, colors = pal, opacity = 0.85, project = TRUE) %>%
  addLegend("bottomright", pal = pal, values = c(lo, hi), title = "pred (kfz_per_24h_pred)")

# watch changed scales in the legend!
m_obs
m_pred


### are we good at TEUs with street scaling?
det <- as.data.frame(send_query("scripts_compare_det_obs_pred_2023"))

det <- merge(
  det,
  dat[, c("x", "y", "strassenklasse", "scal")],
  by = c("x", "y"),
  all.x = TRUE,
  sort = FALSE
)

# with scaling
rmse(det$obs, det$pred*det$scal)
mae(det$obs, det$pred*det$scal)
R2(det$pred*det$scal, det$obs, formula = "traditional")

### Sum of TEU pairs vs VMK / scaled sum of TEU pairs vs VMK
pred_obs <- send_query("scripts_compare_det_obs_pred_2023")
dat <- as.data.frame(send_query("scripts_street_class_preds_2023"))
prio <- c("strassenklasse_0", "strassenklasse_I", "strassenklasse_II",
          "strassenklasse_III", "strassenklasse_IV", "strassenklasse_V") # keep that order

M <- as.matrix(dat[prio])
M[is.na(M)] <- 0

B <- M > 0

# find first street class (entry # from prio list) > 0
index <- apply(B, 1, function(street_class) if (any(street_class)) which(street_class)[1] else NA_integer_)

dat$strassenklasse <- ifelse(is.na(index), NA_character_, prio[index])
dat[prio] <- NULL

# calculate ratios to see how far we are off
m_obs  <- tapply(dat$kfz_per_24h,      dat$strassenklasse, mean, na.rm = TRUE)
m_pred <- tapply(dat$kfz_per_24h_pred, dat$strassenklasse, mean, na.rm = TRUE)

ratio <- m_obs / m_pred
ratio <- ratio[prio]

# New map where grid cells are scaled by straßenklasse (straßenklasse_V excluded).
# Below we multiply the preds with the ratio
dat$scal <- as.numeric(ratio[dat$strassenklasse])
dat$scal[dat$strassenklasse == "strassenklasse_V"] <- as.numeric(1)

t <- pred_obs[!duplicated(pred_obs$mq_name), c("mq_name", "x", "y")]

res <- merge(
  t, dat,
  by = c("x", "y"),
  all.x = TRUE
)

# Kochstraße
tes <- c("TE380", "TE379")
koch <- res[res$mq_name %in% tes, ]
(sum(koch$kfz_per_24h) / 2) / sum(koch$kfz_per_24h_pred) # summed up, would we be close to the VMK?
c(koch$strassenklasse, koch$scal)
sum(koch$kfz_per_24h) / sum(koch$kfz_per_24h_pred * koch$scal) # scaled and summed up, would we be close to the VMK?


# Torstraße
tes <- c("TE181", "TE180")
tor <- res[res$mq_name %in% tes, ]
(sum(tor$kfz_per_24h) / 2) / sum(tor$kfz_per_24h_pred) # summed up, would we be close to the VMK?
c(tor$strassenklasse, tor$scal)
sum(tor$kfz_per_24h) / sum(tor$kfz_per_24h_pred * tor$scal) # scaled and summed up, would we be close to the VMK?

# Hohenzollerndamm
tes <- c("TE301", "TE300")
hohen <- res[res$mq_name %in% tes, ]
(sum(hohen$kfz_per_24h) / 2) / sum(hohen$kfz_per_24h_pred) # summed up, would we be close to the VMK?
c(hohen$strassenklasse, hohen$scal)
sum(hohen$kfz_per_24h) / sum(hohen$kfz_per_24h_pred * hohen$scal) # scaled and summed up, would we be close to the VMK?

# Altmoabit
tes <- c("TE452", "TE503")
alt <- res[res$mq_name %in% tes, ]
(sum(alt$kfz_per_24h) / 2) / sum(alt$kfz_per_24h_pred) # summed up, would we be close to the VMK?
c(alt$strassenklasse, alt$scal)
sum(alt$kfz_per_24h) / sum(alt$kfz_per_24h_pred * alt$scal) # scaled and summed up, would we be close to the VMK?

# Straße des 17. Juni
tes <- c("TE072", "TE073")
juni <- res[res$mq_name %in% tes, ]
(sum(juni$kfz_per_24h) / 2) / sum(juni$kfz_per_24h_pred) # summed up, would we be close to the VMK?
c(juni$strassenklasse, juni$scal)
sum(juni$kfz_per_24h) / sum(juni$kfz_per_24h_pred * juni$scal) # scaled and summed up, would we be close to the VMK?

# Straße des 17. Juni
tes <- c("TE106", "TE232")
juni <- res[res$mq_name %in% tes, ]
(sum(juni$kfz_per_24h) / 2) / sum(juni$kfz_per_24h_pred) # summed up, would we be close to the VMK?
c(juni$strassenklasse, juni$scal)
sum(juni$kfz_per_24h) / sum(juni$kfz_per_24h_pred * juni$scal) # scaled and summed up, would we be close to the VMK?

# A 115
tes <- c("TE001", "TE002")
ab <- res[res$mq_name %in% tes, ]
(sum(ab$kfz_per_24h) / 2) / sum(ab$kfz_per_24h_pred) # summed up, would we be close to the VMK?
c(ab$strassenklasse, ab$scal)
sum(ab$kfz_per_24h) / sum(ab$kfz_per_24h_pred * ab$scal) # scaled and summed up, would we be close to the VMK?

# Landsberger
tes <- c("TE162", "TE484")
land <- res[res$mq_name %in% tes, ]
(sum(land$kfz_per_24h) / 2) / sum(land$kfz_per_24h_pred) # summed up, would we be close to the VMK?
c(land$strassenklasse, land$scal)
sum(land$kfz_per_24h) / sum(land$kfz_per_24h_pred * land$scal) # scaled and summed up, would we be close to the VMK?

# Potsdamer / Berliner
tes <- c("TE005", "TE209")
pb <- res[res$mq_name %in% tes, ]
(sum(pb$kfz_per_24h) / 2) / sum(pb$kfz_per_24h_pred) # summed up, would we be close to the VMK?
c(pb$strassenklasse, pb$scal)
sum(pb$kfz_per_24h) / sum(pb$kfz_per_24h_pred * pb$scal) # scaled and summed up, would we be close to the VMK?


### How do we do with raw scaling, street scaling and just doubling at TEU (no street scaling of class V)
fuse_scales <- merge(
  res,
  scales[, .(x, y, scaling_raw)],
  by = c("x", "y"),
  all.x = TRUE
)

fuse_scales$scale_double <- 2 # add scale factor by 2
fuse_scales$scale_double[fuse_scales$strassenklasse == "strassenklasse_V"] <- 1

rmse(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred) # no scaling
rmse(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred * fuse_scales$scaling_raw) # raw scaling
rmse(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred * fuse_scales$scal) # street scaling
rmse(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred * fuse_scales$scale_double) # * 2

mae(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred) # no scaling
mae(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred * fuse_scales$scaling_raw) # raw scaling
mae(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred * fuse_scales$scal) # street scaling
mae(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred * fuse_scales$scale_double) # * 2

### How do we do with raw scaling, street scaling and just doubling at whole grid (no street scaling of class V)
fuse_scales <- merge(
  dat,
  scales[, .(x, y, scaling_raw)],
  by = c("x", "y"),
  all.x = TRUE
)

fuse_scales <- fuse_scales[complete.cases(fuse_scales), ]
fuse_scales$scale_double <- 2 # add scale factor by 2
fuse_scales$scale_double[fuse_scales$strassenklasse == "strassenklasse_V"] <- 1 # we won't scale class V

rmse(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred) # no scaling
rmse(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred * fuse_scales$scaling_raw) # raw scaling
rmse(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred * fuse_scales$scal) # street scaling
rmse(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred * fuse_scales$scale_double) # * 2

mae(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred) # no scaling
mae(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred * fuse_scales$scaling_raw) # raw scaling
mae(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred * fuse_scales$scal) # street scaling
mae(fuse_scales$kfz_per_24h, fuse_scales$kfz_per_24h_pred * fuse_scales$scale_double) # * 2

