insert into {{ target_schema }}.{{ table }}
select * from {{ source_schema }}.{{ table }};
