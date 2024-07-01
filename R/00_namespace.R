#' @importFrom base64enc base64encode base64decode
#' @importFrom dplyr %>% any_of arrange bind_rows filter group_by inner_join left_join mutate
#' n_distinct pull right_join sample_frac select summarise ungroup
#' @importFrom fairqDbtools check_for_replacing_merge_tree creds optimize_table_final send_data send_query
#' @importFrom futile.logger flog.info
#' @importFrom ggplot2 aes_string geom_abline geom_histogram geom_hline geom_point ggplot labs
#' @importFrom rjson toJSON
#' @importFrom rlang .data
#' @importFrom stats lag predict runif terms
#' @importFrom timeDate holiday
#' @importFrom tidyselect any_of
#' @importFrom xgboost xgb.load xgb.save xgb.DMatrix
NULL
globalVariables("DEV")
