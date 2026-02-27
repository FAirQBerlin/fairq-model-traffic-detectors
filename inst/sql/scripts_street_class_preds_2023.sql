WITH predicted_averages AS (
  SELECT
    x,
    y,
    avg(value) * 24 as kfz_per_24h_pred
  FROM traffic_model_predictions_2023
  GROUP BY x, y
)
SELECT
  tv.x as x,
  tv.y as y,
  tv.kfz_per_24h,
  pa.kfz_per_24h_pred,
  s.strassenklasse_0,
  s.strassenklasse_I,
  s.strassenklasse_II,
  s.strassenklasse_III,
  s.strassenklasse_IV,
  s.strassenklasse_V
FROM traffic_volume tv
INNER JOIN predicted_averages pa USING (x, y)
LEFT JOIN streets s USING (x, y)
WHERE tv.kfz_per_24h > 0
