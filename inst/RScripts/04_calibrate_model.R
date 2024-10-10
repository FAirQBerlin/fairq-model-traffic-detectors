# Estimate a model on the full data set and write predictions to the database
# We use the optimal hyper parameters we identified using temporal CV
# These predictions are used as input in the pollutant model;
# in addition, we can use them for OOS-validation of the traffic model as soon as the next data
# are available

rm(list = ls(all.names = TRUE))

# Make sure to have latest package version installed:
# devtools::document()
# devtools::install()

library(caret)
library(dplyr)
library(fairqModelTrafficDetectors)
library(fairqDbtools)
library(Metrics)
library(parallel)
library(xgboost)

sessionInfo()

set.seed(9127364)

args <- R.utils::commandArgs(
  trailingOnly = TRUE,
  asValues = TRUE,
  defaults = list(TARGET_VARIABLE="q_kfz") # or v_kfz
)
target_variable <- args$TARGET_VARIABLE
logging("calibrating model for target variable %s", target_variable)

# Set variables ----
# If DEV is TRUE, we work with a fraction of cases (= frac_if_dev)
model_name <- format(Sys.Date(), "%y%m%d")
DEV <- Sys.getenv("DEV")
frac_if_dev <- 0.1
formula <- model_formula(target_variable)

logging("Getting data ----")
dat <- get_data(target_variable, DEV, frac_if_dev)
print(max(dat$date_time))

# Extract features
features <- labels(terms(formula))

# Make as DMatrix
ddat <- make_DMatrix(dat, features = features, target_variable)

# Load optimal HP
optimal_hyperparams <- jsonlite::fromJSON(sprintf("inst/params/optimal_hyperparams_%s.json", target_variable))

logging("Training model ----")
xgb_fit <- xgb.train(
  params = optimal_hyperparams,
  nrounds = optimal_hyperparams$nrounds,
  data = ddat,
  verbose = 1
)

# Save model results ----
# So we can load them in another file and look at variable importance or make
# predictions
file_prefix <- paste0(format(Sys.Date(), "%y%m%d"), "_", target_variable)
file_suffix <- if (DEV) "_dev" else ""
model_filename <- paste0(file_prefix,
                                 "traffic_model_full_period",
                                 file_suffix,
                                 ".xgb")

# In-sample model performance
pred <- make_predictions(dat, xgb_fit, target_variable)
rmse(dat[[target_variable]], pred)
R2(pred, dat[[target_variable]], formula = "traditional")
mae(dat[[target_variable]], pred)

# Write predictions to DB ----
# Model description
model_descr <- model_description_for_db(
  xgb_fit = xgb_fit,
  target_variable = target_variable,
  dat_train = dat,
  dat = dat,
  model_name = model_name
)
model_id <- model_descr$model_id

send_data(model_descr, "traffic_model_description", mode = "replace")
logging("Model description sent to DB for model_id %s", model_id)

if (DEV){ # save DEV models locally
  xgb.save(xgb_fit, fname = model_filename)
  logging("Model saved locally with filename %s", model_filename)
} else { # save model to DB
  send_model_to_db(xgb_fit, model_id, model_filename)
  logging("Model saved to DB for model_id %s", model_id)
}

logging("Model calibration done")
