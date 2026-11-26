CREATE DATABASE IF NOT EXISTS eu_macro_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE eu_macro_db;

DROP TABLE IF EXISTS dim_geo;
CREATE TABLE dim_geo (
  geo          VARCHAR(16) PRIMARY KEY,
  country_name VARCHAR(64) NOT NULL,
  euro_area    TINYINT NOT NULL,     -- 1 = in euro memeber (includes Bulgaria following Jan 2026 adoption)
  sub_region   VARCHAR(32) NOT NULL
);
INSERT INTO dim_geo VALUES
('AT','Austria',1,'Western'),('BE','Belgium',1,'Western'),('BG','Bulgaria',1,'CEE'),
('CY','Cyprus',1,'Southern'),('CZ','Czechia',0,'CEE'),('DE','Germany',1,'Western'),
('DK','Denmark',0,'Nordic'),('EE','Estonia',1,'Baltic'),('EL','Greece',1,'Southern'),
('ES','Spain',1,'Southern'),('FI','Finland',1,'Nordic'),('FR','France',1,'Western'),
('HR','Croatia',1,'CEE'),('HU','Hungary',0,'CEE'),('IE','Ireland',1,'Western'),
('IT','Italy',1,'Southern'),('LT','Lithuania',1,'Baltic'),('LU','Luxembourg',1,'Western'),
('LV','Latvia',1,'Baltic'),('MT','Malta',1,'Southern'),('NL','Netherlands',1,'Western'),
('PL','Poland',0,'CEE'),('PT','Portugal',1,'Southern'),('RO','Romania',0,'CEE'),
('SE','Sweden',0,'Nordic'),('SI','Slovenia',1,'CEE'),('SK','Slovakia',1,'CEE'),
('EU27_2020','EU 27 (aggregate)',0,'Aggregate');

DROP TABLE IF EXISTS dim_year;
CREATE TABLE dim_year (
  year INT PRIMARY KEY,
  period_label VARCHAR(40) NOT NULL
);
INSERT INTO dim_year (year, period_label)
VALUES 
(2018, 'Pre-COVID'), (2019, 'Pre-COVID'), (2020, 'Pandemic / inflation shock')
, (2021, 'Pandemic / inflation shock'), (2022, 'Pandemic / inflation shock')
, (2023, 'Pandemic / inflation shock'), (2024, 'Recent / provisional'),(2025, 'Recent / provisional');

select * from dim_geo;
select * from dim_year;
select * from unemployment_rate;
select * from inflation;
select * from net_wages;
select * from inwork_poverty;
select *  from vacancy;


-- Let's start with inflation
create table yearly_inflation as 
select g.geo as code, g.country_name as country, 
g.euro_area as euro, g.sub_region as sub_region, 
y.year as year, y.period_label as period, 
i.OBS_VALUE as yearly_inf_rate 
from inflation as i
inner join dim_geo as g
on g.country_name=i.geo
inner join dim_year as y
on i.TIME_PERIOD=y.year
where i.coicop='All-items HICP' and i.unit='Annual average rate of change'
order by g.country_name, y.year;

drop table if exists inflation_2015;

create table inflation_2015 as 
select g.geo as code, g.country_name as country, 
g.euro_area as euro, g.sub_region as sub_region, 
y.year as year, y.period_label as period, 
i.OBS_VALUE as inf_rate_as_2015 
from inflation as i
inner join dim_geo as g
on g.country_name=i.geo
inner join dim_year as y
on i.TIME_PERIOD=y.year
where i.coicop='All-items HICP' and i.unit='Annual average index'
order by g.country_name, y.year;

select country, concat(round(avg(yearly_inf_rate),2), '%') as average_inf_rate
from yearly_inflation
group by country
order by average_inf_rate desc; -- Hungary, Romania, Latvia, Estonia and Poland had the highest average inflation. 

-- How does it look like based on region, euro/national currency level?
select sub_region, concat(round(avg(yearly_inf_rate),2), '%') as average_inf_rate
from yearly_inflation
group by sub_region
order by average_inf_rate desc;

/*Baltic	5.37%
CEE	5.1%
Western	3.18%
Nordic	2.64%
Southern	2.56% */-- Seems like Baltic sub-region had the highest average inflation. 

