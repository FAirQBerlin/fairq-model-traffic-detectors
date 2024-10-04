rm(list = ls(all.names = TRUE))

# Make sure to have latest package version installed:
# devtools::document()
# devtools::install()

library(caret)
library(dplyr)
library(fairqModelTrafficDetectors)
library(Metrics)
library(parallel)
library(jsonlite)
library("xgboost", lib.loc="~/R/x86_64-pc-linux-gnu-library/4.4/")
library(lubridate)

set.seed(932417)

# Set variables ----
# If DEV is TRUE, we work with a fraction of cases (= frac_if_dev)
# and less hyper parameter combinations
DEV <- Sys.getenv("DEV")
frac_if_dev <- (if (DEV) 0.003 else 1)

# Which target variable should be modeled?
# --> "q_kfz" for counted traffic of all vehicles volume/quantities
# --> "v_kfz" for average traffic speed of all vehicles
target_variable <- "q_kfz"

number_of_hyperparam_combinations <- 25
# Get grid of hyperparams
grid_hyperparam <- random_hpo_grid(number_of_hyperparam_combinations)
# Create formula
formula <- model_formula(target_variable)

# Get data
dat <- get_data(target_variable, DEV, frac_if_dev)

# Train-test split 12 weeks ago
split_date <- max(dat$date_time) - dweeks(12)
dat_train <- dat %>% filter(.data$date_time <= split_date)
dat_validation <- dat %>% filter(.data$date_time > split_date)

# Creating folds for cv
folds <- folds(dat_train)

# Extract features
features <- labels(terms(formula))

# Prepare the data in DMatrix format
dtrain <- make_DMatrix(dat_train, features = features, target_variable)

# Convert folds to a list where each fold is a vector of test indices
cv_folds_test <- lapply(folds, function(fold) {
  fold$test
})

cv_folds_train <- lapply(folds, function(fold) {
  fold$train
})

# Custom cross-validation function using xgb.cv
cv_results <- lapply(1:nrow(grid_hyperparam), function(i) {
  logging("hpo trial %s", i)
  set.seed(932417)
  params <- as.list(grid_hyperparam[i, ])
  cv_result <- xgb.cv(
    prediction = TRUE, # Return the test fold predictions
    params = params,
    data = dtrain,
    nrounds = grid_hyperparam[i, ]$nrounds,
    folds = cv_folds_test,
    train_folds = cv_folds_train,
    tree_method = "hist",
    metrics = "rmse",
    device = "cuda", # For GPU usage - if not available, CPU is used instead.
    early_stopping_rounds = 20
  )
  gc()
  return(cv_result)
})

logging("finished hpo")
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
    "_temp_CV_results_full_",
    ".RData"
  )
}
save.image(model_filename)

logging("Writing down the best set of HP as .json")
best_hyperparams_to_json(cv_results, target_variable)
logging("done with hpo")
optimal_hyperparams <- jsonlite::fromJSON(sprintf("inst/params/optimal_hyperparams_%s.json", target_variable))


logging("Fitting final model for test set evaluation")
# final model
final_model <- xgb.train(
  params = optimal_hyperparams,
  nrounds = optimal_hyperparams$nrounds,
  data = dtrain,
  verbose = 1
)

logging("predict on train set")
dat_train$predict <- predict(final_model, dtrain)
logging("train-rmse:  %s", rmse(dat_train$pred, dat_train[[target_variable]]))
logging("train-mae: %s", mae(dat_train$pred, dat_train[[target_variable]]))
logging("train-rsq: %s", R2(dat_train$pred, dat_train[[target_variable]], formula = "traditional"))

logging("predict on test set")
dvalidation <- make_DMatrix(dat_validation, features = features, target = target_variable)
dat_validation$pred <- predict(final_model, dvalidation)

# plot_pred_vs_obs(target_variable, dat_validation)
# plot_distri(target_variable, dat_validation)
# plot_resid_against_obs(target_variable, dat_validation)

logging("test-rmse: %s", rmse(dat_validation$pred, dat_validation[[target_variable]]))
logging("test-mae: %s", mae(dat_validation$pred, dat_validation[[target_variable]]))
logging("test-rsq: %s", R2(dat_validation$pred, dat_validation[[target_variable]], formula = "traditional"))
