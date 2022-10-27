'Creating table for csv import - including data types and constraints this table includes PK'
DROP TABLE IF EXISTS all_regions;
CREATE TABLE all_regions(
   pk SERIAL PRIMARY KEY,
   entity VARCHAR(100) NOT NULL,
   year DATE NOT NULL,
   electricity_from_nuclear_TWh DECIMAL)


'Making sure pgAdmin csv import successful'

SELECT * FROM all_regions;

'Creating table for csv import - including data types and constraints – parent and child tables referenced so that data deleted in the parent table propagates to the child'

DROP TABLE IF EXISTS demo_data1;
CREATE TABLE demo_data1(
   d1_id INT GENERATED ALWAYS AS IDENTITY,
   entity VARCHAR(100) NOT NULL,
   year VARCHAR(10),
   fk_all_regions INT,
   PRIMARY KEY(d1_id),
   CONSTRAINT fk
      FOREIGN KEY(fk_all_regions)
REFERENCES all_regions(pk)
ON DELETE CASCADE);

'Making sure pgAdmin csv import successful'

SELECT * FROM demo_data1
LIMIT 10;

SELECT COUNT(*) FROM demo_data1;

'Creating table for csv import - including data types and constraints'
CREATE TABLE demo_data2(
   d2_id INT GENERATED ALWAYS AS IDENTITY,
   electricity_from_nuclear_tWh DECIMAL NOT NULL,
   fk_all_regions INT,
   PRIMARY KEY(d2_id),
   CONSTRAINT fk
      FOREIGN KEY(fk_all_regions) 
	REFERENCES all_regions(pk)
ON DELETE CASCADE);

'Making sure pgAdmin csv import successful'

SELECT * FROM demo_data2
LIMIT 10;

SELECT COUNT(*) FROM demo_data2;

‘Checking parent/child CASCADE constraint working’

DELETE FROM all_regions
WHERE pk = 4000;
SELECT * FROM demo_data1; 
SELECT * FROM demo_data2;

‘Reinserting deleted row’

INSERT INTO all_regions
(pk,entity,year,electricity_from_nuclear_twh)
VALUES (4000,'Kiribati',2002,0);

INSERT INTO demo_data1
(d1_id,entity,year,fk_all_regions)
OVERRIDING SYSTEM VALUE
VALUES (4000,'Kiribati',2002,4000);

INSERT INTO demo_data2
(d2_id,electricity_from_nuclear_twh,fk_all_regions)
OVERRIDING SYSTEM VALUE
VALUES(4000,0,4000);

'Selecting specific columns'

SELECT entity, year, electricity_from_nuclear_TWh FROM all_regions;

'Selecting, grouping and ordering by descending year'

SELECT entity, year, electricity_from_nuclear_TWh FROM all_regions
GROUP BY entity, year, electricity_from_nuclear_TWh
ORDER BY year DESC;

‘Checking latest year for which data exists per country. Year is “CAST” to INTEGER’

SELECT MAX((year::VARCHAR)::INTEGER) AS maxyear,entity FROM all_regions
GROUP BY entity;


‘Concatenate entity and electricity produced for each year in alphabetical order’

SELECT 
entity || ' ' || electricity_from_nuclear_twh AS "Year and Energy Generated", year 
FROM all_regions
ORDER BY year DESC, "Year and Energy Generated";

'Total nuclear energy(in TWh) produced for China and the UK 
in the year 2000'

SELECT entity, electricity_from_nuclear_TWh 
FROM all_regions
WHERE entity IN('China', 'United Kingdom') 
AND year = 2000
GROUP BY entity, electricity_from_nuclear_TWh
ORDER BY entity;

'Total nuclear energy(in TWh) produced for regions starting with 'a' between
the years 1999 and 2001 in descending order - Twh must not = zero'

SELECT entity, SUM(electricity_from_nuclear_TWh) AS sum_of_all_years_TWh 
FROM all_regions
WHERE entity ILIKE 'a%' 
AND year BETWEEN '1999' AND '2001'
GROUP BY entity
HAVING SUM(electricity_from_nuclear_TWh) != 0
ORDER BY sum_of_all_years_TWh DESC;


‘Highest energy produced per “entity” from any year in the data. Entities that produced zero energy have been removed’

SELECT DISTINCT ON(entity) entity, year, electricity_from_nuclear_twh
FROM all_regions
WHERE electricity_from_nuclear_twh != 0
ORDER BY entity, electricity_from_nuclear_twh DESC;

‘Show Chinese production of energy per year as a percentage of the year for which production was at its maximum. Years for which production was zero have been removed from the output.’

SELECT
 year,  entity, (electricity_from_nuclear_twh/ MAX(electricity_from_nuclear_twh) 
  OVER ()) AS "% of highest production year"
FROM all_regions
WHERE   entity = 'China'
ORDER BY "% of highest production year" DESC

‘Using CTE from WITH to get the same output as above’

WITH chinamax AS(
SELECT MAX(electricity_from_nuclear_twh) AS chinamaxoutput
FROM all_regions
WHERE entity = 'China'),

chinall AS(
SELECT year AS years, electricity_from_nuclear_twh AS electricity_from_nuclear_twh2
FROM all_regions
WHERE entity = 'China'
ORDER BY electricity_from_nuclear_twh DESC)

SELECT 
years, electricity_from_nuclear_twh2, 
(electricity_from_nuclear_twh2/chinamaxoutput)*100 AS percentage_of_max
FROM chinamax, chinall
WHERE (electricity_from_nuclear_twh2/chinamaxoutput)*100 != 0;


