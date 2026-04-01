select count(*) >= 24 * 365 * 118662 as all_preds_arrived -- full, cropped Berlin raster has 360765 cells
from traffic_model_predictions_2023;
