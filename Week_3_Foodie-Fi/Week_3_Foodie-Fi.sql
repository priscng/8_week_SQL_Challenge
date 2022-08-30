-- Set search path to 'foodie_fi'
SET search_path = foodie_fi;

-- A. Customer Journey
-- Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.
-- Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!
SELECT
	s.customer_id,
	p.plan_id,
	s.start_date
FROM subscriptions AS s
INNER JOIN plans AS p
	ON s.plan_id = p.plan_id
WHERE customer_id in (1,2,4)
ORDER BY customer_id, start_date;

-- In this query, I retrieved 3 customer_ids to display their onboarding journey.
-- Customer 1 started the free trial on 1 Aug 2020 and subsequently subscribed to the basic monthly plan on 8 Aug 2020 after the 7-days trial has ended.
-- Customer 2 started the free trial on 20 Sep 2020 and subsequently subscribed to the pro annual plan on 27 Sep 2020 after the 7-days trial has ended.
-- Customer 4 started the free trial on 17 Jan 2020 and subsequently subscribed to the basic monthly plan on 24 Jan 2020 after the 7-days trial has ended. This customer eventually churn out on 21 Apr 2021.

-- Result query:
-- | "customer_id" | "plan_id" | "start_date" | 
-- |---------------|-----------|--------------|
-- | 1             | 0         | "2020-08-01" |
-- | 1             | 1         | "2020-08-08" |
-- | 2             | 0         | "2020-09-20" |
-- | 2             | 3         | "2020-09-27" |
-- | 4             | 0         | "2020-01-17" |
-- | 4             | 1         | "2020-01-24" |
-- | 4             | 4         | "2020-04-21" |

-- B.Data Analysis Questions
-- 1. How many customers has Foodie-Fi ever had?
SELECT
	COUNT(DISTINCT(customer_id)) AS unique_customers
FROM subscriptions;

-- There are 1000 unique customers.
-- Result query:
-- unique_customers 
-- -----------------
--             1000

-- 2. What is the monthly distribution of trial plan start_date values for our dataset? 
-- use the start of the month as the group by value
SELECT 
	DATE_PART('month', start_date) AS month,
	COUNT(*) as count
FROM subscriptions
WHERE plan_id = 0
GROUP BY month
ORDER BY month;

-- Result query:
--  month | count 
-- -------+-------
--      1 |    88
--      2 |    68
--      3 |    94
--      4 |    81
--      5 |    88
--      6 |    79
--      7 |    89
--      8 |    88
--      9 |    87
--     10 |    79
--     11 |    75
--     12 |    84

-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT 
	p.plan_id,
	p.plan_name,
	COUNT(*) as count
FROM subscriptions AS s
INNER JOIN plans AS p
	ON s.plan_id = p.plan_id
WHERE DATE_PART('year', start_date) > 2020
GROUP BY p.plan_id, p.plan_name
ORDER BY p.plan_id;

-- Result query:
--  plan_id | plan_name     | count 
-- ---------+---------------|------
--        1 | basic monthly |    8
--        2 | pro monthly   |   60
--        3 | pro annual    |   63
--        4 | churn         |   71

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT 
	COUNT(*) AS churn_count,
	ROUND(100 * COUNT(*)::NUMERIC / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions), 1) AS churn_percent
FROM subscriptions AS s
INNER JOIN plans AS p
	ON s.plan_id = p.plan_id
WHERE s.plan_id = 4;

-- Result query:
-- churn_count | churn_percent
-- ------------+--------------
--         307 |          30.7

-- 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
WITH churn AS (
	SELECT 
		p.plan_id,
		p.plan_name,
		s.customer_id,
		ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY p.plan_id) AS rank
	FROM subscriptions AS s
	INNER JOIN plans AS p
		ON s.plan_id = p.plan_id)
SELECT
	COUNT(*) AS customer_churn,
	ROUND(100 * COUNT(*)::NUMERIC / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions), 0) AS churn_percent
FROM churn
WHERE plan_id = 4 -- filter churn plan
AND rank = 2; -- filter rank 2 as customer that churn out immediately after trial should be rank as 2

-- Result query
-- customer_churn | churn_percent
-- ---------------+--------------
--             92 |            9

-- 6. What is the number and percentage of customer plans after their initial free trial?
WITH plan_rank AS (
	SELECT 
		p.plan_id,
		p.plan_name,
		s.customer_id,
		ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY p.plan_id) AS rank
	FROM subscriptions AS s
	INNER JOIN plans AS p
		ON s.plan_id = p.plan_id)
