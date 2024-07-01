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

set.seed(364)

# Set variables ----
# If DEV is TRUE, we work with a fraction of cases (= frac_if_dev)
model_name <- "march_24"
DEV <- Sys.getenv("DEV")
frac_if_dev <- 0.1
# Which target variable should be modeled?
# --> "q_kfz" for counted traffic of all vehicles volume/quantities
# --> "v_kfz" for average traffic speed of all vehicles
target_variable <- "q_kfz"

# Get data ----
dat <- get_data(target_variable, DEV, frac_if_dev)
print(max(dat$date_time))

# Train model ----
xgb_fit <- train(
  form = model_formula(target_variable),
  data = dat,
  method = "xgbTree",
  tuneGrid = optimal_hyper_parameters(target_variable),
  reg_lambda = optimal_lambda(target_variable),
  # fit one model to the entire training set:
  trControl = trainControl("none", predictionBounds = c(0, NA)),
  verbose = TRUE,
  nthread = detectCores() - 1
)

# Save model results ----
# So we can load them in another file and look at variable importance or make
# predictions
file_prefix <- paste0(format(Sys.Date(), "%y%m%d"), "_", target_variable, "_")
file_suffix <- if (DEV) "_dev" else ""
model_filename <- paste0(file_prefix,
                                 "traffic_model_full_period",
                                 file_suffix,
                                 ".xgb")

# In-sample model performance
pred <- make_predictions(xgb_fit$finalModel, dat, target_variable)
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

if (DEV){ # save DEV models locally
  xgb.save(xgb_fit$finalModel, file = model_filename)
} else { # save model to DB
  send_model_to_db(xgb_fit$finalModel, model_id, model_filename)
}
