library(testthat)
library(lintr)
library(fairqModelTrafficDetectors)

Sys.setenv(NOT_CRAN = "true")

test_check("fairqModelTrafficDetectors")