select euro, concat(round(avg(yearly_inf_rate),2), '%') as average_inf_rate
from yearly_inflation
group by euro
order by average_inf_rate desc;
/*
0	4.89%
1	3.48% Non-euro countries had higher average inflation rates
*/

-- Which year had the biggest inflation rate for each country?

with temp_inf as(select country, 
year, yearly_inf_rate, dense_rank() over (partition by country order by yearly_inf_rate desc) as inf_rank
from yearly_inflation) select country, year, yearly_inf_rate from temp_inf where inf_rank=1 order by yearly_inf_rate desc; 
-- Seems like most of the countries experienced a huge spike in inflation in 2022, with Estonia leading with 19.4%. Only Hungary experienced a max of 17% in 2023. 

-- How does the inflation compares per each country per each period?
select country, period, concat(round(avg(yearly_inf_rate),2), '%')
from yearly_inflation
group by country, period;
-- The inflation soared in the Pandemic/inflation shock period, only now reaching pre-pandemic levels or stabilizing. 

-- Which countries had the average inflation rate above or below the EU-average for this period? 
select country, concat(round(avg(yearly_inf_rate),2), '%') as avg_rate,
case when avg(yearly_inf_rate)>(select avg(yearly_inf_rate) from yearly_inflation) then 'Above'
else 'Below' end as 'Above/Below EU average'
from yearly_inflation
group by country;

-- How do prices compare to 2015? Which countries had the highest/lowest increase?
select country, inf_rate_as_2015
from inflation_2015
where year=2025
order by inf_rate_as_2015 desc;

-- Cyprus (118%, Denmark-121%, Ireland - 122% had the lowest increase, while Hungary -173%, Estonia - 162%, Romania - 160% had the highest spike)
-- Checking the unemployment table
drop table if exists unemployment_rate_clean;
create table unemployment_rate_clean as 
select g.geo as code, g.country_name as country, 
g.euro_area as euro, g.sub_region as sub_region, y.year, y.period_label as period,
max(case when u.unit='Percentage of population in the labour force' then u.OBS_VALUE end) as unem_pct_labour_force, 
max(case when u.unit='Percentage of total population' then u.OBS_VALUE end) as unem_pct_pop,
max(case when u.unit='Thousand persons' then u.OBS_VALUE end) as unem_thsnd
from unemployment_rate as u
inner join dim_year as y
on u.TIME_PERIOD=y.year
inner join dim_geo as g
on u.geo=g.country_name
group by g.geo,
    g.country_name,
    g.euro_area,
    g.sub_region,
    y.year
order by g.country_name, y.year;

-- Finding out the average unemployment per period
select country, period, concat(round(avg(unem_pct_labour_force),2),'%'), 
concat(round(avg(unem_pct_pop),2),'%'), concat(avg(unem_thsnd),'K')
from unemployment_rate_clean
group by country, period
order by country, period; -- countries differ, here we see different results. For some the COVID period affected negatively the employment, for others it had a positive impact

-- Finding out the year with the biggest unemployment rate of labour force 
with temp_unem as (select country, year, unem_pct_labour_force,
dense_rank() over (partition by country order by unem_pct_labour_force desc) as year_rank
from unemployment_rate_clean)
select year, count(distinct country) 
from temp_unem
where year_rank=1
group by year
order by year; -- It seems that the biggest unemployment rate happened in 2018 for most of the countries. Only 2 countries hit the highest unemployment rate in 2024, but 5 in 2025.
/*
2018	10
2020	7
2021	6
2024	2
2025	5
*/
-- How does the unemployment rate compare across regions and periods?
select sub_region, period, concat(round(avg(unem_pct_labour_force),2),'%'), 
concat(round(avg(unem_pct_pop),2),'%'), concat(round(avg(unem_thsnd),2),'K')
from unemployment_rate_clean
group by sub_region, period
order by sub_region;
 -- Baltics and Nordics have a higher unemployment rate now than before the pandemic. In CEE and Western Europe the rate is relatively stable. 
 -- In Southern Europe the pandemic showed exceptionally high values, recovering now. 
 
