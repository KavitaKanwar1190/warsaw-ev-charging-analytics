CREATE DATABASE IF NOT EXISTS warsaw_ev_db;
USE warsaw_ev_db;

--  Districts Table
CREATE TABLE districts (
    district_name VARCHAR(100) PRIMARY KEY,
    income_tier VARCHAR(50),
    projected_evs INT,
    projected_plugs INT,
    projected_regular_customers INT
);


-- Customers Table
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    income_tier VARCHAR(50),
    car_model VARCHAR(100),
    battery_capacity_kwh DECIMAL(8, 2)
);

-- Charging Stations Table
CREATE TABLE charging_stations (
    station_id INT PRIMARY KEY,
    district_name VARCHAR(100),
    income_tier VARCHAR(50),
    operator_name VARCHAR(100),
    plugs_count INT,
    latitude DECIMAL(10, 6),
    longitude DECIMAL(10, 6),
    FOREIGN KEY (district_name) REFERENCES districts(district_name)
);

-- Charging Sessions Table
CREATE TABLE charging_sessions (
    session_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    station_id INT,
    session_start_time DATETIME,
    kwh_charged DECIMAL(10, 4),
    cost_per_kwh DECIMAL(10, 4),
    total_cost DECIMAL(10, 4),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (station_id) REFERENCES charging_stations(station_id)
);

-- 1. List all districts along with their income tiers.
SELECT 
    district_name, 
    income_tier 
FROM districts
ORDER BY district_name ASC;

-- 2. Count the total number of charging stations in each district.
SELECT 
    d.district_name,
    COUNT(cs.station_id) AS total_stations
FROM districts d
LEFT JOIN charging_stations cs 
    ON d.district_name = cs.district_name
GROUP BY d.district_name
ORDER BY total_stations DESC;

-- 3. Find the total number of charging plugs available per district.
SELECT 
    d.district_name,
    COALESCE(SUM(cs.plugs_count), 0) AS total_plugs
FROM districts d
LEFT JOIN charging_stations cs 
    ON d.district_name = cs.district_name
GROUP BY d.district_name
ORDER BY total_plugs DESC;


-- 4. Calculate the total number of charging sessions recorded.
SELECT COUNT(*) AS total_sessions 
FROM charging_sessions;

-- 5. Find the average energy charged (kWh) per charging session.
SELECT ROUND(AVG(kwh_charged), 2) AS avg_kwh_per_session 
FROM charging_sessions;

-- Intermediate Level


-- 6. Calculate total energy charged (kWh) by each district.
SELECT 
    cs.district_name,
    ROUND(SUM(s.kwh_charged), 2) AS total_kwh_charged
FROM charging_sessions s
JOIN charging_stations cs 
    ON s.station_id = cs.station_id
GROUP BY cs.district_name
ORDER BY total_kwh_charged DESC;


-- 7. Identify the top 5 charging stations based on number of charging sessions.
SELECT 
    s.station_id,
    cs.district_name,
    cs.operator_name,
    COUNT(s.session_id) AS total_sessions
FROM charging_sessions s
JOIN charging_stations cs 
    ON s.station_id = cs.station_id
GROUP BY s.station_id, cs.district_name, cs.operator_name
ORDER BY total_sessions DESC
LIMIT 5;



-- 8. Calculate total charging revenue generated per district.
SELECT 
    cs.district_name,
    ROUND(SUM(s.total_cost), 2) AS total_revenue
FROM charging_sessions s
JOIN charging_stations cs 
    ON s.station_id = cs.station_id
GROUP BY cs.district_name
ORDER BY total_revenue DESC;


-- 9. Find the average charging cost per session for each income tier.
SELECT 
    c.income_tier,
    ROUND(AVG(s.total_cost), 2) AS avg_cost_per_session
FROM charging_sessions s
JOIN customers c 
    ON s.customer_id = c.customer_id
GROUP BY c.income_tier
ORDER BY avg_cost_per_session DESC;



-- 10. Analyze average energy charged per customer.
SELECT 
    ROUND(SUM(kwh_charged) / COUNT(DISTINCT customer_id), 2) AS avg_kwh_per_customer
FROM charging_sessions;


-- Advanced Level

-- 11. Compare projected EV count with total available charging plugs for each district.
SELECT 
    d.district_name,
    d.projected_evs,
    COALESCE(SUM(cs.plugs_count), 0) AS available_plugs,
    ROUND(d.projected_evs * 1.0 / NULLIF(SUM(cs.plugs_count), 0), 2) AS ev_per_plug_ratio
FROM districts d
LEFT JOIN charging_stations cs 
    ON d.district_name = cs.district_name
GROUP BY d.district_name, d.projected_evs
ORDER BY available_plugs ASC;


-- 12. Identify districts where projected EVs exceed available charging plugs.
SELECT 
    d.district_name,
    d.projected_evs,
    COALESCE(SUM(cs.plugs_count), 0) AS available_plugs,
    (d.projected_evs - COALESCE(SUM(cs.plugs_count), 0)) AS infrastructure_deficit
FROM districts d
LEFT JOIN charging_stations cs 
    ON d.district_name = cs.district_name
GROUP BY d.district_name, d.projected_evs
HAVING available_plugs < d.projected_evs
ORDER BY infrastructure_deficit DESC;


-- 13. Analyze charging demand per projected EV by district (total kWh / projected EVs).
SELECT 
    d.district_name,
    d.projected_evs,
    ROUND(COALESCE(SUM(s.kwh_charged), 0), 2) AS total_kwh_used,
    ROUND(COALESCE(SUM(s.kwh_charged), 0) / d.projected_evs, 2) AS kwh_per_projected_ev
FROM districts d
LEFT JOIN charging_stations cs 
    ON d.district_name = cs.district_name
LEFT JOIN charging_sessions s 
    ON cs.station_id = s.station_id
GROUP BY d.district_name, d.projected_evs
ORDER BY kwh_per_projected_ev DESC;


-- 14. Rank districts based on infrastructure readiness using actual charging usage vs projections.
WITH district_readiness AS (
    SELECT 
        d.district_name,
        d.projected_evs,
        COALESCE(SUM(DISTINCT cs.plugs_count), 0) AS available_plugs,
        ROUND(COALESCE(SUM(s.kwh_charged), 0), 2) AS total_kwh_used,
        ROUND(COALESCE(SUM(cs.plugs_count), 0) * 1.0 / d.projected_evs, 4) AS plug_availability_ratio
    FROM districts d
    LEFT JOIN charging_stations cs 
        ON d.district_name = cs.district_name
    LEFT JOIN charging_sessions s 
        ON cs.station_id = s.station_id
    GROUP BY d.district_name, d.projected_evs
)
SELECT 
    district_name,
    projected_evs,
    available_plugs,
    total_kwh_used,
    plug_availability_ratio,
    DENSE_RANK() OVER (ORDER BY plug_availability_ratio DESC) AS readiness_rank
FROM district_readiness;



