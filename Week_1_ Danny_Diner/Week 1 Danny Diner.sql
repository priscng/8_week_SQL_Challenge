-- Create schema and table for danny_diner
CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

-- Create sales table
CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 
-- Create menu table
CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  
-- Create members table
CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

--------------------------
--Week #1: DANNY'S DINER--
--------------------------

-- 1. What is the total amount each customer spent at the restaurant?
SELECT
  	s.customer_id,
    SUM(m.price) as total_amount
FROM dannys_diner.sales AS s
INNER JOIN dannys_diner.menu AS m
ON m.product_id = s.product_id
GROUP BY 1
ORDER BY 2 DESC;

-- 2. How many days has each customer visited the restaurant?
SELECT
	customer_id,
  	COUNT(DISTINCT(order_date)) as total_days_visit
FROM dannys_diner.sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
SELECT
	customer_id,
    product_name
FROM 
  (SELECT
      s.customer_id,
      s.order_date,
      m.product_name,
      DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS rank
  FROM dannys_diner.sales AS s
  INNER JOIN dannys_diner.menu AS m
  ON m.product_id = s.product_id) sub
WHERE rank = 1
GROUP BY customer_id, product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT
    m.product_name,
    COUNT(m.product_name) as most_purchased
FROM dannys_diner.sales AS s
INNER JOIN dannys_diner.menu AS m
ON m.product_id = s.product_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 1;

-- 5. Which item was the most popular for each customer?
SELECT
	customer_id,
    product_name,
    order_count
FROM (
  SELECT
      s.customer_id,
      m.product_name,
      COUNT(m.product_name) as order_count,
      DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY COUNT(m.product_name) DESC) AS rank
  FROM dannys_diner.sales AS s
  INNER JOIN dannys_diner.menu AS m
  ON m.product_id = s.product_id
  GROUP BY s.customer_id, m.product_name
  ) sub
WHERE rank = 1;

-- 6. Which item was purchased first by the customer after they became a member?
SELECT
	customer_id,
    order_date,
    product_name
FROM 
  (SELECT
      s.customer_id,
      s.order_date,
      m.product_name,
      DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS rank
  FROM dannys_diner.sales AS s
  INNER JOIN dannys_diner.menu AS m
  ON m.product_id = s.product_id
  INNER JOIN dannys_diner.members AS c
  ON s.customer_id = c.customer_id
  WHERE s.order_date >= c.join_date) sub
WHERE rank = 1
GROUP BY customer_id, order_date, product_name;

-- 7. Which item was purchased just before the customer became a member?
SELECT
	customer_id,
    order_date,
    product_name
FROM 
  (SELECT
      s.customer_id,
      s.order_date,
      m.product_name,
      DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS rank
  FROM dannys_diner.sales AS s
  INNER JOIN dannys_diner.menu AS m
  ON m.product_id = s.product_id
  INNER JOIN dannys_diner.members AS c
  ON s.customer_id = c.customer_id
  WHERE s.order_date < c.join_date) sub
WHERE rank = 1
GROUP BY customer_id, order_date, product_name;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT
	customer_id,
    COUNT(DISTINCT(product_name)) AS items_ordered,
    SUM(price) as total_amount
FROM 
  (SELECT
      s.customer_id,
      s.order_date,
      m.product_name,
      m.price
  FROM dannys_diner.sales AS s
  INNER JOIN dannys_diner.menu AS m
  ON m.product_id = s.product_id
  INNER JOIN dannys_diner.members AS c
  ON s.customer_id = c.customer_id
  WHERE s.order_date < c.join_date) sub
GROUP BY customer_id
ORDER BY SUM(price);

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH points_table AS (
  SELECT 
  	*,
  	CASE WHEN product_id = 1 THEN price * 20
  	ELSE price * 10 END AS points
  FROM dannys_diner.menu)
SELECT
	customer_id,
    SUM(points) as total_points
FROM points_table as pt
INNER JOIN dannys_diner.sales AS s
ON pt.product_id = s.product_id
GROUP BY customer_id
ORDER BY customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT 
	s.customer_id, 
    SUM(CASE
      WHEN m.product_id = 1 THEN 20 * m.price
      WHEN s.order_date >= c.join_date AND s.order_date < c.join_date + (7* INTERVAL '1 day') THEN 20 * m.price
      ELSE 10 * m.price END) AS points
FROM dannys_diner.sales AS s
INNER JOIN dannys_diner.members as c
   ON c.customer_id = s.customer_id
INNER JOIN dannys_diner.menu AS m
   ON s.product_id = m.product_id
WHERE DATE_PART('month', s.order_date) = 1
GROUP BY s.customer_id
ORDER BY s.customer_id;

-------------------
--Bonus Questsion--
-------------------

-- Join All The Things
SELECT
	s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE WHEN s.order_date >= c.join_date THEN 'Y'
    ELSE 'N' END AS member
FROM dannys_diner.sales AS s
LEFT JOIN dannys_diner.members as c
   ON c.customer_id = s.customer_id
INNER JOIN dannys_diner.menu AS m
   ON s.product_id = m.product_id
ORDER BY s.customer_id, s.order_date, m.product_name;

-- Rank all things
WITH summary AS (
  SELECT
	s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE WHEN s.order_date >= c.join_date THEN 'Y'
    ELSE 'N' END AS member
  FROM dannys_diner.sales AS s
  LEFT JOIN dannys_diner.members as c
     ON c.customer_id = s.customer_id
  INNER JOIN dannys_diner.menu AS m
     ON s.product_id = m.product_id
  ORDER BY s.customer_id, s.order_date, m.product_name
  )
SELECT
	*, 
    CASE WHEN member = 'N' THEN NULL
    ELSE RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date) END AS ranking 
FROM summary

