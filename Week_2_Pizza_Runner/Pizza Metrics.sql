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

/* --------------
   Pizza Metrics
   --------------*/
-- 1. How many pizzas were ordered?
SELECT 
	COUNT(*) as num_pizza_ordered
FROM updated_customer_orders;

-- 2. How many unique customer orders were made?
SELECT 
	COUNT(DISTINCT(order_id))
FROM updated_customer_orders;

-- 3. How many successful orders were delivered by each runner?
SELECT
	runner_id,
	COUNT(order_id) AS order_count
FROM updated_runner_orders
WHERE cancellation IS NULL
GROUP BY runner_id
ORDER BY runner_id;

-- 4. How many of each type of pizza was delivered?
SELECT 
	pn.pizza_name,
	COUNT(co.pizza_id) as pizza_count
FROM updated_customer_orders AS co
INNER JOIN updated_runner_orders AS ro
	ON co.order_id = ro.order_id
INNER JOIN pizza_names AS pn
	ON co.pizza_id = pn.pizza_id
WHERE cancellation IS NULL
GROUP BY pn.pizza_name;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT
	co.customer_id,
	pn.pizza_name,
	COUNT(co.pizza_id) as pizza_count
FROM updated_customer_orders AS co
INNER JOIN pizza_names AS pn
	ON co.pizza_id = pn.pizza_id
GROUP BY co.customer_id, pn.pizza_name
ORDER BY co.customer_id;

-- 6. What was the maximum number of pizzas delivered in a single order?
SELECT
	co.order_id,
	COUNT(co.pizza_id) as pizzas_per_order
FROM updated_customer_orders AS co
INNER JOIN updated_runner_orders AS ro
	ON co.order_id = ro.order_id
WHERE cancellation IS NULL
GROUP BY co.order_id
ORDER BY pizzas_per_order DESC;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT 
	customer_id,
  	SUM(CASE WHEN c.exclusions IS NOT null OR c.extras IS NOT NULL THEN 1
		ELSE 0 END) AS at_least_1_change,
  	SUM(CASE WHEN c.exclusions IS NULL AND c.extras IS NULL THEN 1 
		ELSE 0 END) AS no_change	
FROM updated_customer_orders AS c
INNER JOIN updated_runner_orders AS ro
	ON c.order_id = ro.order_id
WHERE ro.cancellation IS NULL
GROUP BY c.customer_id
ORDER BY c.customer_id;

-- 8. How many pizzas were delivered that had both exclusions and extras?
SELECT 
	SUM(CASE WHEN c.exclusions IS NOT null AND c.extras IS NOT NULL THEN 1
		ELSE 0 END) AS pizza_with_exclusions_extras
FROM updated_customer_orders AS c
INNER JOIN updated_runner_orders AS ro
	ON c.order_id = ro.order_id
WHERE ro.cancellation IS NULL;

-- 9. What was the total volume of pizzas ordered for each hour of the day?
SELECT 
	date_part('hour', order_time::TIMESTAMP) AS hour_of_day,
	COUNT(*) AS pizza_ordered
FROM updated_customer_orders
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- 10. What was the volume of orders for each day of the week?
SELECT 
	TO_CHAR(order_time, 'Day') AS day_of_week,
	COUNT(*) AS pizza_ordered
FROM updated_customer_orders
GROUP BY day_of_week
ORDER BY day_of_week;

