# fairq-model-traffic-detectors

This repository contains R code to estimate an XGBoost model forecasting traffic
amount and speed.


## How to get started

- Create an .Renviron file in the project folder, see `.Renviron_template` for 
the structure
   - If the environment variable DEV is set to true, the data is loaded from a file
instead of the database to save time. In addition, the model is estimated on
a sample.
- Build the R package
- Create database as described in https://github.com/fairqBerlin/fairq-data/tree/public/inst/db (schemas fairq_raw and fairq_features)


## Most important files

- `inst/RScripts/01_prep_data.R`: This script retrieves all data from the 
database and stores it in an RData file. This script must be run once to save 
the data that will be used in the dev mode, in order to save time.
- `inst/RScripts/02_temporal_cv_hyper_tuning.R`: This script tunes 
hyperparameters and uses a time split to compute model performance metrics.
- `inst/RScripts/03_spatial_cv.R`: This script computes model performance 
metrics based on a spatial split.
-  `inst/RScripts/04_calibrate_model_and_make_predictions.R`: This script fits 
the model on complete data and makes predictions on various datasets (see below 
for details).
- `inst/RScripts/05_shap.R`: This script loads a model stored in script 04 and 
generates Shapley plots, which show variable importance and the shape of 
relationships.


## Input and output

### Input

- Database, schema `fairq_features`

### Output

- Database, schemas `fairq_features` and `fairq_output`


## Procedure for new traffic data

Traffic data arrives monthly as a csv file on https://api.viz.berlin.de/daten/verkehrsdetektion.

1. Import new data using https://github.com/fairqBerlin/fairq-data-traffic-detectors/blob/public/inst/RScripts/main.R
  - Populate the fairq_raw.traffic_det_observations table
  - No gap filling is applied here because the data is too sparse and we don't have any lags in the model anyway
  - Create a data validation report and send it to stakeholders
2. Calculate new predictions for number of vehicles on dev using script https://github.com/fairqBerlin/fairq-model-traffic-detectors/blob/public/inst/RScripts/04_calibrate_model_and_make_predictions.R, which includes:
  - a.) Predictions at detectors in the future -> model evaluation
  - b.) Predictions at pollutant measurement stations for entire past -> training of pollutant model
  - c.) Predictions on entire Berlin grid in the future -> input for pollutant model predictions
  - d.) Predictions on entire Berlin grid for year 2019 and based on that, calculation of rescaling factors using traffic volume map
3. Calculate new predictions for vehicle speed on dev using script https://github.com/fairqBerlin/fairq-model-traffic-detectors/blob/public/inst/RScripts/04_calibrate_model_and_make_predictions.R (predictions for 2019 are not created for speed because we don't need rescaling for it)
4. Retrigger Kubernetes job for pollutant model training (dev)
5. Transfer traffic model predictions to prod using `inst/R_Code/06_move_data_dev_prod` after checking that it's working on dev
6. Retrigger Kubernetes job for pollutant model training (prod)


## Credentials

-   Create `.Renviron` file in root directory and fill according to `.Renviron_template`.
