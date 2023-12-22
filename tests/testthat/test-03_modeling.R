test_that("compute_avg_n_det() returns corrects numbers", {
  dat <- data.frame(
    date_time = as.POSIXct(
      c(
        # Detector 1
        "2020-01-01 01:00:00",
        "2020-01-01 02:00:00",
        "2020-01-01 03:00:00",
        # Detector 2
        "2020-01-01 02:00:00",
        "2020-01-01 03:00:00",
        # Detector 3
        "2020-01-01 03:00:00"
      )
    ),
    x = c(1, 1, 1, 2, 2, 3),
    y = c(1, 1, 1, 5, 5, 5)
  )

  # Detectors 2 and 3 have the same y coordinate, but the function should not care
  # 01:00: only 1 entry (coord 1, 1) -> 1
  # 02:00: 2 entries (coords 1, 1 and 3, 5) -> 2
  # 03:00: 3 entries
  # So the mean is 2
  res <- compute_avg_n_det(dat)
  expect_equal(res, 2)

  res_det_1 <-
    compute_avg_n_det(dat[1:3, ]) # only one detector
  expect_equal(res_det_1, 1)

  res_det_23 <-
    compute_avg_n_det(dat[4:6, ]) # one day with 2, one day with 3 detectors
  expect_equal(res_det_23, 1.5)
})