-- Creating a clean table to check the inwork poverty per age group 
drop table if exists inwork_poverty_clean; 
create table inwork_poverty_clean as
select g.geo as code, g.country_name as country, 
g.euro_area as euro, g.sub_region as sub_region, y.year as year, y.period_label as period,
max(case when p.age='18 years or over' then p.OBS_VALUE end) as inwork_pov_adults_over_18,
max(case when p.age='From 18 to 24 years' then p.OBS_VALUE end) as inwork_pov_juniors_18_24,
max(case when p.age='From 25 to 29 years' then p.OBS_VALUE end) as inwork_pov_young_adults_25_29,
max(case when p.age='From 55 to 64 years' then p.OBS_VALUE end) as inwork_pov_pre_retirement_55_64
from inwork_poverty as p
inner join dim_year as y
on p.TIME_PERIOD=y.year
inner join dim_geo as g
on p.geo=g.country_name
group by g.geo, g.country_name, 
g.euro_area, g.sub_region, y.year, y.period_label;
-- let's compare the risk of inwork poverty per country across different periods of time. In the recent times, which countries have especically high values for risk
select country, period, round(avg(inwork_pov_adults_over_18),2) as avg_adults, round(avg(inwork_pov_juniors_18_24),2) as avg_18_24, round(avg(inwork_pov_young_adults_25_29),2) as avg_25_29,
round(avg(inwork_pov_pre_retirement_55_64),2) as avg_55_64,
round(avg(inwork_pov_juniors_18_24)/avg(inwork_pov_adults_over_18),2) as risk_juniors_18_24,
round(avg(inwork_pov_young_adults_25_29)/avg(inwork_pov_adults_over_18),2) as risk_young_adults_25_29,
round(avg(inwork_pov_pre_retirement_55_64)/avg(inwork_pov_adults_over_18),2) as risk_pre_retirement_55_64
from inwork_poverty_clean
where period='Recent / provisional'
group by country, period
order by risk_juniors_18_24 desc, risk_young_adults_25_29 desc, risk_pre_retirement_55_64 desc ;

/* We see that in Denmark, Finland, Lithuania, Germany, Sweden and Netherlands the inwork poverty is especially high for young adults within the age of 18-24. 
 Denmark is especially high at 3.42 risk ratio, meaning that the percentage of population experiencing inwork poverty between 18-24 yo is 3.42 higher 
than the general adult population. Here we see a inwork poverty index of 6.05% within the general adult population, but a rate of 20.7% across 18-24 yo. 
For Finland the index is also quite high, however the inwork poverty for the same age group is only 6.75%, which is lower than in many other countries, 
and doesn't even compare to Denmark's. */

/* As follow up questions, let's check countries where the values cross the 10% border, also where does the inwork poverty value for both young adults category is lower 
than for the general population and where do we see that the value is lower for the pre-retirement age group*/
select country, sub_region, period, round(avg(inwork_pov_adults_over_18),2) as avg_inwork_pov, round(avg(inwork_pov_juniors_18_24),2) as avg_18_24, round(avg(inwork_pov_young_adults_25_29),2) as avg_25_29,
round(avg(inwork_pov_pre_retirement_55_64),2) as avg_55_64
from inwork_poverty_clean
where inwork_pov_adults_over_18>10 and period='Recent / provisional'
group by country, sub_region, period
order by avg_inwork_pov desc;

/*We see that mostly countries in Southern Europe (Spain, Italy, Greece) and CEE (Romania, Bulgaria, Slovakia) maintain values over 10%
Exception is Luxemburg where the rate is quite high for Western Europe. Also, we see Estonia from Baltics. */

select country, sub_region, period, round(avg(inwork_pov_adults_over_18),2) as avg_adults, round(avg(inwork_pov_juniors_18_24),2) as avg_18_24, 
round(avg(inwork_pov_young_adults_25_29),2) as avg_25_29,
round(avg(inwork_pov_juniors_18_24)/avg(inwork_pov_adults_over_18),2) as risk_juniors_18_24,
round(avg(inwork_pov_young_adults_25_29)/avg(inwork_pov_adults_over_18),2) as risk_young_adults_25_29
from inwork_poverty_clean
where period='Recent / provisional' 
group by country, sub_region, period
having round(avg(inwork_pov_juniors_18_24)/avg(inwork_pov_adults_over_18),2)<1 and 
round(avg(inwork_pov_young_adults_25_29)/avg(inwork_pov_adults_over_18),2)<1 and 
round(avg(inwork_pov_young_adults_25_29),2) <10 and
round(avg(inwork_pov_juniors_18_24),2) < 10
order by sub_region ;

