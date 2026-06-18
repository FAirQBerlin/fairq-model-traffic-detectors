# Copy TEU_pairs.ods from tmp_fairq/teu-vergleich into input_data/
# install.packages("readODS")
# rm(list=ls())
library(fairqDbtools)
library(dplyr)
library(readODS)
library(tidyr)

det_pairs <- read_ods("input_data/TEU_pairs.ods")

det_pairs <- det_pairs %>%
  mutate(
    valid = 1 - valid, # correct logic
    one_way_street = as.integer(one_way_street), # int
    valid          = as.integer(valid)
  )

# check duplicates
dup_valid <- duplicated(det_pairs)
any(dup_valid)

# make long format
det_long <- det_pairs %>%
  mutate(self = mq_prime) %>%
  tidyr::pivot_longer(
    cols = c(self, mq_name),
    names_to  = "which",
    values_to = "mq_name"
  ) %>%
  mutate(which = factor(which, levels = c("self", "mq_name"))) %>%
  arrange(mq_prime, which) %>%
  select(mq_prime, mq_name, dplyr::everything(), -which) %>%
  as.data.frame()

q <- unique(det_long)
rownames(q) <- NULL
# send to db
send_data(q, "det_pairs", database = Sys.getenv("DB_SCHEMA_SOURCE"), mode = "replace")

# check if its the same frame
q_db <- send_query("select * from fairq_features.det_pairs;")
testthat::expect_equal(q_db, q)

