test_that("prep_preds_for_db prepares data frame correctly", {
  df <-
    data.frame(
      date_time = as.POSIXct(c("2022-01-02", "2022-01-03")),
      x = c(1, 2),
      y = c(3, 4),
      value = c(17, 18)
    )
  expected <- data.frame(
    model_id = rep(99, 2),
    date_time = as.POSIXct(c("2022-01-02", "2022-01-03")),
    x = c(1, 2),
    y = c(3, 4),
    value = c(17, 18)
  )
  res <- prep_preds_for_db(df, 99)
  expect_equal(colnames(res),
               c("model_id",
                 "date_time",
                 "x",
                 "y",
                 "value"))
  expect_equal(res, expected)
})


test_that("prep_preds_for_db works with model_ID NULL", {
  df <-
    data.frame(
      date_time = as.POSIXct(c("2022-01-02", "2022-01-03")),
      x = c(1, 2),
      y = c(3, 4),
      value = c(17, 18)
    )
  expected <- data.frame(
    date_time = as.POSIXct(c("2022-01-02", "2022-01-03")),
    x = c(1, 2),
    y = c(3, 4),
    value = c(17, 18)
  )
  res <- prep_preds_for_db(df, NULL)
  expect_equal(colnames(res),
               c("date_time",
                 "x",
                 "y",
                 "value"))
  expect_equal(res, expected)
})


test_that("comma_separated_chunks works correctly", {
  expect_equal(comma_separated_chunks(c(3, 6, 5, 7, 7), chunk_length = 2),
               list(`1` = "3, 6", `2` = "5, 7", `3` = "7"))

  expect_equal(comma_separated_chunks(c(2, 1), chunk_length = 3),
               list(`1` = "2, 1"))

  expect_equal(comma_separated_chunks(c(2, 1, 99, 2), chunk_length = Inf),
               list(`0` = "2, 1, 99, 2"))
})
