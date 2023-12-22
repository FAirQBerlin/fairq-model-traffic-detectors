#' Format date as character
#' e.g., 2022-07-29 01:00:00
#' @param date Date or PosixCT
#' @export
format_date <- function(date) {
  format(date, "%Y-%m-%d %H:%M:%S")
}
