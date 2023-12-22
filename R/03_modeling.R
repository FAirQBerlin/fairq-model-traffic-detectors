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
    max_depth = sample(7:10, replace = TRUE, size = tune_length),
    eta = runif(tune_length, min = 0.001, max = 0.6),
    gamma = runif(tune_length, min = 0, max = 10),
    colsample_bytree = runif(tune_length,  min = 0.7, max = 1),
    min_child_weight = sample(0:20, size = tune_length, replace = TRUE),
    subsample = runif(tune_length, min = 0.7, max = 1)
  )
  logging(grid)
  return(grid)
}


#' Optimal hyper parameters
#'
#' As identified using temporal CV
#'
#' @param target_variable (character) "q_kfz" for counted traffic of all
#' vehicles volume/quantities, "v_kfz" for average traffic speed of all vehicles
#'
#' @return data frame with optimal hyper parameters
#' @export
optimal_hyper_parameters <- function(target_variable) {
  if (target_variable == "q_kfz") {
    data.frame(
      nrounds = 303,
      max_depth = 9,
      eta = 0.3048174,
      gamma = 1.588561,
      colsample_bytree = 0.8311579,
      min_child_weight = 1,
      subsample = 0.8877896
    )
  } else if (target_variable == "v_kfz") {
    data.frame(
      nrounds = 117,
      max_depth = 10,
      eta = 0.1250001,
      gamma = 8.474384,
      colsample_bytree = 0.7686541,
      min_child_weight = 12,
      subsample = 0.9978663
    )
  } else {
    stop("target_variable needs to be either 'q_kfz' or 'v_kfz'")
  }
}


#' Optimal lambdas
#'
#' As identified using temporal CV
#'
#' @param target_variable (character) "q_kfz" for counted traffic of all
#' vehicles volume/quantities, "v_kfz" for average traffic speed of all vehicles
#'
#' @return integer with best lambda values, identified for the above hyper parameters
#' @export
optimal_lambda <- function(target_variable) {
  if (target_variable == "q_kfz") {
    500000
  } else if (target_variable == "v_kfz") {
    5
  } else {
    stop("target_variable needs to be either 'q_kfz' or 'v_kfz'")
  }
}


#' Get average number of unique detectors per hour
#' @description For temporal CV we need the number of detectors per hour to multiply it with
#' the window width etc.
#' This number varies from hour to hour, however this won't affect the results very much so we
#' just use the average number of detectors per hour.
#' @param dat data.frame with columns date_time, x, and y
#' @export
compute_avg_n_det <- function(dat) {
  dat %>%
    group_by(.data$date_time) %>%
    summarise(n_dets = n_distinct(paste(.data$x, .data$y))) %>%
    ungroup %>%
    summarise(mean(.data$n_dets)) %>%
    pull()
}
