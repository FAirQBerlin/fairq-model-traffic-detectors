WITH predicted_averages AS (
  SELECT
    x,
    y,
    avg(value) * 24 AS kfz_per_24h_pred
  FROM traffic_model_predictions_2023
  where toYear(date_time) == 2023
  and model_id == 75
  GROUP BY x, y
),
year_avgs AS (
  SELECT
    x,
    y,
    kfz_per_24h,
    kfz_per_24h_pred
  FROM fairq_features.traffic_volume
  INNER JOIN predicted_averages USING (x, y)
  where kfz_per_24h > 0
)
SELECT
  x,
  y,
  kfz_per_24h,
  kfz_per_24h_pred
FROM year_avgs;


