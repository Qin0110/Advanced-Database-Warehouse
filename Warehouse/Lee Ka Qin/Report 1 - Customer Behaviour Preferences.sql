-- Report 1: Customer Order Preferences Behaviour
-- Overall Summary (Top Level)
TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 1 : NATIONAL CHANNEL MIX BY YEAR' SKIP 1 -
       LEFT 'Walk-In vs Online  |  all branches  |  2020-2026' SKIP 1 -
       LEFT '========================================================' SKIP 2
 
BREAK ON channel SKIP 1
 
SELECT op.ORDER_TYPE                                        AS channel,
       d.CAL_YEAR                                           AS order_year,
       COUNT(DISTINCT f.ORDERNO)                            AS orders,
       ROUND(100 * COUNT(DISTINCT f.ORDERNO)
             / SUM(COUNT(DISTINCT f.ORDERNO))
                   OVER (PARTITION BY d.CAL_YEAR), 2)       AS pct_of_year_orders,
       SUM(f.PURCHASEQUANTITY)                              AS units_sold,
       ROUND(SUM(f.NETLINEAMOUNT), 2)                       AS revenue_rm,
       ROUND(100 * SUM(f.NETLINEAMOUNT)
             / SUM(SUM(f.NETLINEAMOUNT))
                   OVER (PARTITION BY d.CAL_YEAR), 2)       AS pct_of_year_revenue,
       ROUND(SUM(f.NETLINEAMOUNT)
             / NULLIF(COUNT(DISTINCT f.ORDERNO), 0), 2)     AS avg_basket_rm,
       ROUND(COUNT(*) * 1.0
             / NULLIF(COUNT(DISTINCT f.ORDERNO), 0), 2)     AS lines_per_basket,
       ROUND(100 * (SUM(f.NETLINEAMOUNT)
             - LAG(SUM(f.NETLINEAMOUNT))
                   OVER (PARTITION BY op.ORDER_TYPE ORDER BY d.CAL_YEAR))
             / NULLIF(LAG(SUM(f.NETLINEAMOUNT))
                   OVER (PARTITION BY op.ORDER_TYPE ORDER BY d.CAL_YEAR), 0), 2)
                                                            AS yoy_revenue_growth_pct
FROM   SALES_FACT f
JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
WHERE  op.ORDER_STATUS <> 'Cancelled'
GROUP  BY op.ORDER_TYPE, d.CAL_YEAR
ORDER  BY op.ORDER_TYPE, d.CAL_YEAR;
CLEAR BREAKS
TTITLE OFF

-- Drill by Online Order Type (Delivery vs Pickup)
TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 1b : ONLINE SERVICE SPLIT BY YEAR' SKIP 1 -
       LEFT 'Pickup vs Delivery  |  ONLINE ORDERS ONLY' SKIP 1 -
       LEFT '========================================================' SKIP 2
 
BREAK ON online_service SKIP 1
 
SELECT op.SERVICE_TYPE                                      AS online_service,
       d.CAL_YEAR                                           AS order_year,
       COUNT(DISTINCT f.ORDERNO)                            AS orders,
       ROUND(100 * COUNT(DISTINCT f.ORDERNO)
             / SUM(COUNT(DISTINCT f.ORDERNO))
                   OVER (PARTITION BY d.CAL_YEAR), 2)       AS pct_of_online_year,
       SUM(f.PURCHASEQUANTITY)                              AS units_sold,
       ROUND(SUM(f.NETLINEAMOUNT), 2)                       AS revenue_rm,
       ROUND(SUM(f.NETLINEAMOUNT)
             / NULLIF(COUNT(DISTINCT f.ORDERNO), 0), 2)     AS avg_basket_rm,
       ROUND(COUNT(*) * 1.0
             / NULLIF(COUNT(DISTINCT f.ORDERNO), 0), 2)     AS lines_per_basket,
       ROUND(100 * (SUM(f.NETLINEAMOUNT)
             - LAG(SUM(f.NETLINEAMOUNT))
                   OVER (PARTITION BY op.SERVICE_TYPE ORDER BY d.CAL_YEAR))
             / NULLIF(LAG(SUM(f.NETLINEAMOUNT))
                   OVER (PARTITION BY op.SERVICE_TYPE ORDER BY d.CAL_YEAR), 0), 2)
                                                            AS yoy_revenue_growth_pct
FROM   SALES_FACT f
JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
WHERE  op.ORDER_STATUS <> 'Cancelled'
AND    op.ORDER_TYPE = 'Online'
GROUP  BY op.SERVICE_TYPE, d.CAL_YEAR
ORDER  BY op.SERVICE_TYPE, d.CAL_YEAR;
 
CLEAR BREAKS
TTITLE OFF


-- Drill by Quarter of YEAR
TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 2 : CHANNEL MIX BY QUARTER AND STATE' SKIP 1 -
       LEFT 'Drill-down from Level 1  |  adds quarter + state' SKIP 1 -
       LEFT '========================================================' SKIP 2

