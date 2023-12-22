insert into traffic_model_scaling

with predicted_averages as (
  select
    x,
    y,
    avg(value) * 24 as kfz_per_24h_pred
  from
    traffic_model_predictions_2019
  group by x, y
),

year_avgs as (
  select
    x,
    y,
    kfz_per_24h,
    kfz_per_24h_pred
  from
    traffic_volume
  inner join
    predicted_averages using(x, y)
)

select
  x,
  y,
  kfz_per_24h,
  kfz_per_24h_pred,
  multiIf(
 kfz_per_24h / kfz_per_24h_pred > 5,
 5.0,
 kfz_per_24h <= 0.001, -- means zero, due to numerical issues.
 0.0,
 kfz_per_24h > 0.001 and kfz_per_24h / kfz_per_24h_pred < 0.1,
 0.1,
 kfz_per_24h / kfz_per_24h_pred
  ) as scaling
from
  year_avgs;
