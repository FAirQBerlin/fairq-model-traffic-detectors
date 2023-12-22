# Extract model input data from db and save them as Rdata file to save time during development

# Make sure to have latest package version installed:
# devtools::document()
# devtools::install()

library(fairqDbtools)
dat <- send_query("traffic")
save(file = "datPrep.RData", dat)
