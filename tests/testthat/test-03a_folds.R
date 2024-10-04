library(lubridate)

n_groups <- 5
start_date <- ymd_hms("2020-01-01 00:00:00")
end_date <- start_date + weeks(2)
all_times <- seq(start_date, end_date, by = "hour")

sample_groups <- function() {
  n <- sample(2:5, 1)
  sample(1:n_groups, n)
}

dat_train <- do.call(rbind, lapply(all_times, function(time) {
  groups <- sample_groups()
  data.frame(
    date_time = rep(time, length(groups)),
    mq_name = groups,
    x = runif(length(groups)),
    y = runif(length(groups)),
    target = runif(length(groups))
  )
}))

n_splits <- 4 # Four splits, which is default in folds() but needed elsewhere
n_weeks <- 1/7 # Only one day as the shifting size as the data.frame is much smaller

res <- folds(dat_train, n_splits, n_weeks)

test_that("Tests if the output has the correct number of folds and correct content", {
  expect_equal(length(res), 4)
  expect_true(all(vapply(res, function(x) all(c("train", "test") %in% names(x)), logical(1))))
})

test_that("Each fold is non-empty", {
  expect_true(all(vapply(res, function(x) length(x$train) > 0 && length(x$test) > 0, logical(1))))
})

test_that("Train and test indices are non-intersecting sets", {
  expect_true(all(vapply(res, function(x) length(intersect(x$train, x$test)) == 0, logical(1))))
})

test_that("Examples are sorted by time", {
  expect_true(all(vapply(res, function(x) all(diff(dat_train$date_time[x$train]) >= 0) && all(diff(dat_train$date_time[x$test]) >= 0), logical(1))))
})

test_that("Every datapoint lies either in a test or a train set", {
  covered_indices <- unlist(lapply(res, function(x) c(x$train, x$test)))
  expect_equal(length(unique(covered_indices)), nrow(dat_train))
})

# We compare differences of first indices of a preceding and an actual train split
test_that("Splits are shifted correctly by n_weeks", {
  all_true <- TRUE
  for (num in 1:(n_splits - 1)) {
    if (difftime(dat_train[res[[num + 1]]$train[1], ]$date_time, dat_train[res[[num]]$train[1], ]$date_time, units = "weeks") != n_weeks) {
      all_true <- FALSE
      break
    }
  }
  expect_true(all_true)
})
