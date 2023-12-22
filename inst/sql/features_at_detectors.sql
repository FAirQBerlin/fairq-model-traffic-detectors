with latest_traffic_date as (
select max(date_time) max_traffic_date from fairq_output.traffic_model_predictions_temporal_cv
)

select
  dt.date_time date_time,
	toDayOfWeek(dt.date_time) day_of_week,
	toYear(dt.date_time) year,
	toHour(dt.date_time) hour,
	timeZoneOffset(dt.date_time) == 3600 winter_time,
	det_x x,
	det_y y,
	dt.type_school_holiday == 'Sommerferien' and dt.type_school_holiday is not null as summer_holidays,
	dt.type_school_holiday != 'Sommerferien' and dt.type_school_holiday is not null as other_school_holidays,
	dt.is_public_holiday is_public_holiday,
	dt.doy_scaled day_of_year,
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
  fairq_features.coord_stadt_berlin stadt
-- Spatial features
inner join
  fairq_features.coord_mapping_stadt_det on (stadt.x = stadt_x and stadt.y = stadt_y)
left join
  fairq_features.streets str on (stadt.x = streets.x and stadt.y = streets.y)
left join
  fairq_features.land_use land on (stadt.x = land.x and stadt.y = land.y)
left join
  fairq_features.traffic_volume traffic_vol on (stadt.x = traffic_vol.x and stadt.y = traffic_vol.y)
left join
  fairq_features.buildings on (stadt.x = buildings.x and stadt.y = buildings.y)
-- Temporal features
cross join
  fairq_features.features_date_time dt
-- Query data from the last prediction in the target table until 12 weeks after today
cross join
 latest_traffic_date
where dt.date_time > latest_traffic_date.max_traffic_date
  and dt.date_time <= date_add(WEEK, 12, today())
order by x, y, date_time desc;