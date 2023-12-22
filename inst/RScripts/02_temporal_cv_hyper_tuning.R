# This script estimates the traffic model using XGBoost with a temporal CV.
# The optimal hyper parameters are identified to be stored (manually) in the package.
# After the HPO, different values for lambda are checked bc. they can't be covered in the HPO.

rm(list = ls(all.names = TRUE))

# Make sure to have latest package version installed:
# devtools::document()
# devtools::install()

library(caret)
library(dplyr)
library(fairqModelTrafficDetectors)
library(Metrics)
library(parallel)
library(rjson)
library(xgboost)

set.seed(3649)

# Set variables ----
# If DEV is TRUE, we work with a fraction of cases (= frac_if_dev)
# and less hyper parameter combinations
DEV <- Sys.getenv("DEV")
frac_if_dev <- (if (DEV) 0.003 else 1)
# If DEV is true, make a very short random HPO with only 2 trials:
tune_length <- ifelse(DEV, 2, 25) # Higher values than 25 recommended to ensure good results
# Which target variable should be modeled?
# --> "q_kfz" for counted traffic of all vehicles volume/quantities
# --> "v_kfz" for average traffic speed of all vehicles
target_variable <- "q_kfz"

# Get data ----
dat <- get_data(target_variable, DEV, frac_if_dev)

# Split data ----
days_per_week <- 7
hours_per_day <- 24
hours_per_week <- days_per_week * hours_per_day

# Train-test split 12 weeks ago:
split_date <- max(dat$date_time) - 12 * hours_per_week * 3600
dat_train <- dat %>% filter(.data$date_time <= split_date)
dat_test <- dat %>% filter(.data$date_time > split_date)

# Temporal CV for training and validation:
avg_n_det <- round(compute_avg_n_det(dat_train))

eval_oos_horizon <-
  12 * hours_per_week * avg_n_det # 12 weeks
skip <-
  12 * hours_per_week * avg_n_det # 12 weeks
initial_train_window <-
  nrow(dat_train) - 4 * skip # So we have 4 different splits
time_control <- trainControl(
  # see http://topepo.github.io/caret/model-training-and-tuning.html#control
  method = "timeslice",
  # The initial number of consecutive values in each training set sample:
  initialWindow = initial_train_window * frac_if_dev,
  # the number of consecutive values in test set sample:
  horizon = eval_oos_horizon * frac_if_dev,
  # how far the validation windows are apart from each other:
  skip = skip,
  # We don't discard older data so the training window grows:
  fixedWindow = FALSE,
  search = "grid",
  verboseIter = TRUE,
  allowParallel = TRUE,
  predictionBounds = c(0, NA)
)

# Check:
nrow(dat_train)
initial_train_window * frac_if_dev
eval_oos_horizon * frac_if_dev
skip
(nrow(dat_train) - initial_train_window * frac_if_dev) / skip # ~ number of splits


# Estimate model ----
n_workers <- min(detectCores() - 2, 25)

# Prepare out-of-sample data for early stopping
feature_names <- labels(terms(model_formula(target_variable)))
watchlist <-
  list(
    train = xgboost:::xgb.DMatrix(label = dat_train[[target_variable]],
                                  data = as.matrix(as.data.frame(dat_train)[, feature_names])),
    eval = xgboost:::xgb.DMatrix(label = dat_test[[target_variable]],
                                 data = as.matrix(as.data.frame(dat_test)[, feature_names]))
  )

xgb_fit <- train(
  model_formula(target_variable),
  data = dat_train,
  method = "xgbTree",
  tuneLength = tune_length,
  tuneGrid = random_hpo_grid(tune_length),
  trControl = time_control,
  verbose = TRUE,
  metric = "RMSE",
  nthread = n_workers,
  verbosity = 0,
  watchlist = watchlist,
  early_stopping_rounds = 5
)

