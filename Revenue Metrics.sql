-- Creating a summary table of monthly revenue for each user and game
WITH monthly_revenue AS (
SELECT 
	user_id 
	, game_name 
	, CAST (DATE_TRUNC ('month', payment_date) AS DATE) AS payment_month
	, SUM (revenue_amount_usd ) AS total_revenue
FROM games_payments gp 
GROUP BY
	user_id
	, game_name
	, payment_month),
-- Adding analytic functions to track previous and next months' payments and revenues
monthly_revenue_tracking AS (
SELECT 
	user_id
	, game_name
	, payment_month
	, CAST (payment_month + INTERVAL '1 month' AS DATE)  AS next_calendar_month
	, CAST (payment_month - INTERVAL '1 month' AS DATE)  AS prev_calendar_month
	, LEAD (payment_month) OVER (PARTITION BY user_id ORDER BY payment_month ASC) AS next_payment_month
	, LAG (payment_month) OVER (PARTITION BY user_id ORDER BY payment_month ASC) AS prev_payment_month
	, total_revenue
	, LAG (total_revenue) OVER (PARTITION BY user_id ORDER BY payment_month ASC) AS prev_month_revenue
FROM monthly_revenue)
-- Сalculating revenue metrics
SELECT 
	m.user_id
	, m.game_name
	, payment_month
	, total_revenue
	, CASE 
		WHEN prev_payment_month IS NULL 
		THEN total_revenue 
	END AS new_mrr 	
	, CASE 
		WHEN next_payment_month != next_calendar_month OR next_payment_month IS NULL 
		THEN total_revenue 
	END AS churned_revenue
	, CASE 
		WHEN prev_payment_month != prev_calendar_month 
		THEN total_revenue 
	END AS back_from_churn
	, CASE 
		WHEN prev_payment_month = prev_calendar_month AND total_revenue > prev_month_revenue 
		THEN  total_revenue - prev_month_revenue 
	END AS expansion_mrr
	, CASE 
		WHEN prev_payment_month = prev_calendar_month AND total_revenue < prev_month_revenue 
		THEN  total_revenue - prev_month_revenue 
	END AS сontraction_mrr
	, language
	, age 
FROM monthly_revenue_tracking m
LEFT JOIN games_paid_users gpu ON m.user_id = gpu.user_id;