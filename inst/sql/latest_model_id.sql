SELECT max(model_id) model_id FROM fairq_output.traffic_model_description tmd
WHERE depvar = '{{ target_variable }}'
AND tmd.model_id IN (SELECT model_id FROM traffic_model_object);
