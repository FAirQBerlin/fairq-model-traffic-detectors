create temporary table coord_kfz_counts as
select 52.51792 as lat, 13.37813 as lon, 'Dorotheenstraße (östl. Ebertstraße) (Mitte, 10555)' as bez;
 insert into coord_kfz_counts values (52.48791, 13.37319, 'Monumentenstraße (Monumentenbrücke) (Schöneberg, 10829)');
 insert into coord_kfz_counts values (52.49246, 13.37181, 'Yorckstraße (westl. Katzbachstraße) (Kreuzberg, 10965)');
 insert into coord_kfz_counts values (52.4968, 13.2893, 'Kurfürstendamm (Höhe S-Bhf. Halensee) (Wilmersdorf, 10711)');
 insert into coord_kfz_counts values (52.47985, 13.3118, 'Mecklenburgische Straße (südl. Rudolstädter Straße) (Wilmersdorf, 14197)');
 insert into coord_kfz_counts values (52.513, 13.28747, 'Knobelsdorffstraße (westl. Sophie-Charlotten-Straße) (Charlottenburg, 10585)');
 insert into coord_kfz_counts values (52.5064, 13.2824, 'Neue Kantstraße (Ostpreußenbrücke) (Charlottenburg, 14057)');
 insert into coord_kfz_counts values (52.50667, 13.38593, 'Wilhelmstraße (südl. Zimmerstraße) (Kreuzberg, 10963)');
 insert into coord_kfz_counts values (52.47344, 13.36511, 'Sachsendamm (östl. Lotte-Laserstrin-Straße (Bahnbrücke)) (Schöneberg, 12103)');
 insert into coord_kfz_counts values (52.4873, 13.4518, 'Elsenstraße (nördl. Heidelberger Straße) (Neukölln, 12435)');
 insert into coord_kfz_counts values (52.46191, 13.47774, 'Sonnenallee (südl. Fritzi-Massary-Straße) (Neukölln, 12437)');
 insert into coord_kfz_counts values (52.44569, 13.36768, 'Ringstraße (Teubertbrücke) (Tempelhof, 12105)');
 insert into coord_kfz_counts values (52.4734, 13.54845, 'Rudolf-Rühl-Allee [ehem. Köpenicker A.] (südl. Verl. Waldowallee) (Köpenick, 12459)');
 insert into coord_kfz_counts values (52.44297, 13.35392, 'Attilastraße - Kaiser-Wilhelm-Straße (Sieversbrücke) (Steglitz, 12247)');
 insert into coord_kfz_counts values (52.44515, 13.33991, 'Siemensstraße (Siemensbrücke) (Steglitz,12247)');
 insert into coord_kfz_counts values (52.52472, 13.24501, 'Rominter Allee (südl. Charlottenburger Chaussee) (Ruhleben, 14052)');
 insert into coord_kfz_counts values (52.55944, 13.22484, 'Daumstraße (Spandau, 13599)');
 insert into coord_kfz_counts values (52.56477, 13.39383, 'Wollankstraße (Höhe S-Bhf. Wollankstraße) (Wedding, 13359)');
 insert into coord_kfz_counts values (52.5976, 13.3731, 'Wilhelmsruher Damm (westl. Uhlandstraße) (Rosenthal, 13158)');
 insert into coord_kfz_counts values (52.5434, 13.61984, 'Louis-Lewin-Straße (südl. Berliner Straße) (Hellersdorf, 12629)');
 insert into coord_kfz_counts values (52.42492, 13.5569, 'Adlergestell (Stelling-Janitzky-Brücke, Teltowkanal) (Treptow, 12489)');
 insert into coord_kfz_counts values (52.42754, 13.40592, 'Quarzweg (östl. Ankogelweg) (Tempelhof, 12349)');
 insert into coord_kfz_counts values (52.4214, 13.5169, 'Neudecker Weg (nördl. August-Froehlich-Str.) (Rudow, 12355)');
 insert into coord_kfz_counts values (52.48009, 13.2849, 'Franzensbader Straße östl. Berkaer Straße (Charlottenburg-Wilmersdorf, 14193)');
 insert into coord_kfz_counts values (52.6016, 13.286, 'Hermsdorfer Damm (östl. A111) (Tegel, 13507)');
 insert into coord_kfz_counts values (52.5507, 13.46183, 'Berliner Allee in Höhe Hausnr. 125 (Weißensee, 13088)');

 create temporary table all_element_nr as (
-- get the distances between the kfz_counts lon, lat and the grid cells lon, lat
with dists as (
select
	bez,
	x as x_grid,
	y as y_grid,
	lon,
	lat,
	geoDistance(lon_int / 100000,
	lat_int / 100000,
	lon,
	lat) as dist
from
	fairq_features.coord_mapping_stadt_reprojection
cross join
  coord_kfz_counts
),
-- get the minimum distance for each lon, lat pair - this is the grid cell where the kfz_count has taken place
grid_cells_with_counting as (
select
	bez,
	argMin((x_grid,
	y_grid),
	dist).1 as x,
	argMin((x_grid,
	y_grid),
	dist).2 as y
from
	dists
group by
	lon,
	lat,
	bez
),
all_element_nr as (
select
	bez,
	cmss.element_nr,
	strassenname
from
	grid_cells_with_counting
left join
 fairq_features.coord_mapping_stadt_streets cmss on
	x = stadt_x
	and y = stadt_y
left join
 fairq_raw.stadtstruktur_network_streets sns on
	cmss.element_nr = sns.element_nr
)
select
	bez,
	cmss.element_nr,
	strassenname,
	countSubstrings(bez,
	strassenname) > 0 strname_match
FROM
	all_element_nr
settings join_use_nulls = 1
);

create temporary table relevant_coords as (
select
	cmss.element_nr,
	bez,
	stadt_x x,
	stadt_y y
from
	all_element_nr
left join
fairq_features.coord_mapping_stadt_streets on
	cmss.element_nr = element_nr
where
	strname_match = 1
);

create temporary table unscaled_preds_2022 as (
select
	date_time,
	x,
	y,
	value as pred
from
	fairq_features_jan.jba_traffic_model_predictions_grid
where
	toDate(date_time) in ('2022-05-31')
);

create temporary table unscaled_preds_2023 as (
select
	date_time,
	x,
	y,
	value as pred
from
	fairq_features.traffic_model_predictions_grid
where
	toDate(date_time) in ('2023-05-04', '2023-06-28')
	and model_id = 21
);



create temporary table scaled_preds_2022 as (
select 
  date_time,
  x ,
  y,
 toNullable(scaling * pred) as pred
from 
 unscaled_preds_2022
inner join 
 fairq_features_jan.traffic_model_scaling using(x, y)
);

create temporary table scaled_preds_2023 as (
select 
  date_time,
  x ,
  y,
 toNullable(scaling * pred) as pred
from 
 unscaled_preds_2023
inner join 
 traffic_model_scaling using(x, y)
);


create temporary table scaled_preds as (
select 
  date_time,
  x ,
  y,
  pred
from 
scaled_preds_2022
union all 
select 
  date_time,
  x ,
  y,
  pred
from 
scaled_preds_2023
);

select
	date_time,
	cmss.element_nr,
	bez,
	avg(pred) pred
from
	 scaled_preds
left join
relevant_coords
		using(x,
	y)
where
	(x,
	y) in (
	select
		toInt64(x),
		toInt64(y)
	from
		relevant_coords)
group by
	date_time,
	cmss.element_nr,
	bez;
