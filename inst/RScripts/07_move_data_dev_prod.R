################################################################################
# This script transfers data from dev to prod after model-recalibration on dev #
# You need to insert the prod ETL user to the env file to make this script     #
# work!                                                                        #
#                                                                              #
# Author: Milan Flach                                                          #
# E-mail: milan.flach@inwt-statistics.de                                       #
################################################################################

rm(list = ls(all.names = TRUE))

# 00 Preparation ---------------------------------------------------------------
cat("System information:\n")
for (i in seq_along(sysinfo <- Sys.info()))
  cat(" ", names(sysinfo)[i], ":", sysinfo[i], "\n")
options(warn = 2)

library(fairqModelTrafficDetectors)
library(methods)
sessionInfo()

# 01 Start ETL -----------------------------------------------------------------
# futile.logger::flog.threshold(futile.logger::DEBUG)
tables = data_sources()
status <- transfer_tables_to_prod(tables)

q(save = "no", status = status)
