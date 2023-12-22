  select
    distinct det_x x,
    det_y y,
    scaling
  from
    fairq_raw.traffic_det_cross_sections_processed
    left join mapping_reprojection mr using(lat_int, lon_int)
    left join coord_mapping_stadt_det cmsd on(mr.x = cmsd.det_x and mr.y = cmsd.det_y)
    left join traffic_model_scaling tms on(cmsd.stadt_x = tms.x and cmsd.stadt_y = tms.y)
