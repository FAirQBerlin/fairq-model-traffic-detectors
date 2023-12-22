test_that("Package code is in line with our style conventions", {
  lintr::expect_lint_free(linters = INWTUtils::selectLinters())
})