COLUMN quarter_ FORMAT A6;

BREAK ON state SKIP 1 ON order_year
 
SELECT b.BRANCHSTATE                                        AS state,
       d.CAL_YEAR                                           AS order_year,
       d.CAL_QUARTER                                        AS quarter_,
       COUNT(DISTINCT f.ORDERNO)                            AS total_orders,
       COUNT(DISTINCT CASE WHEN op.ORDER_TYPE = 'Walk-In'
                           THEN f.ORDERNO END)              AS walkin_orders,
       COUNT(DISTINCT CASE WHEN op.ORDER_TYPE = 'Online'
                           THEN f.ORDERNO END)              AS online_orders,
       ROUND(100 * COUNT(DISTINCT CASE WHEN op.ORDER_TYPE = 'Online'
                                       THEN f.ORDERNO END)
             / NULLIF(COUNT(DISTINCT f.ORDERNO), 0), 2)     AS online_share_pct,
       ROUND(SUM(CASE WHEN op.ORDER_TYPE = 'Walk-In'
                      THEN f.NETLINEAMOUNT ELSE 0 END), 2)  AS walkin_revenue_rm,
       ROUND(SUM(CASE WHEN op.ORDER_TYPE = 'Online'
                      THEN f.NETLINEAMOUNT ELSE 0 END), 2)  AS online_revenue_rm,
       ROUND(SUM(CASE WHEN op.ORDER_TYPE = 'Walk-In' THEN f.NETLINEAMOUNT END)
             / NULLIF(COUNT(DISTINCT CASE WHEN op.ORDER_TYPE = 'Walk-In'
                                          THEN f.ORDERNO END), 0), 2)
                                                            AS walkin_basket_rm,
       ROUND(SUM(CASE WHEN op.ORDER_TYPE = 'Online' THEN f.NETLINEAMOUNT END)
             / NULLIF(COUNT(DISTINCT CASE WHEN op.ORDER_TYPE = 'Online'
                                          THEN f.ORDERNO END), 0), 2)
                                                            AS online_basket_rm,
       COUNT(DISTINCT b.BRANCHID)                           AS branches_trading
FROM   SALES_FACT f
JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
JOIN   BRANCH_DIM        b  ON b.BRANCHKEY          = f.BRANCHKEY
WHERE  op.ORDER_STATUS <> 'Cancelled'
GROUP  BY b.BRANCHSTATE, d.CAL_YEAR, d.CAL_QUARTER
ORDER  BY b.BRANCHSTATE, d.CAL_YEAR, d.CAL_QUARTER;
CLEAR BREAKS
TTITLE OFF



-- LEVEL 3 : CHANNEL MIX BY AREA AND BRANCH
COLUMN BRANCH FORMAT A25;
COLUMN AREA FORMAT A20;

TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 3 : CHANNEL MIX BY AREA AND BRANCH' SKIP 1 -
       LEFT 'Finest grain  |  state -> area -> branch' SKIP 1 -
       LEFT 'CAUTION: small cell counts - read shares, not raw values' SKIP 1 -
       LEFT '========================================================' SKIP 2
 
BREAK ON state SKIP 1 ON area SKIP 1 ON branch ON order_year
 
SELECT b.BRANCHSTATE                                        AS state,
       b.BRANCHAREA                                         AS area,
       b.BRANCHNAME                                         AS branch,
       d.CAL_YEAR                                           AS order_year,
       op.ORDER_TYPE                                        AS channel,
       COUNT(DISTINCT f.ORDERNO)                            AS orders,
       ROUND(100 * COUNT(DISTINCT f.ORDERNO)
             / SUM(COUNT(DISTINCT f.ORDERNO))
                   OVER (PARTITION BY b.BRANCHAREA, d.CAL_YEAR), 2)
                                                            AS pct_of_area_year,
       SUM(f.PURCHASEQUANTITY)                              AS units_sold,
       ROUND(SUM(f.NETLINEAMOUNT), 2)                       AS revenue_rm,
       ROUND(SUM(f.NETLINEAMOUNT)
             / NULLIF(COUNT(DISTINCT f.ORDERNO), 0), 2)     AS avg_basket_rm
FROM   SALES_FACT f
JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
JOIN   BRANCH_DIM        b  ON b.BRANCHKEY          = f.BRANCHKEY
WHERE  op.ORDER_STATUS <> 'Cancelled'
GROUP  BY b.BRANCHSTATE, b.BRANCHAREA, b.BRANCHNAME, d.CAL_YEAR, op.ORDER_TYPE
ORDER  BY b.BRANCHSTATE, b.BRANCHAREA, d.CAL_YEAR, op.ORDER_TYPE;
 
CLEAR BREAKS
TTITLE OFF



