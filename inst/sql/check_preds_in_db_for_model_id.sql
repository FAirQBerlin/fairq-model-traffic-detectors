select count(*) as n_preds
from traffic_model_predictions_grid final
where model_id = {{model_id}}
and date_time >= '{{start_time}}' - interval 1 DAY
and date_time <= date_add(WEEK, 5, '{{start_time}}');
