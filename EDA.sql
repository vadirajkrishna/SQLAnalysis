--Base Query
SELECT location, date, total_cases, new_cases, total_deaths, population 
FROM Portfolio..CovidDeaths
WHERE location = 'United States' --AND date < '2021-05-04'
ORDER BY location, date


--The columns total_cases and total_detahs are created with nvarchar, convert to float to perform any numerical operations
ALTER TABLE Portfolio..CovidDeaths ALTER COLUMN total_cases FLOAT;    
ALTER TABLE Portfolio..CovidDeaths ALTER COLUMN total_deaths FLOAT;  
GO  

--Total Cases Vs Total Deaths
SELECT 
	location, 
	date,
	total_cases AS 'Total_Cases', 
	total_deaths AS 'Total_Deaths', 
	total_deaths/total_cases*100 AS 'Death_Ratio' 
FROM Portfolio..CovidDeaths
WHERE continent IS NOT NULL
--WHERE location = 'United States'
ORDER by 2 desc

--Get the max date per country so that we can see the chance of someone dying if they get the disease in the specific country
--CTE to get the max date per location to check the status as of latest date
WITH max_date_per_location(location, latest_date) 
AS
(
	SELECT 
		location, 
		max(date)
	FROM Portfolio..CovidDeaths
	WHERE 
		total_cases is not Null and total_deaths is not Null
	GROUP by location 
)
SELECT
	a.location,
	date,
	total_cases,
	total_deaths,
	total_deaths/total_cases*100 as 'death_ratio'
FROM Portfolio..CovidDeaths as a
INNER JOIN max_date_per_location as b
ON
	a.location = b.location 
WHERE
	a.date = b.latest_date 
	AND a.continent IS NOT NULL
	--AND a.location = 'India'
ORDER by death_ratio desc

--So as 2023-11-30 a person in Yemen has 18% chance of dying from Covid 

--Total cases Vs population

WITH max_date_per_location(location, latest_date) 
AS
(
	SELECT 
		location, 
		max(date)
	FROM Portfolio..CovidDeaths
	WHERE 
		total_cases is not Null and total_deaths is not Null
	GROUP by location 
)
SELECT
	a.location,
	date,
	total_cases,
	population,
	--total_deaths,
	total_cases/population*100 as 'percent_population_affected'
FROM Portfolio..CovidDeaths as a
INNER JOIN max_date_per_location as b
ON
	a.location = b.location 
WHERE
	a.date = b.latest_date
	AND a.location in ('India', 'United States', 'United Kingdom')
ORDER by percent_population_affected desc

SELECT location, max(total_cases) FROM  Portfolio..CovidDeaths 
WHERE location = 'United States'
GROUP BY location

--Assuming the total_cases are add on from previous dates we could write the above using a simple query
SELECT 
	location, 
	max(total_cases) as 'total_cases', 
	max(population) as 'population', 
	max(total_cases)/max(population) * 100 as 'percent_population_infected'
FROM Portfolio..CovidDeaths
WHERE 
	total_cases IS NOT NULL AND population IS NOT NULL
	--AND location in ('Andorra' , 'India', 'United States', 'United Kingdom')
GROUP BY location
ORDER BY percent_population_infected desc

--Countries with highest death ratio per population
SELECT 
	location, 
	max(total_deaths) as 'total_deaths', 
	max(population) as 'population', 
	max(total_deaths)/max(population) * 100 as 'death_ratio_by_pop'
FROM Portfolio..CovidDeaths
WHERE 
	total_cases IS NOT NULL AND population IS NOT NULL
	--AND location in ('Andorra' , 'India', 'United States', 'United Kingdom')
GROUP BY location
ORDER BY death_ratio_by_pop desc

--Countries with highest death ratio per total infected
SELECT 
	location, 
	max(total_deaths) as 'total_deaths', 
	max(total_cases) as 'total_cases', 
	max(total_deaths)/max(total_cases) * 100 as 'death_ratio_by_infected'
