library(fairqDbtools)
library(fairqModelTrafficDetectors)
library(dplyr)

# devtools::load_all()

# rm(list=ls())
data <- send_query("traffic")

# check how many data points are pairwise
data_pairs <- data %>%
  filter(!is.na(q_kfz)) %>%
  group_by(date_time, q_kfz) %>%
  filter(n() >= 2) %>%
  ungroup() %>%
  arrange(date_time, q_kfz, mq_name)

nrow(data_pairs) / nrow(data) # if close to 1, despite some one way streets, our data is pairwise in q_kfz.
