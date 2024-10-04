#' Make predictions using a given model object
#'
#' @description Make predictions using a given model object, e.g., from the database
#' @param model_object a single xgb model_object, e.g. xgb_fit$final model or
#' an model object, retrieved from the database with retrieve_model_from_db()
#' @param dat data frame with the features
#' @param target_variable (character) "q_kfz" or v_kfz"
#'
#' @return vector of predictions
#' @export
make_predictions <- function(model_object, dat, target_variable){
  feature_names <- labels(terms(model_formula(target_variable)))
  predict(model_object, dat)
}

#' Latest model formula
#'
#' @param target_variable (character) "q_kfz" for counted traffic of all
#' vehicles volume/quantities, "v_kfz" for average traffic speed of all vehicles
#'
#' @return model formula
#' @export
model_formula <- function(target_variable) {
  if (target_variable == "q_kfz") {
    q_kfz ~ x + y + year + day_of_week + day_of_year + hour + winter_time +
      # holidays:
      summer_holidays + other_school_holidays + is_public_holiday +
      # amount of street classes in cell:
      str_class_0 + str_class_I + str_class_II + str_class_III + str_class_IV + str_class_V +
      # land use:
      land_water + land_grey + land_green + land_infra + land_mixed + land_forest + land_living +
      # builds:
      building_density + building_height +
      # traffic volume per 24 h:
      traffic_volume
  }
  else if (target_variable == "v_kfz") {
    v_kfz ~ x + y + year + day_of_week + day_of_year + hour + winter_time +
      # holidays:
      summer_holidays + other_school_holidays + is_public_holiday +
      # amount of street classes in cell:
      str_class_0 + str_class_I + str_class_II + str_class_III + str_class_IV + str_class_V +
      # land use:
      land_water + land_grey + land_green + land_infra + land_mixed + land_forest + land_living +
      # builds:
      building_density + building_height +
      # traffic volume per 24 h:
      traffic_volume
  } else {
    stop("target_variable must be either 'q_kfz' or 'v_kfz'")
  }
}


#' Grid for HPO random search
#'
#' Create a grid of hyper parameters with random values.
#' We use this instead of the built-in random search of caret because we
#' want to specify the distributions to draw from.
#' n_rounds is a fixed, large number because the function is meant to be
#' used in combination with early stopping.
#'
#' @param tune_length (int) number of rows for the grid, i.e., number of unique combinations
#' of hyper parameters
#'
#' @return data frame with random combination of hyper parameters
#' @export
random_hpo_grid <- function(tune_length) {
  grid <- data.frame(
    nrounds = 500,
    max_depth = sample(7:7, replace = TRUE, size = tune_length),
    eta = runif(tune_length, min = 0.15, max = 0.2),
    gamma = runif(tune_length, min = 5, max = 10),
    colsample_bytree = runif(tune_length,  min = 0.45, max = 0.55),
    min_child_weight = sample(10:20, size = tune_length, replace = TRUE),
    subsample = runif(tune_length, min = 0.5, max = 0.55),
    lambda = runif(tune_length, min = 10, max = 20),
    nthread = min(parallel::detectCores() - 1, 12),
    objective = "reg:squarederror"
  )
  logging(grid)
  return(grid)
}

#' @title Write data as DMatrix
#' @description Uses `xgb.DMatrix` from the `xgboost` Package to transform data to the correct format
#' @param dat Data to be rewritten
#' @param features Features to be included
#' @param target Targeted variable
#' @export
make_DMatrix <- function(dat, features, target) {
  xgb.DMatrix(data = as.matrix(dat[, features, with = FALSE]),
              label = dat[[target]]
  )
}

#' @title Make Folds for CV
#' @description Creates CV-Folds for usage in `xgb.cv`. The default can be changed to match your specific needs.
#' @param dat_train Training Date you want to split in folds
#' @param n_splits Number of splits
#' @param n_weeks The time range shifting with every new split
#' @export
folds <- function(dat_train, n_splits = 4, n_weeks = 12) {
  result <- list()
  split <- 0:(n_splits - 1)

  for (num in split) {
    max_date <- max(dat_train$date_time) - dweeks(n_weeks * (n_splits - num))
    min_date <- min(dat_train$date_time) + dweeks(n_weeks * num)
    train <- which(dat_train$date_time >= min_date & dat_train$date_time <= max_date)
    test <- which(dat_train$date_time > max_date & dat_train$date_time <= max_date + dweeks(n_weeks))
    single_split <- list(train = train, test = test)
    result[[as.character(num)]] <- single_split
  }

  return(result)
}

#' @title Storing optimal set of HP
#' @description Saves best set of HP as .json. It can be easily loaded from `inst/params`, where it is stored immediately after running the model.
#' @param cv_results List containing sublists of all HP combinations
#' @param target_variable Either "q_kfz" or "v_kfz"
#' @export
best_hyperparams_to_json <- function(cv_results, target_variable) {
  test_rmse_means <- sapply(cv_results, function(x) {
    x$evaluation_log$test_rmse_mean[nrow(x$evaluation_log)]
  })

  optimal_hyperparams <- cv_results[[which.min(test_rmse_means)]]$params
  optimal_hyperparams$silent <- NULL
  optimal_hyperparams$nrounds <- cv_results[[which.min(test_rmse_means)]]$early_stop$best_iteration
  optimal_hyperparams$rmse <- round(min(test_rmse_means), 2)

  file_name <- paste0("inst/params/optimal_hyperparams_", target_variable, ".json")
  write(jsonlite::toJSON(optimal_hyperparams, pretty = TRUE, auto_unbox = TRUE), file_name)
}
