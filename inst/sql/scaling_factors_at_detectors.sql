select distinct
    det_x x,
    det_y y,
    scaling
from
  coord_mapping_stadt_det cmsd
left join
  traffic_model_scaling tms on(cmsd.stadt_x = tms.x and cmsd.stadt_y = tms.y);
