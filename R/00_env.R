#' env module controlling dev or prod envrironment for db
#' if ENV is not set, it will be set to DEV
#' if ENV is set to PROD, the "prod_" prefix will be returned to be used at db
#' @export
env <- modules::module({

  db <- function() {
    switch(Sys.getenv("ENV", unset = "DEV"),
           DEV = "",
           PROD = "prod_",
    )
  }

})