/*We see that across smaller CEE, Southern and Western countries the values for young adults aged between 18 and 29 yo the values are better than for the general population, 
also being under 10%. 

Countries where this is the case are: Latvia, Czechia, Croatia, Slovenia, Greece, Malta, Portugal, Belgium and Ireland. */

select country, sub_region, period, round(avg(inwork_pov_adults_over_18),2) as avg_adults, 
round(avg(inwork_pov_pre_retirement_55_64),2) as avg_55_64,
round(avg(inwork_pov_pre_retirement_55_64)/avg(inwork_pov_adults_over_18),2) as risk_pre_retirement_55_64
from inwork_poverty_clean
where period='Recent / provisional' 
group by country, sub_region, period
having round(avg(inwork_pov_pre_retirement_55_64)/avg(inwork_pov_adults_over_18),2)<1 and 
round(avg(inwork_pov_pre_retirement_55_64),2)<10 
order by sub_region, risk_pre_retirement_55_64 ;
/* On the opposite site, we see that in most European countries the risk index is lower for the pre-retirees. The number of countries where this is applicable
is much greater than the one for young adults and juniors, however some countries like Slovenia, Malta, Ireland, Croatia are present in both tables. */

-- Creating the net_wages table, I will also combine it with inflation to calculate the real_wage_growth as opposed to just the nominal one
drop table if exists net_wages_clean;
create table net_wages_temp as
with net_wage_temp as (
select g.geo as code, g.country_name as country, 
g.euro_area as euro, g.sub_region as sub_region, y.year as year, y.period_label as period,
max(case when w.ecase='Single person without children earning 100% of the average earning' then w.OBS_VALUE end) as net_average_income_single
from net_wages as w
inner join dim_year as y
on w.TIME_PERIOD=y.year
inner join dim_geo as g
on w.geo=g.country_name
group by g.geo, g.country_name, 
g.euro_area, g.sub_region, y.year, y.period_label)
select w.code, w.country, w.euro, w.sub_region, w.year,  w.period, w.net_average_income_single, i.yearly_inf_rate,
/*Getting the yearly change in avg income)*/
round((w.net_average_income_single - lag(w.net_average_income_single) over (partition by w.country order by w.year))/
lag(w.net_average_income_single) over (partition by w.country order by w.year) * 100.0,2) as yearly_growth_income,
/*Now using the above to get the real income growth using the Fischer's law: (1+growth)/(1+inflation)-1*/
round(((1+((w.net_average_income_single - lag(w.net_average_income_single) over (partition by w.country order by w.year))/
lag(w.net_average_income_single) over (partition by w.country order by w.year)))/(1+i.yearly_inf_rate/100.0) - 1)*100,2) as real_wage_growth
from net_wage_temp as w
inner join yearly_inflation as i
on w.code=i.code and w.year =i.year;

-- Building a rolling wage change column and checking the data for 2025, to see how the wages moved during this period
create table net_wages_clean as
select *, round((exp(sum(ln(1+coalesce(real_wage_growth/100,0))) over (partition by country order by year))-1)*100,2) as rolling_real_wage_change
from net_wages_temp;
 
-- Which countries experienced a negative growth between 2018 and 2025? 
select country, rolling_real_wage_change
from net_wages_clean
where year=2025 and rolling_real_wage_change<0;
/*
Belgium	-2.02
France	-2.66
Germany	-5.37
Netherlands	-13.65
Sweden	-5.46
*/

-- Which countries experienced the most positive growth?
select country, rolling_real_wage_change
from net_wages_clean
where year=2025
order by rolling_real_wage_change desc
limit 5;
/*
Bulgaria	90.9
Latvia	57.48
Lithuania	50.76
Slovenia	48.53
Portugal	43.18
*/

-- Now focusing on vacancies

select geo, TIME_PERIOD, left(TIME_PERIOD,4), indic_em, OBS_VALUE
from vacancy
where indic_em='Job vacancy rate';

