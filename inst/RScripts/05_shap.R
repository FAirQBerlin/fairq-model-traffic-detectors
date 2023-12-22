# This script loads XGBoost model results from a file and computes Shapley values.
# - The variable importance is computed based on the whole dataset.
# - The shape of the effects for the single features is computed based on a sample
#   because otherwise it takes an unreasonable amount of CPU and time.

rm(list = ls(all.names = TRUE))

library(dplyr)
library(ggplot2)
library(hrbrthemes)
library(INWTggplot)
library(xgboost)
setThemeGgplot2()

set.seed(1702)

file <- "231107_q_kfz_traffic_model_full_period.Rdata"
r2 <- 0.75
target_variable <- "Verkehrsaufkommen"
load(file)

print(xgb_fit)

# Overall
importance_dat <-
  xgb.plot.importance(xgb.importance(model = xgb_fit$finalModel))

importance_dat %>%
  mutate(Feature = factor(Feature, levels = rev(importance_dat$Feature)),
         rel_importance = Importance * r2) %>%
  dplyr::slice(1:10) %>%
ggplot() +
  geom_col(aes(x = rel_importance, y = Feature)) +
  labs(x = "Feature Importance", main = target_variable) +
  scale_x_percent()

# Importance of groups of features (e.g., land use)
importance_dat <- importance_dat %>%
  mutate(
    feature_group = case_when(
      grepl("land_", Feature) ~ "land_use",
      grepl("str_", Feature) ~ "street_class",
      grepl("building", Feature) ~ "buildings",
      grepl("holiday", Feature) ~ "holidays",
      Feature %in% c("x", "y") ~ "coordinates",
      TRUE ~ Feature
    )
  )
importance_dat %>%
  group_by(feature_group) %>%
  summarise(imp = 100 * sum(Importance)) %>%
  ungroup %>%
  arrange(desc(imp))

# Effect of variable levels
# We sample rows because otherwise it takes too long
# 10000 take about 42 seconds
# For 1000 rows we already see only very small differences between the plots for repeated samples
# We sample 100000 rows for the plots
sampled_rows <- sample(1:nrow(xgb_fit$trainingData), 100000)
train_dat <-
  as.matrix(xgb_fit$trainingData[sampled_rows, -".outcome"])
pred_contr <-
  predict(xgb_fit$finalModel,
          train_dat,
          predcontrib = TRUE,
          approxcontrib = FALSE)

save(pred_contr, file = paste0(file, "_pred_contr.RData"))
print("Saved!")
# load(file = paste0(file, "_pred_contr.RData"))

xgb.plot.shap(
  data = train_dat,
  shap_contrib = pred_contr,
  model = xgb_fit$finalModel,
  top_n = 6
)

for (feature in importance_dat$Feature) {
  xgb.plot.shap(train_dat,
                pred_contr,
                model = xgb_fit$finalModel,
                features = feature)
}
