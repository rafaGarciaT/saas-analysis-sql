-- Current Profitability Analysis

WITH profitability AS (
	SELECT
		v.user_account_id,
		v.month_ref::date AS month_ref,
		v.subscription_revenue,
		v.estimated_ad_revenue,
		(v.subscription_revenue + v.estimated_ad_revenue)::numeric(12, 4) AS total_revenue,
		v.estimated_ai_cost,
		v.baseline_cost,
		v.estimated_profit,
		ROUND(
			(
				v.estimated_profit
				/ NULLIF((v.subscription_revenue + v.estimated_ad_revenue), 0)
			) * 100,
			2
		) AS profit_margin_pct
	FROM vw_monthly_user_profitability v
	-- Last 3 months including current month.
	WHERE v.month_ref >= date_trunc('month', CURRENT_DATE) - INTERVAL '2 months'
)
SELECT
	p.month_ref,
	p.user_account_id,
	ua.username,
	ua.email,
	p.subscription_revenue,
	p.estimated_ad_revenue,
	p.total_revenue,
	p.estimated_ai_cost,
	p.baseline_cost,
	p.estimated_profit,
	p.profit_margin_pct
FROM profitability p
JOIN user_account ua ON ua.user_account_id = p.user_account_id
ORDER BY p.month_ref DESC, p.estimated_profit DESC, p.user_account_id;