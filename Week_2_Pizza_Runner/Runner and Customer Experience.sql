-- Set search path to 'pizza_runner'
SET search_path = pizza_runner;

-- Check customer_orders table
SELECT *
FROM customer_orders;

-- Check pizza_names table
SELECT *
FROM pizza_names;

-- Check pizza_recipes table
SELECT *
FROM pizza_recipes;

-- Check pizza_toppings table
SELECT *
FROM pizza_toppings;

-- Check runner_orders table
SELECT *
FROM runner_orders;

-- Check runners table
SELECT *
FROM runners;

-- Null values and inconsistent data observed for the customer_orders and runner_order tables
-- Perform cleaning for customer_orders and runner_order tables
-- Temporary tables will be created to store the cleaned data in order to retain the original dataset

/* ----------------------------------------------
   Cleaning & Transformation for customer_orders
   ----------------------------------------------*/
-- Check data type
SELECT
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'customer_orders';

-- Create temporary table and update data
DROP TABLE IF EXISTS updated_customer_orders;
CREATE temp TABLE updated_customer_orders AS (
	SELECT
		order_id,
		customer_id,
		pizza_id,
		CASE WHEN exclusions IN ('null', NULL, '') THEN null
		ELSE exclusions END AS exclusions,
		CASE WHEN extras IN ('null', NULL, '') THEN null
		ELSE extras END AS extras,
		order_time
	FROM customer_orders);
	
SELECT *
FROM updated_customer_orders;

/* ----------------------------------------------
   Cleaning & Transformation for runner_orders
   ----------------------------------------------*/
-- Check data type
SELECT
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'runner_orders';

-- Create temporary table and update data
DROP TABLE IF EXISTS updated_runner_orders;
CREATE temp TABLE updated_runner_orders AS (
	SELECT
		order_id,
		runner_id,
		CASE WHEN pickup_time LIKE 'null' THEN null
		ELSE pickup_time END AS pickup_time,
		CASE WHEN distance IN ('null', NULL, '') THEN null
			WHEN distance LIKE '%km' THEN TRIM('km' FROM distance)
			ELSE distance END AS distance,
		CASE WHEN duration IN ('null', NULL, '') THEN null
			WHEN duration LIKE '%mins%' THEN TRIM('mins' FROM duration)
			WHEN duration LIKE '%minute' THEN TRIM('minute' FROM duration)
			WHEN duration LIKE '%minutes' THEN TRIM('minutes' FROM duration)
			ELSE duration END AS duration,
		CASE WHEN cancellation IN ('null', '', 'NaN') THEN null
			ELSE cancellation END AS cancellation
	FROM runner_orders);
	
SELECT *
FROM updated_runner_orders;

/* ------------------------------
   Runner and Customer Experience
   ------------------------------*/
-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT 
	to_char(registration_date, 'WW')::NUMERIC AS week,
	COUNT(runner_id) AS runner_signup
FROM runners
GROUP BY week
ORDER BY week;

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
WITH cte_pickup_min AS (
	SELECT 
		DISTINCT(co.order_id),
		ro.runner_id,
		DATE_PART('minute', ro.pickup_time::TIMESTAMP - co.order_time)::INTEGER AS pickup_min
	FROM updated_customer_orders AS co
	INNER JOIN updated_runner_orders AS ro
	ON co.order_id = ro.order_id
	WHERE ro.pickup_time IS NOT NULL
	)
SELECT
	runner_id,
	ROUND(AVG(pickup_min),2) AS avg_pickup_min
FROM cte_pickup_min
GROUP BY runner_id
ORDER BY runner_id;

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH cte_prep_time AS (
	SELECT 
		co.order_id,
		DATE_PART('minute', ro.pickup_time::TIMESTAMP - co.order_time)::INTEGER AS prep_time,
		COUNT(co.pizza_id) AS pizza_ordered
	FROM updated_customer_orders AS co
	INNER JOIN updated_runner_orders AS ro
	ON co.order_id = ro.order_id
	WHERE ro.pickup_time IS NOT NULL
	GROUP BY co.order_id, prep_time
	)
SELECT
	pizza_ordered,
	ROUND(AVG(prep_time),2) AS avg_prep_time
FROM cte_prep_time
GROUP BY pizza_ordered
ORDER BY pizza_ordered;

-- 4. What was the average distance travelled for each customer?
SELECT 
	customer_id,
	ROUND(AVG(ro.distance::NUMERIC), 2) AS avg_distance
FROM updated_customer_orders AS co
INNER JOIN updated_runner_orders AS ro
ON co.order_id = ro.order_id
WHERE ro.pickup_time IS NOT NULL
GROUP BY customer_id
ORDER BY customer_id;

-- 5. What was the difference between the longest and shortest delivery times for all orders?
SELECT 
	MAX(duration::NUMERIC) AS longest_duration,
	MIN(duration::NUMERIC) AS shortest_duration,
	MAX(duration::NUMERIC) - MIN(duration::NUMERIC) AS diff
FROM updated_runner_orders
WHERE pickup_time IS NOT NULL;

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
WITH cte_order AS (
	SELECT 
		order_id,
		order_time,
		COUNT(pizza_id) AS pizza_ordered
	FROM updated_customer_orders
	GROUP BY order_id, order_time
	)
SELECT
	o.order_id,
	ro.runner_id,
	ro.distance,
	ro.duration,
	o.pizza_ordered,
	ROUND((ro.distance::NUMERIC/ro.duration::NUMERIC)*2, 2) AS avg_speed
FROM cte_order AS o	
INNER JOIN updated_runner_orders AS ro
ON o.order_id = ro.order_id
WHERE ro.pickup_time IS NOT NULL
ORDER BY ro.runner_id, pizza_ordered, avg_speed;

-- 7. What is the successful delivery percentage for each runner?
SELECT 
	runner_id,
	COUNT(order_id) AS orders,
	COUNT(duration) AS delivered,
	ROUND(100*COUNT(duration)/COUNT(order_id)) as percent_delivered
FROM updated_runner_orders
GROUP BY runner_id
ORDER BY runner_id;