model_filename <- if (DEV) {
  paste0(
    format(Sys.Date(), "%y%m%d"),
    "_",
    target_variable,
    "_temp_CV_results_sample_frac_",
    frac_if_dev,
    ".RData"
  )
} else {
  paste0(
    format(Sys.Date(), "%y%m%d"),
    "_",
    target_variable,
    "_temp_CV_results_full",
    ".RData"
  )
}
save.image(model_filename)

# Inspect model results ----
xgb_fit$results %>% arrange(desc(Rsquared))
# plot(xgb_fit) # takes very long for many trials
xgb_fit$finalModel$best_ntreelimit
xgb_fit$bestTune
plot(xgb_fit$results$max_depth, xgb_fit$results$Rsquared)


# IS vs. OOS fit ----

# Predict on train data
dat_train$pred <- predict(xgb_fit, dat_train)

# Predict on test data
dat_test$pred <- predict(xgb_fit, dat_test)
plot_pred_vs_obs(target_variable, dat_test)
plot_distri(target_variable, dat_test)
plot_resid_against_obs(target_variable, dat_test)

# IS fit
rmse(dat_train[[target_variable]], dat_train$pred)
R2(dat_train$pred, dat_train[[target_variable]], formula = "traditional")
mae(dat_train[[target_variable]], dat_train$pred)

# IS CV fit
(xgb_fit$bestTune %>% left_join(xgb_fit$results))[c("RMSE", "Rsquared", "MAE")]

# OOS fit
rmse(dat_test[[target_variable]], dat_test$pred)
R2(dat_test$pred, dat_test[[target_variable]], formula = "traditional")
mae(dat_test[[target_variable]], dat_test$pred)


# With lambda ----

# Try different lambda values to reduce overfitting
lambdas <- (10 ^ (1:7)) / 2
res <- lapply(lambdas, function(lambda) {
  print(c("lambda:", lambda))

  xgb_fit_lambda <- train(
    model_formula(target_variable),
    data = dat_train,
    method = "xgbTree",
    tuneGrid = xgb_fit$bestTune,
    trControl = trainControl("none", predictionBounds = c(0, NA)),
    verbose = TRUE,
    metric = "RMSE",
    nthread = n_workers,
    verbosity = 0,
    watchlist = watchlist,
    early_stopping_rounds = 5,
    reg_lambda = lambda
  )

  # Predict on train and test data
  dat_train$pred <- predict(xgb_fit_lambda, dat_train)
  dat_test$pred <- predict(xgb_fit_lambda, dat_test)

  return(
    list(
      lambda = lambda,
      RMSE_is = rmse(dat_train[[target_variable]], dat_train$pred),
      RMSE_oos = rmse(dat_test[[target_variable]], dat_test$pred),
      R2_is = R2(dat_train$pred, dat_train[[target_variable]], formula = "traditional"),
      R2_oos = R2(dat_test$pred, dat_test[[target_variable]], formula = "traditional"),
      MAE_is = mae(dat_train[[target_variable]], dat_train$pred),
      MAE_oos = mae(dat_test[[target_variable]], dat_test$pred)
    )
  )
})

bind_rows(res) %>% as.data.frame # Inspect results
best_lambda <- bind_rows(res) %>%
  arrange(RMSE_oos) %>%
  dplyr::slice(1) %>%
  pull(lambda)


# Final model ----

# Estimate final model with the identified optimal lambda value and find optimal n_rounds with this value

xgb_fit_final <- train(
  model_formula(target_variable),
  data = dat_train,
  method = "xgbTree",
  tuneGrid = xgb_fit$bestTune,
  trControl = trainControl("none", predictionBounds = c(0, NA)),
  verbose = TRUE,
  metric = "RMSE",
  nthread = n_workers,
  verbosity = 0,
  watchlist = watchlist,
  early_stopping_rounds = 5,
  reg_lambda = best_lambda
)

# Optimal hyper parameters to be written to the optimal_hyper_parameters() function
xgb_fit_final$finalModel$best_ntreelimit # optimal value for nrounds
xgb_fit_final$bestTune # optimal values for everything except nrounds
best_lambda
