
--to find the cloumn & datatype
select column_name,data_type
from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME='customers'

--to find the details in customers
select *
from [dbo].[orders]

-- to find the orderdate 
select min(order_purchase_timestamp) as start_date,
	   max(order_purchase_timestamp) as end_date
	   from [dbo].[orders]

--find the details in cutomers
select *
from [dbo].[customers]

--to find the count of citites and states  who ordered during the given period

select count(distinct customer_city) as unique_cities,
	   count(distinct customer_state) as unique_state
from [dbo].[customers]

--Is there a growing trend in the number of orders placed over the past years?

select year(order_purchase_timestamp) as order_year,
		count(order_id) as total_orders
		from [dbo].[orders]
		group by year(order_purchase_timestamp)
		order by order_year
--Can we see some kind of monthly seasonality in terms of the no. of orders being placed?

select month(order_purchase_timestamp) as order_month,
		count(order_id) as total_order
		from [dbo].[orders]
		group by month(order_purchase_timestamp)
		order by order_month
--or

select top 3 month(order_purchase_timestamp) as month_number,
		DateName(month,(order_purchase_timestamp)) as month_name,
		count(order_id) as total_order
		from [dbo].[orders]
		group by month(order_purchase_timestamp) ,DateName(month,(order_purchase_timestamp))
		order by total_order desc

--During what time of the day do Brazilian customers mostly place their orders

select	
	case
		when DATEPART(HOUR,order_purchase_timestamp) BETWEEN 0 AND 6 THEN 'Dawn'
		when DATEPART(hour,order_purchase_timestamp) BETWEEN 7 AND 12 THEN 'Morning'
		when DATEPART(hour,order_purchase_timestamp) BETWEEN 13 AND 18 THEN 'Afternoon'
		else 'night'
		END AS time_of_day,
		count(order_id)as total_order
		from [dbo].[orders]
		GROUP BY 
  CASE 
    WHEN DATEPART(HOUR, order_purchase_timestamp) BETWEEN 0 AND 6 THEN 'Dawn'
    WHEN DATEPART(HOUR, order_purchase_timestamp) BETWEEN 7 AND 12 THEN 'Morning'
    WHEN DATEPART(HOUR, order_purchase_timestamp) BETWEEN 13 AND 18 THEN 'Afternoon'
    ELSE 'night'
  END
ORDER BY total_order DESC;

--Month-on-month orders placed in each state

select year(o.order_purchase_timestamp) as order_year,
       month(o.order_purchase_timestamp) as order_month,
	   c.customer_state,
	   count(o.order_id) as total_order
	   from [dbo].[orders] o
	   join [dbo].[customers] c
	   on o.customer_id=c.customer_id
	   group by 
			year(o.order_purchase_timestamp) ,
			month(o.order_purchase_timestamp) ,
			c.customer_state
	   order by 
			order_year,
			order_month,
			customer_state

--How are the customers distributed across all the states?
SELECT 
  customer_state,
  COUNT(DISTINCT customer_id) AS total_customers
FROM customers
GROUP BY customer_state
ORDER BY total_customers DESC;

--Analyze how much money is moving via e-commerce. You’ll do this by looking at order prices, freight charges, and overall payment values
--Get the % increase in the cost of orders from year 2017 to 2018 (include months between Jan to Aug only).
WITH yearly_payments AS (
    SELECT 
        YEAR(o.order_purchase_timestamp) AS order_year,
        SUM(p.payment_value) AS total_payment
    FROM orders o
    JOIN [dbo].[payments] p ON o.order_id = p.order_id
    WHERE MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
      AND YEAR(o.order_purchase_timestamp) IN (2017, 2018)
    GROUP BY YEAR(o.order_purchase_timestamp)
)
SELECT 
    MAX(CASE WHEN order_year = 2017 THEN total_payment END) AS total_2017,
    MAX(CASE WHEN order_year = 2018 THEN total_payment END) AS total_2018,
    ROUND(((MAX(CASE WHEN order_year = 2018 THEN total_payment END) - 
            MAX(CASE WHEN order_year = 2017 THEN total_payment END)) * 100.0) /
            MAX(CASE WHEN order_year = 2017 THEN total_payment END), 2) AS percentage_increase
FROM yearly_payments;

--Calculate the Total & Average value of order price for each state
SELECT 
    c.customer_state,
    SUM(p.payment_value) AS total_payment,
    ROUND(AVG(p.payment_value), 2) AS avg_payment
FROM orders o
JOIN [dbo].[payments] p ON o.order_id = p.order_id
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY total_payment DESC;

--Total & Avg Freight per State
SELECT 
    c.customer_state,
    SUM(oi.freight_value) AS total_freight,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_state
ORDER BY total_freight DESC;

--Analysis based on sales, freight and delivery time
--Delivery Time & Estimate Difference (Single Query)
SELECT 
    order_id,
    DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) AS time_to_deliver,
    DATEDIFF(DAY, order_estimated_delivery_date, order_delivered_customer_date) AS diff_estimated_delivery
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

--Top 5 States by Average Freight
SELECT 
    c.customer_state,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_state
ORDER BY avg_freight DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;  -- Top 5 Highest

--Top 5 States by Average Delivery Time
SELECT 
    c.customer_state,
    ROUND(AVG(DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date)), 2) AS avg_delivery_time
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_time DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;  -- Top 5 Slowest

--Top 5 States with Fast Delivery vs Estimate
SELECT 
    c.customer_state,
    ROUND(AVG(DATEDIFF(DAY, o.order_estimated_delivery_date, o.order_delivered_customer_date)), 2) AS avg_diff_estimated_delivery
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_diff_estimated_delivery ASC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;  -- Most Ahead of Time

--Month-on-Month Orders by Payment Type
SELECT 
    YEAR(o.order_purchase_timestamp) AS order_year,
    MONTH(o.order_purchase_timestamp) AS order_month,
    p.payment_type,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN payments p ON o.order_id = p.order_id
GROUP BY 
    YEAR(o.order_purchase_timestamp),
    MONTH(o.order_purchase_timestamp),
    p.payment_type
ORDER BY 
    order_year,
    order_month,
    p.payment_type;

-- Orders by Number of Installments
SELECT 
    payment_installments,
    COUNT(DISTINCT order_id) AS total_orders
FROM payments
GROUP BY payment_installments
ORDER BY payment_installments;




