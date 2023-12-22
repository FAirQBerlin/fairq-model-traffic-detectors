#' Get data for modelling
#'
#' @param target_variable (character) target value for model.
#' "q_kfz" for counted traffic of all vehicles volume/quantities,
#' "v_kfz" for average traffic speed of all vehicles.
#' @param dev (bool) If TRUE we work with less cases and less hyper parameter
#' combinations. Usually filled via Sys.getenv("DEV")
#' @param sample_fract (numeric) share of data to be used via sampling for model
#'
#' @return (data.frame) df that contains target variable and all predictors
#'
#' @export
get_data <- function(target_variable, dev, sample_fract = 0.002){

  date_time <- x <- y <- NULL # fix linting

  if (dev) {
    # Load data from file and take a sample
    load("datPrep.RData")
    dat <- dat %>%
      filter(.data[[target_variable]] != -1) %>%
      sample_frac(sample_fract) %>%
      arrange(date_time, x, y)
  } else {
    # Load data from DB
    dat <- send_query("traffic") %>%
      filter(.data[[target_variable]] != -1) %>%
      arrange(date_time, x, y)
  }

  return(dat)
}
