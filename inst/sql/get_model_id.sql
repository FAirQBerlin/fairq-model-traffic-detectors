select model_id from traffic_model_description
  where date_time = '{{date_time}}'
  and model_name = '{{model_name}}'
  and description = '{{json_description}}';
