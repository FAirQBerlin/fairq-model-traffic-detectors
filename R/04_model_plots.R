#' Plot predicted against observed values
#'
#' @param target_variable (character) "q_kfz" for counted traffic of all
#' vehicles volume/quantities, "v_kfz" for average traffic speed of all vehicles
#' @param dat_test df with columns pred and target_variable
#'
#' @export
plot_pred_vs_obs <- function(target_variable, dat_test) {
  ggplot(dat_test) +
    geom_point(aes_string(x = target_variable, y = "pred"),
               size = 1,
               alpha = 0.5) +
    geom_abline(col = "blue") +
    labs(title = paste0(target_variable,
                        " - Predicted against observed values"),
         subtitle = paste(nrow(dat_test), "observations"))
}

#' Plot distribution of predicted vs. observed values
#'
#' @param target_variable (character) "q_kfz" for counted traffic of all
#' vehicles volume/quantities, "v_kfz" for average traffic speed of all vehicles
#' @param dat_test df with columns pred and target_variable
#' @export
plot_distri <- function(target_variable, dat_test) {
  ggplot(dat_test) +
    geom_histogram(aes_string(x = "pred"), fill = "blue") +
    geom_histogram(aes_string(x = target_variable), alpha = 0.8) +
    labs(
      title = paste0(target_variable,
                     " - Distribution of predicted vs. observed values"),
      subtitle = paste(
        "predicted = blue; observed = grey;",
        nrow(dat_test),
        "observations"
      )
    )
}


#' Plot residuals against observed values
#'
#' @param target_variable (character) "q_kfz" for counted traffic of all
#' vehicles volume/quantities, "v_kfz" for average traffic speed of all vehicles
#' @param dat_test df with columns pred and target_variable
#' @export
plot_resid_against_obs <- function(target_variable, dat_test) {
  dat_test$resid <- dat_test[[target_variable]] - dat_test[["pred"]]
  ggplot(dat_test) +
    geom_point(aes_string(x = target_variable, y = "resid"), alpha = 0.5) +
    geom_hline(yintercept = 0) +
    labs(
      title = paste0(target_variable,
                     " - Residuals vs. observed values"),
      subtitle = paste(nrow(dat_test), "observations"),
      x = target_variable,
      y = "residual"
    )
}
