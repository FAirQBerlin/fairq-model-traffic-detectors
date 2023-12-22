with det_observations as (
select
  mq_name,
  date_time,
  q_kfz_mq_hr,
  v_kfz_mq_hr,
  x det_x,
  y det_y
from
  fairq_features.traffic_det
)
select
  det.mq_name mq_name,
	det.date_time date_time,
	-- values we compute from the date refer to the time zone, so "hour 5" means 5 in Berlin
	-- however we can join tables by date even if they are in different time zones
	toDayOfWeek(det.date_time) day_of_week,
	toYear(det.date_time) year,
	toHour(det.date_time) hour,
	timeZoneOffset(det.date_time) == 3600 winter_time,
	det.q_kfz_mq_hr q_kfz,
	det.v_kfz_mq_hr v_kfz,
	det.det_x x,
	det.det_y y,
	fdt.type_school_holiday == 'Sommerferien' and fdt.type_school_holiday is not null as summer_holidays,
	fdt.type_school_holiday != 'Sommerferien' and fdt.type_school_holiday is not null as other_school_holidays,
	fdt.is_public_holiday is_public_holiday,
	fdt.doy_scaled day_of_year,
	str.strassenklasse_0 str_class_0,
	str.strassenklasse_I str_class_I,
	str.strassenklasse_II str_class_II,
	str.strassenklasse_III str_class_III,
	str.strassenklasse_IV str_class_IV,
	str.strassenklasse_V str_class_V,
	land.gewaesser as land_water,
	land.grauflaeche as land_grey,
	land.gruenflaeche as land_green,
	land.infrastruktur as land_infra,
	land.mischnutzung as land_mixed,
	land.wald as land_forest,
	land.wohnnutzung as land_living,
	buildings.density building_density,
	buildings.height building_height,
	traffic_vol.kfz_per_24h traffic_volume
from
	det_observations det
left join
  fairq_features.features_date_time fdt on (fdt.date_time = det.date_time)
-- add closest stadstruktur coordinates and data
left join
  fairq_features.coord_mapping_stadt_det cmsd on (det.det_x = cmsd.det_x and det.det_y = cmsd.det_y)
left join
  fairq_features.streets str on (stadt_x = str.x and stadt_y = str.y)
left join
  fairq_features.land_use land on (stadt_x = land.x and stadt_y = land.y)
left join
  fairq_features.traffic_volume traffic_vol on (stadt_x = traffic_vol.x and stadt_y = traffic_vol.y)
left join
  fairq_features.buildings on (stadt_x = buildings.x and stadt_y = buildings.y)
order by date_time, x, y;