-- LEVEL 3b
TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 3b : AREA RANKING BY ONLINE ADOPTION' SKIP 1 -
       LEFT 'Full period 2020-2026  |  ranked by online share' SKIP 1 -
       LEFT '========================================================' SKIP 2
 
BREAK ON state SKIP 1
 
WITH area_channel AS (
    SELECT b.BRANCHSTATE AS state,
           b.BRANCHAREA  AS area,
           COUNT(DISTINCT f.ORDERNO) AS total_orders,
           COUNT(DISTINCT CASE WHEN op.ORDER_TYPE = 'Online'
                               THEN f.ORDERNO END) AS online_orders,
           COUNT(DISTINCT CASE WHEN op.ORDER_TYPE = 'Walk-In'
                               THEN f.ORDERNO END) AS walkin_orders,
           ROUND(SUM(f.NETLINEAMOUNT), 2) AS revenue_rm,
           SUM(CASE WHEN op.ORDER_TYPE = 'Online'
                    THEN f.NETLINEAMOUNT END) AS online_revenue,
           SUM(CASE WHEN op.ORDER_TYPE = 'Walk-In'
                    THEN f.NETLINEAMOUNT END) AS walkin_revenue
    FROM   SALES_FACT f
    JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
    JOIN   BRANCH_DIM        b  ON b.BRANCHKEY          = f.BRANCHKEY
    WHERE  op.ORDER_STATUS <> 'Cancelled'
    GROUP  BY b.BRANCHSTATE, b.BRANCHAREA
)
SELECT state, area, total_orders,
       online_orders,
       ROUND(100 * online_orders / NULLIF(total_orders, 0), 2) AS online_share_pct,
       RANK() OVER (ORDER BY online_orders / NULLIF(total_orders, 0) DESC)
                                                               AS online_rank,
       walkin_orders,
       ROUND(100 * walkin_orders / NULLIF(total_orders, 0), 2) AS walkin_share_pct,
       RANK() OVER (ORDER BY walkin_orders / NULLIF(total_orders, 0) DESC)
                                                               AS walkin_rank,
       revenue_rm,
       ROUND(online_revenue / NULLIF(online_orders, 0), 2)     AS online_basket_rm,
       ROUND(walkin_revenue / NULLIF(walkin_orders, 0), 2)     AS walkin_basket_rm
FROM   area_channel
ORDER  BY online_share_pct DESC;
 
CLEAR BREAKS
TTITLE OFF

-- Bottom Level
COLUMN state      FORMAT A15;
COLUMN area       FORMAT A18;
COLUMN branch     FORMAT A25;
COLUMN month_name FORMAT A10;
COLUMN channel    FORMAT A8;

TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 3e : CHANNEL MIX BY AREA AND MONTH' SKIP 1 -
       LEFT 'Finest grain  |  branch x month x channel' SKIP 1 -
       LEFT 'CAUTION: ~10 orders per branch-month - read trends only' SKIP 1 -
       LEFT '========================================================' SKIP 2

BREAK ON state SKIP 1 ON area SKIP 1 ON branch ON order_year

SELECT b.BRANCHSTATE                                        AS state,
       b.BRANCHAREA                                         AS area,
       b.BRANCHNAME                                         AS branch,
       d.CAL_YEAR                                           AS order_year,
       d.CAL_MONTH_YEAR                                     AS month_no,
       INITCAP(TRIM(d.CAL_MONTH_NAME))                      AS month_name,
       op.ORDER_TYPE                                        AS channel,
       COUNT(DISTINCT f.ORDERNO)                            AS orders,
       ROUND(100 * COUNT(DISTINCT f.ORDERNO)
             / SUM(COUNT(DISTINCT f.ORDERNO))
                   OVER (PARTITION BY b.BRANCHNAME, d.CAL_YEAR,
                                      d.CAL_MONTH_YEAR), 2) AS pct_of_branch_month,
       SUM(f.PURCHASEQUANTITY)                              AS units_sold,
       ROUND(SUM(f.NETLINEAMOUNT), 2)                       AS revenue_rm,
       ROUND(SUM(f.NETLINEAMOUNT)
             / NULLIF(COUNT(DISTINCT f.ORDERNO), 0), 2)     AS avg_basket_rm
FROM   SALES_FACT f
JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
JOIN   BRANCH_DIM        b  ON b.BRANCHKEY          = f.BRANCHKEY
WHERE  op.ORDER_STATUS <> 'Cancelled'
AND    d.CAL_YEAR = 2025          -- change year, or comment out for all years
GROUP  BY b.BRANCHSTATE, b.BRANCHAREA, b.BRANCHNAME,
         d.CAL_YEAR, d.CAL_MONTH_YEAR, d.CAL_MONTH_NAME, op.ORDER_TYPE
ORDER  BY b.BRANCHSTATE, b.BRANCHAREA, d.CAL_YEAR, d.CAL_MONTH_YEAR, op.ORDER_TYPE;

CLEAR BREAKS
TTITLE OFF