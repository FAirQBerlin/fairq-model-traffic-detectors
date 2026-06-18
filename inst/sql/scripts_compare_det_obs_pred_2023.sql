with obs as (
  select
  stadt_x x,
  stadt_y y,
  date_time date_time,
  mq_name mq_name,
  q_kfz_mq_hr
  from
  traffic_all_observations tdo
  inner join
  coord_mapping_stadt_det on (tdo.x = det_x and  tdo.y = det_y)
  where toYear(date_time) in (2023, 2024)
)
select
mq_name,
x,
y,
date_time,
value as pred,
q_kfz_mq_hr as obs
from traffic_model_predictions_2023
inner join obs using(x, y, date_time)
where model_id = '75'
  and toYear(date_time) in (2023, 2024)
  and (x, y) in (select stadt_x, stadt_y from coord_mapping_stadt_det)
