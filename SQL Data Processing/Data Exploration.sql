-- Look at total cases, total deaths, death rate by country historically
Select cd.location,
	max(cd.total_cases) total_cases,
	max(cd.total_deaths) as total_deaths,
	max(cd.total_deaths::float)/max(cd.total_cases::float)*100 as death_rate
From coviddeath cd
Group By cd.location
Having max(cd.total_deaths) is not null and max(cd.total_cases) is not null
Order By 4 desc
Limit 10
;

-- Look at date with most death rate in USA
SELECT cd.location, cd.date,
		cd.new_cases,
		cd.new_deaths,
		(cd.new_deaths::float/cd.new_cases::float)*100 as death_percentage
FROM coviddeath cd
WHERE location = 'United States'
	and cd.new_cases is not null and cd.new_cases > 0
	and cd.new_deaths is not null
ORDER BY 4 desc
LIMIT 1
;

-- Looking at Total Cases vs Population
-- Show percentage of population got Covid in Canada on a daily basis
SELECT cd.location, cd.date,
	cd.new_cases,
	cd.population,
	(cd.new_cases::float/cd.population::float)*100 as infected_percentage
FROM coviddeath cd
WHERE cd.location = 'Canada' 
ORDER BY cd.date	
;

--Which country has the highest infection rate compared to population historically
SELECT cd.location, cd.population,
		max(cd.total_cases) as total_cases,
		max((cd.total_cases::float/cd.population::float))*100 as infection_rate
FROM coviddeath cd
WHERE cd.total_cases is not null
GROUP BY cd.location, cd.population
ORDER BY 4 desc
;
--Which country has the highest death rate compared to population historically
SELECT cd.location,
		cd.population,
		max(cd.total_deaths) as total_deaths,
		max(cd.total_deaths::float/cd.population::float)*100 as death_rate,
		max(cd.total_cases) as total_cases,
		max((cd.total_cases::float/cd.population::float))*100 as infection_rate
FROM coviddeath cd
WHERE cd.continent is not null and cd.total_deaths is not null
GROUP BY cd.location, cd.population
ORDER BY 4 desc
;
-- How many days does it take from 1 patient to ~10% of population get infected in Canada
With infected AS
		(SELECT location, 
				date,
				total_cases,
				population,
				(total_cases::float/population::float)*100 as infected_percentage
		FROM coviddeath
		WHERE location = 'Canada'
		ORDER BY 1)

SELECT 
	date as tenpdate,	
	
	(SELECT i.date
	FROM infected as i
	WHERE i.total_Cases = 1
	ORDER BY 1
	LIMIT 1) as firstcasedate,
	
	(date - 
			(SELECT i.date
			FROM infected as i
			WHERE i.total_Cases = 1
			ORDER BY 1
			LIMIT 1))/30
	 as months_diff
FROM infected
WHERE round(infected_percentage)=10
ORDER BY 1
LIMIT 1
;

-- Look at breakdown at continent level with comparision to World numbers then create a view for this query
CREATE VIEW View_Continent_Summary as
SELECT cd.continent,
	   sum(cd.new_deaths) as total_deaths,
	   (SELECT max(total_deaths) FROM coviddeath WHERE location='World') as world_deaths,
	   sum(cd.new_deaths::float)*100/(SELECT max(total_deaths::float) FROM coviddeath WHERE location='World') as cont_d_percentage,
	   sum(cd.new_cases) as total_cases,
	   (SELECT max(total_cases) FROM coviddeath WHERE location='World') as world_cases,
	   CAST(sum(cd.new_cases::float)*100/(SELECT max(total_cases::float) FROM coviddeath WHERE location='World') as float(5)) as cont_c_percentage
FROM coviddeath cd
WHERE cd.continent is not null
GROUP BY cd.continent
ORDER BY 2 desc
;

-- Look at Total Population vs Vaccinations
DROP TABLE IF EXISTS perctg_pop_vacc;
CREATE TEMPORARY TABLE perctg_pop_vacc(
	location varchar(50),
	continent varchar(50),
	date date,
	population bigint,
	new_vaccinations bigint,
	rolling_vaccinations numeric
);

INSERT INTO perctg_pop_vacc
	SELECT cd.location,
			cd.continent,
			cd.date,
			cd.population,
			cv.new_vaccinations,
			sum(cv.new_vaccinations) over (partition by cv.location order by cd.location,cd.date) as rolling_vaccinations
	FROM coviddeath cd
		join covidvaccinations cv
		on cd.location = cv.location and cd.date=cv.date
	WHERE cv.new_vaccinations is not null and cd.continent is not null
	ORDER BY 2,3

SELECT *, round((pv.rolling_vaccinations/population)*100,2) as rolling_perctg_vacc
FROM perctg_pop_vacc pv
ORDER BY 1,3