FROM Portfolio..CovidDeaths
WHERE 
	continent IS NOT NULL
	AND total_cases IS NOT NULL AND population IS NOT NULL
	--AND location in ('Andorra' , 'India', 'United States', 'United Kingdom')
GROUP BY location
ORDER BY death_ratio_by_infected desc

--Analysis of the same by continent
SELECT 
	continent, 
	max(total_deaths) as 'total_deaths', 
	max(total_cases) as 'total_cases', 
	max(total_deaths)/max(total_cases) * 100 as 'death_ratio_by_infected'
FROM Portfolio..CovidDeaths
WHERE 
	continent IS NOT NULL
	AND total_cases IS NOT NULL AND population IS NOT NULL
	--AND location in ('Andorra' , 'India', 'United States', 'United Kingdom')
GROUP BY continent
ORDER BY total_deaths desc

-- Global Numbers per day
SELECT 
	date, SUM(new_cases) as new_cases, SUM(new_deaths) as new_deaths, SUM(new_deaths)/SUM(new_cases)*100 as DeathRatio
FROM Portfolio..CovidDeaths
WHERE continent IS NOT NULL 
	AND new_cases > 0  and new_deaths > 0
GROUP BY date
ORDER BY 1, 2

-- Global Numbers overall
SELECT 
	SUM(new_cases) as new_cases, SUM(new_deaths) as new_deaths, SUM(new_deaths)/SUM(new_cases)*100 as DeathRatio
FROM Portfolio..CovidDeaths
WHERE continent IS NOT NULL 
	AND new_cases > 0  and new_deaths > 0
ORDER BY 1, 2

-- Total population Vs Vaccinations

WITH pop_and_vacc (continent, location, date, population, new_vaccinations, RollingVaccinationByDate)
AS
(
	SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vacc.new_vaccinations ,
	SUM(CAST(vacc.new_vaccinations AS FLOAT)) 
	OVER (PARTITION by deaths.location ORDER BY deaths.location, deaths.date) as RollingVaccinationByDate
	FROM Portfolio..CovidDeaths as deaths
	INNER JOIN
	Portfolio..CovidVaccinations as vacc
	ON
		deaths.location = vacc.location AND
		deaths.date =	vacc.date
	WHERE deaths.continent IS NOT NULL
	--ORDER BY 1, 2, 3
)
SELECT *, RollingVaccinationByDate/population*100
FROM pop_and_vacc

--Doing the same using a temp table

DROP TABLE IF EXISTS #pop_and_vacc
CREATE TABLE #pop_and_vacc
(
	continent nvarchar(255),
	location nvarchar(255),
	date datetime,
	population numeric,
	new_vaccinations numeric,
	RollingVaccinationByDate numeric
)

INSERT INTO #pop_and_vacc
	SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vacc.new_vaccinations ,
	SUM(CAST(vacc.new_vaccinations AS FLOAT)) 
	OVER (PARTITION by deaths.location ORDER BY deaths.location, deaths.date) as RollingVaccinationByDate
	FROM Portfolio..CovidDeaths as deaths
	INNER JOIN
	Portfolio..CovidVaccinations as vacc
	ON
		deaths.location = vacc.location AND
		deaths.date =	vacc.date
	WHERE deaths.continent IS NOT NULL

SELECT *, RollingVaccinationByDate/population*100
FROM #pop_and_vacc

--Create a view for total death counts by continent

DROP VIEW IF EXISTS DeathCountsByContinent
CREATE VIEW DeathCountsByContinent
AS
SELECT 
	continent, 
	max(total_deaths) as 'total_deaths', 
	max(total_cases) as 'total_cases', 
	max(total_deaths)/max(total_cases) * 100 as 'death_ratio_by_infected'
FROM Portfolio..CovidDeaths
WHERE 
	continent IS NOT NULL
	AND total_cases IS NOT NULL AND population IS NOT NULL
	--AND location in ('Andorra' , 'India', 'United States', 'United Kingdom')
GROUP BY continent
--ORDER BY total_deaths desc

SELECT * FROM DeathCountsByContinent