-- I decided to calculate the vacancy rate and the quarterly changes myself. Italy has missing data in this table, while Estonia has missing data for some years. 
-- In this case I will continue the analysis and add a note about this. 
drop table if exists vacancy_clean;
create table vacancy_clean as
with vacancy_temp as(
select geo , TIME_PERIOD, left(TIME_PERIOD,4) as year,
max(case when indic_em='Job vacancies' then OBS_VALUE end) as job_vacancies,
max(case when indic_em='Occupied (posts) jobs' then OBS_VALUE end) as occupied_posts
from vacancy
group by geo , TIME_PERIOD, left(TIME_PERIOD,4))
select g.geo as code, g.country_name as country, 
g.euro_area as euro, g.sub_region as sub_region, y.year as year, y.period_label as period,
round(avg(v.job_vacancies),2) as avg_quarterly_job_vacancies, 
round(avg(v.occupied_posts),2) as avg_quarterly_occupied_posts
from vacancy_temp as v
inner join dim_year as y
on v.year=y.year
inner join dim_geo as g
on v.geo=g.country_name
group by g.geo,
g.country_name,
g.euro_area,
g.sub_region,
y.year,
y.period_label
order by g.country_name, y.year; 

-- Checking the yearly change for yearly average quarterly vacancies numbers and comparing it to the unemployment numbers
-- I liked this table so much that I want it to be an additional table 
drop table if exists vacancy_and_unemployment_clean; 
create table vacancy_and_unemployment_clean as
select v.code, v.country, v.euro, v.sub_region, v.year, v.period, v.avg_quarterly_job_vacancies, 
round((v.avg_quarterly_job_vacancies - lag(v.avg_quarterly_job_vacancies) over (partition by v.country order by v.year))/
lag(v.avg_quarterly_job_vacancies) over (partition by v.country order by v.year)*100,2) as yearly_change_vacancies, 
u.unem_thsnd*1000 as unemployed_count, u.unem_pct_labour_force, round((avg_quarterly_job_vacancies/1000.0)/u.unem_thsnd,2) as avg_quarterly_jobs_per_unemployed, 
round((u.unem_thsnd-lag(u.unem_thsnd) over (partition by u.country order by u.year))
/lag(u.unem_thsnd) over (partition by u.country order by u.year)*100,2) as unemployment_rate_change
from vacancy_clean as v
inner join unemployment_rate_clean as u
on v.code=u.code and v.year=u.year;

-- I want to compare 2025 to 2020/2021 as both years seem to reflect a crisis on the job market and compare the numbers
select * 
from vacancy_and_unemployment_clean
where year in (2020,2021,2025);

-- interestingly enough we can see that in most countries we see comparable drops in vacancies in 2020 as in 2025, with a similar increase in unemployment numbers
-- 2021 seems to be mostly a recovery year for most countries. There are some exceptions, but the patter in visible, specifically in terms of big reductions in 
-- available positions and increase is people without a position. Would be interesting to also check the numbers for 2026.

-- Now I would also like to check the countries for the situation regarding the Average quarterly jobs per unemployed people for 2025. Where is the situation critical
-- and where is the situation more manageable?

select country, sub_region, avg_quarterly_job_vacancies, yearly_change_vacancies, unemployed_count, unem_pct_labour_force, 
avg_quarterly_jobs_per_unemployed, unemployment_rate_change
from vacancy_and_unemployment_clean
where year = 2025
order by avg_quarterly_jobs_per_unemployed;
/* The anti-leaders here are Romania (0.06), Spain (0.06), Greece (0.1), Finland (0.12), Slovakia (0.13), Poland (0.17) and Portugal (0.17). 
Almost in all countries we see a decrease in available vacancies, only in Malta, Cyprus, Lithuania, Ireland, Bulgaria, Spain and Portugal do we see an actual increase. 
Nevertheless, in most countries the rate still fails to accomodate the thousands of unemployed people. The leaders in regards to available vacancies
and the unemployed people are: Netherlands (0.97), Malta (0.92), Germany (0.66), Cyprus (0.63), Czechia (0.57) and Austria (0.52). Here the competition
is milder, and the unemployed to vacancy ratio is between 1 unemployed per vacancy and 2 unemployed per vacancy. 
Of course we must take into account that not all statistics might describe fully the situation on the ground.*/

select * from dim_geo;
select * from dim_year; 
select * from yearly_inflation;
select * from inflation_2015;
select * from inwork_poverty_clean;
select * from net_wages_clean;
select * from unemployment_rate_clean;
select * from vacancy_and_unemployment_clean;