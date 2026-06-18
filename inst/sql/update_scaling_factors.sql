insert into traffic_model_scaling

with predicted_averages as (
  select
    x,
    y,
    avg(value) * 24 as kfz_per_24h_pred
  from
    traffic_model_predictions_2023
  group by x, y
),
year_avgs as (
  select
    x,
    y,
    kfz_per_24h,
    kfz_per_24h_pred,
    (strassenklasse_V > 0
      and strassenklasse_IV <= 0
      and strassenklasse_III <= 0
      and strassenklasse_II <= 0
      and strassenklasse_I <= 0
      and strassenklasse_0 <= 0) as is_exclusive_V
  from
    traffic_volume
  inner join
    predicted_averages using(x, y)
  inner join
    streets using(x, y)
  where kfz_per_24h > 0
),
scaling_V_factor as (
  select avg(kfz_per_24h / kfz_per_24h_pred) as scaling_V
  from year_avgs
  where is_exclusive_V
)
select
  x,
  y,
  kfz_per_24h,
  kfz_per_24h_pred,
  multiIf(
    kfz_per_24h <= 0.001, 0.0,
    is_exclusive_V, scaling_V,
    1.0
  ) as scaling
from
  year_avgs
cross join
  scaling_V_factor;
