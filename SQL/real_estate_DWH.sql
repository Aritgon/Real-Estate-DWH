-- checking datatypes of columns.
select column_name, data_type
from information_schema.columns
where table_name = 'real_estate';

-- date_recorded is still text format.
alter table real_estate
alter column date_recorded type date
using date_recorded::date;

alter table real_estate
rename column assessed_outliers to assessed_outlier;

-- lets start date ware housing for smoother EDAs and powerBI connection.
-- we will build a star schema for better powerBI data modelling.

-- The schema tables will be four in count.
-- dim_property(property_id(auto increment, PK), property_type, residential_type)
-- dim_location(location_id(auto increment, PK), town, address, town_outlier)
-- dim_date(date_id(PK, FK to date_recorded in fact table), day, month, month_name, quarter, year, week, day_of_week, day_name, is_weekend)
-- fact_property_sales(fact_id(PK, auto_increment), property_id(FK), location_id(FK), list_year, date_recorded(FK to date_id), assessed_value, sale_amount, sales_ratio, assessed_vs_sales_pct, assessed_outlier, sale_amount_outlier)

-- lets start data_warehouse.
-- 1 create and populate dim_property.
drop table if exists dim_property cascade;
create table dim_property (
	property_id serial primary key, -- PK
	property_type text,
	residential_type text
);

-- lets populate dim_property.
insert into dim_property (property_type, residential_type) 
select distinct
	property_type,
	residential_type
from real_estate;

-- dim property is populated.

-- 2 create and populate dim_location.
drop table if exists dim_location cascade;
create table dim_location (
	location_id serial primary key, -- PK
	town text,
	address text,
	town_outlier text
);

-- populate dim_location.
insert into dim_location (town, address, town_outlier)
select distinct
	town,
	address,
	town_outlier
from real_estate;

-- dim_location is populated.

-- 3 create and populate dim_date.
drop table if exists dim_date cascade;
create table dim_date (
	date_id date primary key, -- PK and FK to fact_property(date_recorded)
	day INT,
	month INT,
	month_name text,
	quarter INT,
	year INT,
	week INT,
	day_of_week INT,
	day_name text,
	is_weekend bool
);

-- lets populate the dim_date.

insert into dim_date (date_id, day, month, month_name, quarter, year, week, day_of_week, day_name, is_weekend)
select
	rn::date as date_id, -- PK(FK to real_estate date_recorded)
	extract(day from rn) as day,
	extract(month from rn) as month,
	to_char(rn, 'month') as month_name,
	extract(quarter from rn) as quarter,
	extract(year from rn) as year,
	extract(week from rn) as week,
	extract(ISODOW from rn) as day_of_week,
	to_char(rn , 'day') as day,
	case
		when extract(DOW from rn) in (6,7) then True
		else False
	end as is_weekend
from generate_series(
	(select min(date_recorded) from real_estate),
	(select max(date_recorded) from real_estate),
	interval '1 day'
)as rn;

select	
	column_name
from information_schema.columns
where table_name = 'real_estate';

-- lets create the fact_property table.
drop table if exists fact_property cascade;
create table fact_property (
	fact_id serial primary key,
	property_id INT, -- FK to dim_property.
	location_id INT, -- FK to dim_location.
	list_year INT, 
	date_recorded date, -- Fk to dim_date.
	
	assessed_value INT,
	sale_amount INT,
	sales_ratio float,
	assessed_vs_sales_pct float,
	assessed_outlier text,
	sale_amount_outlier text,
	
	foreign key (property_id) references dim_property(property_id), -- FK(property_id)
	foreign key (location_id) references dim_location(location_id), -- FK(location_id)
	foreign key (date_recorded) references dim_date(date_id) -- FK(date_recorded)
); 

-- lets join other dim tables and populate the fact_property table.
insert into fact_property (property_id, location_id, list_year, date_recorded, assessed_value, sale_amount, sales_ratio, assessed_vs_sales_pct, assessed_outlier, sale_amount_outlier)
select
	b.property_id,
	c.location_id,
	a.list_year,
	d.date_id,
	a.assessed_value,
	a.sale_amount,
	a.sales_ratio,
	a.assessed_vs_sales_pct,
	a.assessed_outlier,
	a.sale_amount_outlier
from real_estate as a
join dim_property as b
	on b.property_type = a.property_type
	and b.residential_type = a.residential_type
join dim_location as c
	on c.town = a.town
	and c.address = a.address
	and c.town_outlier = a.town_outlier
join dim_date as d
	on d.date_id = a.date_recorded;

-- all tables are populated.

-- altered sales_ratio.
alter table fact_property
alter column sales_ratio type decimal(10,2)
using sales_ratio::decimal(10,2);

-- ****************************************************************************
-- as the dataset was filled with many data anomalies. It was better to clean it again using pandas and load it in the same warehouse for better
-- modelling approach.

truncate table dim_date cascade;
truncate table dim_property cascade;
truncate table dim_location cascade;
truncate table fact_property cascade;


-- ******* DWH complete! ******************************************
-- Creating indexes in the most used keys to increase performances of each query.
create index idx_date_id_dim on dim_date(date_id); 
create index idx_property_id_fact on fact_property(property_id);
create index idx_location_id_fact on fact_property(location_id);

-- For frequent filters of town and property_type. (dim tables).
create index idx_town_dim on dim_location(town);
create index idx_property_dim on dim_property(property_type);



-- *************************************************************************

select
	b.town,
	c.property_type,
	sum(a.sale_amount) as total_amount
from fact_property as a
join dim_location as b on b.location_id = a.location_id
join dim_property as c on c.property_id = a.property_id
join dim_date as d on d.date_id = a.date_recorded
where d.year between 2020 and 2021
and b.town = 'greenwich'
group by 1,2;

-- *******************************************************
-- YoY growth percentage.
with cte as(select
	b.year,
	sum(a.sale_amount) as total_sale_amount,
	lag(sum(a.sale_amount)) over (order by b.year) as prev_year_total
from fact_property as a
join dim_date as b on b.date_id = a.date_recorded
group by 1)

select
	year,
	total_sale_amount,
	prev_year_total,
	round((total_sale_amount - prev_year_total) * 100 / prev_year_total ,2) as YoY_growth
from cte
where prev_year_total is not null;

-- property type wise YoY sale growth.

with cte as(select
	c.property_type,
	b.year,
	sum(a.sale_amount) as total_sales,
	lag(sum(a.sale_amount)) over (partition by c.property_type order by b.year) as prev_year_total
from fact_property as a
join dim_date as b on b.date_id = a.date_recorded
join dim_property as c on c.property_id = a.property_id
group by 1,2)

select
	property_type,
	year,
	total_sales,
	coalesce(prev_year_total, 0) as prev_year_total,
	coalesce(round((total_sales - prev_year_total) * 100 / prev_year_total , 2), 0) as YoY_growth
from cte;