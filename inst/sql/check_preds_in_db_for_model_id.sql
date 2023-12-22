select count(*) in (
24 * 113 * 360765 + 360765, -- normal
24 * 113 * 360765 + 2 * 360765, -- summer time to winter time -> one hour more
24 * 113 * 360765 -- winter time to summer time -> one hour less
) as all_preds_arrived
-- full, cropped Berlin raster has 360765 cells; 24 hours; 16 weeks + yesterday = 113 days; plus current hour
-- at time change: 1 hour more or less
from traffic_model_predictions_grid
where model_id = {{model_id}};
