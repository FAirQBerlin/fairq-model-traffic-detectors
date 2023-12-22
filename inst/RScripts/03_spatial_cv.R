# This script estimates the traffic model using XGboost with a spatial CV.
# We use the optimal hyper parameters we identified using temporal CV.
# For number of vehicles, the predictions are rescaled w.r.t.
# Verkehrsmengenkarte.

rm(list = ls(all.names = TRUE))

library(caret)
library(dplyr)
library(fairqDbtools)
library(fairqModelTrafficDetectors)
library(ggplot2)
library(ggrepel)
library(Metrics)
library(parallel)

set.seed(109385)

# Set variables ----
# If DEV is TRUE, we work with a fraction of cases (= frac_if_dev)
# and less hyper parameter combinations
DEV <- Sys.getenv("DEV")
frac_if_dev <- 0.02
# Which target variable should be modeled?
# --> "q_kfz" for counted traffic of all vehicles volume/quantities
# --> "v_kfz" for average traffic speed of all vehicles
target_variable <- "q_kfz"

# Get data ----
dat <- get_data(target_variable, DEV, frac_if_dev)
scaling_factors <- send_query("scaling_factors_at_detectors")

# Split data and train model ----
n_splits <- ifelse(DEV, 2, 5)
groups <- dat %>%
  select(mq_name) %>%
  distinct() %>%
  mutate(group = sample(1:n_splits, size = nrow(.), replace = TRUE))
dat <- dat %>%
  left_join(groups, by = "mq_name") %>%
  left_join(scaling_factors, by = c("x", "y"))

result_list <- lapply(1:n_splits,
                      function(id) {
                        # Split data
                        dat_train <-
                          dat %>% filter(group != id)
                        dat_test <-
                          dat %>% filter(group == id)

                        # Train model
                        xgb_fit <- train(
                          form = model_formula(target_variable),
                          data = dat_train,
                          method = "xgbTree",
                          tuneGrid = optimal_hyper_parameters(target_variable),
                          reg_lambda = optimal_lambda(target_variable),
                          trControl = trainControl("none", predictionBounds = c(0, NA)),
                          verbose = TRUE,
                          nthread = detectCores() - 1
                        )

                        # Make predictions
                        dat_test$pred <-
                          predict(xgb_fit, dat_test)
                        dat_test
                      })

save(file = "pred_cv.Rdata", result_list)


# Plot results ----
dat_test_combined <- bind_rows(result_list)

if (target_variable ==  "q_kfz") {
  # Multiply by scaling factor and divide by 2 to have a one-direction prediction
  dat_test_combined <-
    dat_test_combined %>% mutate(pred = pred * scaling / 2)
}

plot_pred_vs_obs(target_variable, dat_test_combined) + facet_grid(group ~ .)
plot_distri(target_variable, dat_test_combined) + facet_grid(group ~ .)
plot_resid_against_obs(target_variable, dat_test_combined) + facet_grid(group ~ .)


# Model performance ----
perf <-
  dat_test_combined %>%
  split(dat_test_combined$group) %>%
  lapply(function(df, target_col = target_variable) {
    data.frame(
      rmse = rmse(df[[target_col]], df$pred),
      rsq = R2(df$pred, df[[target_col]], formula = "traditional"),
      mae = mae(df[[target_col]], df$pred)
    )
  }) %>% bind_rows

perf

# Mean metrics
apply(perf, 2, mean)


# Plot avg. per det (pred vs. obs) ----
# This answers the question: "How good are we at simulating the overall traffic
# for a street in Berlin where there is no traffic detector?"
dat_test_agg <- dat_test_combined %>%
  group_by(mq_name) %>%
  summarise(pred = mean(pred), obs = mean(!!sym(target_variable)), scaling = first(scaling))

ggplot(dat_test_agg, aes(x = pred, y = obs)) +
  geom_abline(slope = 1, col = "darkgrey") +
  geom_point(aes(col = scaling)) +
  geom_text_repel(aes(label = mq_name)) +
  labs(
    x = "Mittlerer vorhergesagter Wert",
    y = "Mittlere Beobachtung",
    title = "Vorhersagegüte pro Detektor",
    subtitle = "Daten seit 2015"
  )

cor(dat_test_agg$pred, dat_test_agg$obs)
cor(dat_test_agg$pred, dat_test_agg$obs, method = "spearman")