‘INNER JOIN to match “left” table(demo_data1) to values present in demo_data2 using WHERE to filter for electricity generated > 0 and the country of Belgium. Ordered by electricity generated’

SELECT entity, year, electricity_from_nuclear_twh
FROM demo_data1
JOIN demo_data2 
ON demo_data1.d1_id = demo_data2.d2_id
WHERE demo_data2.electricity_from_nuclear_twh > 0
AND entity = 'Belgium'
ORDER BY demo_data2.electricity_from_nuclear_twh DESC

‘Using a window function and PARTITION BY to separate out Chinese energy production with a total energy produced column next to it’

SELECT entity, year, electricity_from_nuclear_twh, 
SUM(electricity_from_nuclear_twh) 
OVER (PARTITION BY entity) AS total_produced
FROM all_regions
WHERE electricity_from_nuclear_twh > 0 AND entity = 'China'
ORDER BY entity, year

‘Exactly the same as above except for the final column being a “rolling” total of energy produced’

SELECT entity, year, electricity_from_nuclear_twh, 
SUM(electricity_from_nuclear_twh) 
OVER (PARTITION BY entity ORDER BY year) AS rolling_total
FROM all_regions
WHERE electricity_from_nuclear_twh > 0 AND entity = 'China'
ORDER BY entity, year

‘Using CASE to develop a 1 and 0 column where 1 represents nuclear energy having been produced that year and 0 meaning it wasn’t’

SELECT entity, year,
SUM(CASE WHEN electricity_from_nuclear_twh > 0 THEN 1 ELSE 0 END)
AS one_if_electricity_produced
FROM all_regions
WHERE entity = 'China'
GROUP BY entity, year
ORDER BY entity, year DESC

‘Same purpose as above but using “yes” and “no” in the final column instead of 1’s and 0’s’

SELECT entity, year,
(CASE WHEN electricity_from_nuclear_twh > 0 THEN 'yes' ELSE 'no' END)
AS nuclear_electricity_produced
FROM all_regions
WHERE entity = 'China'
GROUP BY entity, year, 
(CASE WHEN electricity_from_nuclear_twh > 0 THEN 'yes' ELSE 'no' END)
ORDER BY entity, year DESC

‘Last column provides percent of total produced for the given year and given entity’

SELECT entity, year, electricity_from_nuclear_twh, 
SUM(electricity_from_nuclear_twh) 
OVER (PARTITION BY entity) AS total_produced, 
electricity_from_nuclear_twh/SUM(electricity_from_nuclear_twh) 
OVER (PARTITION BY entity)*100 AS percent_of_total_produced
FROM all_regions
WHERE electricity_from_nuclear_twh > 0 
ORDER BY entity, year


‘Same purpose as above but creating a VIEW and using NULLIF instead of WHERE > 0’

DROP VIEW IF EXISTS percent_produced;
CREATE VIEW percent_produced AS
SELECT 
pk, entity, year, electricity_from_nuclear_twh, 
ROUND(SUM(electricity_from_nuclear_twh) 
OVER (PARTITION BY entity),2) AS total_produced, 
ROUND(electricity_from_nuclear_twh/NULLIF(SUM(electricity_from_nuclear_twh) OVER (PARTITION BY entity),0)*100,2) 
AS percent_of_total_produced
FROM all_regions
ORDER BY entity, year;

‘Creating “rolling total” VIEW for repeat use’

DROP VIEW IF EXISTS rolling_total_view;
CREATE VIEW rolling_total_view AS
SELECT 
entity, year, electricity_from_nuclear_twh, 
SUM(electricity_from_nuclear_twh) 
OVER (PARTITION BY entity ORDER BY year) AS rolling_total
FROM all_regions
ORDER BY entity, year;


‘Using percent_produced VIEW and COALESCE function to build a table that shows if a country has ever produced nuclear energy’

SELECT entity, year, electricity_from_nuclear_twh, 
COALESCE(CAST(percent_of_total_produced AS TEXT), 
CASE WHEN percent_of_total_produced IS NULL 
THEN 'Has never produced nuclear energy' END) 
AS percent_of_total_produced
FROM percent_produced

‘Same as above but using JOIN for demo purposes’

SELECT 
a.entity, a.year, ROUND(a.electricity_from_nuclear_twh,2) AS nuclear_energy_in_twh, 
COALESCE(CAST(p.percent_of_total_produced AS TEXT), 
CASE WHEN percent_of_total_produced IS NULL 
THEN 'Has never produced nuclear energy' END) 
AS percent_of_total_produced
FROM all_regions a
JOIN percent_produced p
ON a.pk=p.pk
ORDER BY a.entity, a.year


‘Re-using the above table but filtering for the U.K, China and Afghanistan for the year 2000’

SELECT 
a.entity, a.year, ROUND(a.electricity_from_nuclear_twh,2) AS nuclear_energy_in_twh, 
COALESCE(CAST(p.percent_of_total_produced AS TEXT), 
CASE WHEN percent_of_total_produced IS NULL 
THEN 'Has never produced nuclear energy' END) AS percent_of_total_produced
FROM all_regions a
JOIN percent_produced p
ON a.pk=p.pk
WHERE a.entity IN ('United Kingdom', 'China', 'Afghanistan') AND a.year = '2000'
ORDER BY a.entity, a.year