SELECT
	pr.plan_id,
	pr.plan_name,
	COUNT(*) AS customer_count,
	ROUND(100 * COUNT(*) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions)) AS percentage
FROM plan_rank AS pr
INNER JOIN plans AS p
	ON pr.plan_id = p.plan_id
WHERE pr.rank = 2 -- filter rank 2 as this is the plan after the trial
GROUP BY pr.plan_id, pr.plan_name;

-- Result query:
--  plan_id | plan_name     | customer_count | percentage
-- ---------+---------------+----------------+------------
--        1 | basic monthly |            546 |         54
--        2 | pro monthly   |            325 |         32
--        3 | pro annual    |             37 |          3
--        4 | churn         |             92 |          9

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH sub_plan AS (
	SELECT 
		p.plan_id,
		p.plan_name,
		s.customer_id,
		s.start_date,
		ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.start_date DESC) AS rank
	FROM subscriptions AS s
	INNER JOIN plans AS p
		ON s.plan_id = p.plan_id
	WHERE s.start_date <= '2020-12-31')
SELECT
	sp.plan_id,
	sp.plan_name,
	COUNT(*) AS customer_count,
	ROUND(100 * COUNT(*) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions)) AS percentage
FROM sub_plan AS sp
INNER JOIN plans AS p
	ON sp.plan_id = p.plan_id
WHERE rank = 1
GROUP BY sp.plan_id, sp.plan_name
ORDER BY sp.plan_id;

-- Result query:
--  plan_id | plan_name     | customer_count | percentage
-- ---------+---------------+----------------+------------
--        0 | trial         |             19 |          1
--        1 | basic monthly |            224 |         22
--        2 | pro monthly   |            326 |         32
--        3 | pro annual    |            195 |         19
--        4 | churn         |            236 |         23

-- 8. How many customers have upgraded to an annual plan in 2020?
SELECT
	COUNT(DISTINCT customer_id) AS customer_count
FROM subscriptions
WHERE DATE_PART('year', start_date) = 2020
AND plan_id = 3;

-- 195 customers upgraded to an annual plan in 2020.
-- Result query:
-- customers_count 
-- ---------------
--             195

-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH annual AS (
	SELECT 
		customer_id,
		start_date AS annual_date
	FROM subscriptions
	WHERE plan_id = 3),
	
	trial AS (
	SELECT 
		customer_id,
		start_date AS trial_date
	FROM subscriptions
	WHERE plan_id = 0)
	
SELECT
	ROUND(AVG(a.annual_date - t.trial_date)) AS avg_days
FROM annual AS a
INNER JOIN trial AS t
	ON a.customer_id = t.customer_id;

-- It took 105 average days for a customer switch to an annual plan from the day joined in 2020.
-- Result query:
-- avg_days 
-- --------
--      105

-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH annual AS (
	SELECT 
		customer_id,
		start_date AS annual_date
	FROM subscriptions
	WHERE plan_id = 3),
	
	trial AS (
	SELECT 
		customer_id,
		start_date AS trial_date
	FROM subscriptions
	WHERE plan_id = 0),
	
	bins AS (
	SELECT 
		WIDTH_BUCKET(a.annual_date - t.trial_date, 0, 360, 12) AS avg_days_to_upgrade
	FROM trial AS t
	JOIN annual AS a
  		ON t.customer_id = a.customer_id)
  
SELECT 
  ((avg_days_to_upgrade - 1) * 30 || ' - ' || (avg_days_to_upgrade) * 30) || ' days' AS breakdown, 
  COUNT(*) AS customers
FROM bins
GROUP BY avg_days_to_upgrade
ORDER BY avg_days_to_upgrade;

-- Result query:
-- breakdown      | customers
-- ---------------+----------
-- 0 - 30 days    |       48
-- 30 - 60 days   |       25
-- 60 - 90 days   |       33
-- 90 - 120 days  |       35
-- 120 - 150 days |       43
-- 150 - 180 days |       35
-- 180 - 210 days |       27
-- 210 - 240 days |        4
-- 240 - 270 days |        5
-- 270 - 300 days |        1
-- 300 - 330 days |        1
-- 330 - 360 days |        1

-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH sub_plan AS (
	SELECT 
		plan_id,
		customer_id,
		start_date,
		LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS lead_id
	FROM subscriptions
	WHERE DATE_PART('year', start_date) = 2020)
SELECT
	COUNT(*) as customer_count
FROM sub_plan 
WHERE lead_id = 1 AND plan_id = 2;

-- 0 customer downgraded from a pro monthly to a basic monthly plan in 2020.
-- Result query:
-- customers_count 
-- ---------------
--              0


