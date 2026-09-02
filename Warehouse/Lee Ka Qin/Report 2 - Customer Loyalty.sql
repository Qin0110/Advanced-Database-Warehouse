SET SQLBLANKLINES ON
SET LINESIZE 250
SET PAGESIZE 100
CLEAR BREAKS
CLEAR COLUMNS
 
COLUMN state           FORMAT A15
COLUMN area            FORMAT A18
COLUMN customer_type   FORMAT A12
COLUMN membership_tier FORMAT A10
COLUMN quarter_        FORMAT A6
COLUMN status_         FORMAT A10

TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 1 : NEW vs RECURRING CUSTOMERS BY YEAR' SKIP 1 -
       LEFT 'National  |  all branches  |  2020-2026' SKIP 1 -
       LEFT 'NOTE: all customers are New in 2020 by construction' SKIP 1 -
       LEFT '========================================================' SKIP 2
 
WITH acquisition AS (
    SELECT c.CUSTOMERID,
           MIN(d.CAL_DATE)                     AS first_order_date,
           EXTRACT(YEAR FROM MIN(d.CAL_DATE))  AS cohort_year
    FROM   SALES_FACT f
    JOIN   CUSTOMER_DIM      c  ON c.CUSTOMERKEY        = f.CUSTOMERKEY
    JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
    JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
    WHERE  c.CUSTOMERKEY <> -1
    AND    op.ORDER_STATUS <> 'Cancelled'
    GROUP  BY c.CUSTOMERID
),
activity AS (
    SELECT c.CUSTOMERID,
           a.cohort_year,
           d.CAL_YEAR                                       AS activity_year,
           d.CAL_QUARTER                                    AS quarter_,
           b.BRANCHSTATE                                    AS state,
           b.BRANCHAREA                                     AS area,
           CASE WHEN c.MEMBERID IS NULL THEN 'Non-Member'
                ELSE 'Member' END                           AS customer_type,
           NVL(c.MEMBERSHIPTYPE, 'None')                    AS membership_tier,
           f.ORDERNO,
           f.NETLINEAMOUNT
    FROM   SALES_FACT f
    JOIN   CUSTOMER_DIM      c  ON c.CUSTOMERKEY        = f.CUSTOMERKEY
    JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
    JOIN   BRANCH_DIM        b  ON b.BRANCHKEY          = f.BRANCHKEY
    JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
    JOIN   acquisition       a  ON a.CUSTOMERID         = c.CUSTOMERID
    WHERE  c.CUSTOMERKEY <> -1
    AND    op.ORDER_STATUS <> 'Cancelled'
)
SELECT activity_year,
       COUNT(DISTINCT CUSTOMERID)                           AS active_customers,
       COUNT(DISTINCT CASE WHEN cohort_year = activity_year
                           THEN CUSTOMERID END)             AS new_customers,
       COUNT(DISTINCT CASE WHEN cohort_year < activity_year
                           THEN CUSTOMERID END)             AS recurring_customers,
       ROUND(100 * COUNT(DISTINCT CASE WHEN cohort_year < activity_year
                                       THEN CUSTOMERID END)
             / NULLIF(COUNT(DISTINCT CUSTOMERID), 0), 2)    AS recurring_share_pct,
       ROUND(100 * COUNT(DISTINCT CASE WHEN cohort_year < activity_year
                                       THEN CUSTOMERID END)
             / NULLIF(LAG(COUNT(DISTINCT CUSTOMERID))
                          OVER (ORDER BY activity_year), 0), 2)
                                                            AS retention_rate_pct,
       COUNT(DISTINCT ORDERNO)                              AS orders,
       ROUND(COUNT(DISTINCT ORDERNO) * 1.0
             / NULLIF(COUNT(DISTINCT CUSTOMERID), 0), 2)    AS orders_per_customer,
       ROUND(SUM(NETLINEAMOUNT), 2)                         AS revenue_rm,
       ROUND(SUM(NETLINEAMOUNT)
             / NULLIF(COUNT(DISTINCT CUSTOMERID), 0), 2)    AS revenue_per_customer_rm
FROM   activity
GROUP  BY activity_year
ORDER  BY activity_year;
 
TTITLE OFF


TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 1b : NEW vs RECURRING BY STATE AND MEMBER TYPE' SKIP 1 -
       LEFT 'Drill-down from Level 1  |  adds state + member status' SKIP 1 -
       LEFT '========================================================' SKIP 2
 
BREAK ON state SKIP 1 ON customer_type
 
WITH acquisition AS (
    SELECT c.CUSTOMERID,
           EXTRACT(YEAR FROM MIN(d.CAL_DATE)) AS cohort_year
    FROM   SALES_FACT f
    JOIN   CUSTOMER_DIM      c  ON c.CUSTOMERKEY        = f.CUSTOMERKEY
    JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
    JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
    WHERE  c.CUSTOMERKEY <> -1
    AND    op.ORDER_STATUS <> 'Cancelled'
    GROUP  BY c.CUSTOMERID
)
SELECT b.BRANCHSTATE                                        AS state,
       CASE WHEN c.MEMBERID IS NULL THEN 'Non-Member'
            ELSE 'Member' END                               AS customer_type,
       d.CAL_YEAR                                           AS activity_year,
       COUNT(DISTINCT c.CUSTOMERID)                         AS active_customers,
       COUNT(DISTINCT CASE WHEN a.cohort_year = d.CAL_YEAR
                           THEN c.CUSTOMERID END)           AS new_customers,
       COUNT(DISTINCT CASE WHEN a.cohort_year < d.CAL_YEAR
                           THEN c.CUSTOMERID END)           AS recurring_customers,
       ROUND(100 * COUNT(DISTINCT CASE WHEN a.cohort_year < d.CAL_YEAR
                                       THEN c.CUSTOMERID END)
             / NULLIF(COUNT(DISTINCT c.CUSTOMERID), 0), 2)  AS recurring_share_pct,
       COUNT(DISTINCT f.ORDERNO)                            AS orders,
       ROUND(COUNT(DISTINCT f.ORDERNO) * 1.0
             / NULLIF(COUNT(DISTINCT c.CUSTOMERID), 0), 2)  AS orders_per_customer,
       ROUND(SUM(f.NETLINEAMOUNT), 2)                       AS revenue_rm,
       ROUND(SUM(f.NETLINEAMOUNT)
             / NULLIF(COUNT(DISTINCT c.CUSTOMERID), 0), 2)  AS revenue_per_customer_rm
FROM   SALES_FACT f
JOIN   CUSTOMER_DIM      c  ON c.CUSTOMERKEY        = f.CUSTOMERKEY
JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
JOIN   BRANCH_DIM        b  ON b.BRANCHKEY          = f.BRANCHKEY
JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
JOIN   acquisition       a  ON a.CUSTOMERID         = c.CUSTOMERID
WHERE  c.CUSTOMERKEY <> -1
AND    op.ORDER_STATUS <> 'Cancelled'
GROUP  BY b.BRANCHSTATE,
         CASE WHEN c.MEMBERID IS NULL THEN 'Non-Member' ELSE 'Member' END,
         d.CAL_YEAR
ORDER  BY b.BRANCHSTATE, customer_type, d.CAL_YEAR;
 
CLEAR BREAKS
TTITLE OFF

TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 2 : NEW vs RECURRING BY QUARTER AND AREA' SKIP 1 -
       LEFT 'Finest grain  |  area x quarter x member type' SKIP 1 -
       LEFT 'CAUTION: quarterly counts do not sum to annual totals' SKIP 1 -
       LEFT '========================================================' SKIP 2
 
BREAK ON state SKIP 1 ON area SKIP 1 ON activity_year
 
WITH acquisition AS (
    SELECT c.CUSTOMERID,
           EXTRACT(YEAR FROM MIN(d.CAL_DATE)) AS cohort_year
    FROM   SALES_FACT f
    JOIN   CUSTOMER_DIM      c  ON c.CUSTOMERKEY        = f.CUSTOMERKEY
    JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
    JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
    WHERE  c.CUSTOMERKEY <> -1
    AND    op.ORDER_STATUS <> 'Cancelled'
    GROUP  BY c.CUSTOMERID
)
SELECT b.BRANCHSTATE                                        AS state,
       b.BRANCHAREA                                         AS area,
       d.CAL_YEAR                                           AS activity_year,
       d.CAL_QUARTER                                        AS quarter_,
       CASE WHEN c.MEMBERID IS NULL THEN 'Non-Member'
            ELSE 'Member' END                               AS customer_type,
       COUNT(DISTINCT c.CUSTOMERID)                         AS active_customers,
       COUNT(DISTINCT CASE WHEN a.cohort_year = d.CAL_YEAR
                           THEN c.CUSTOMERID END)           AS new_customers,
       COUNT(DISTINCT CASE WHEN a.cohort_year < d.CAL_YEAR
                           THEN c.CUSTOMERID END)           AS recurring_customers,
       ROUND(100 * COUNT(DISTINCT CASE WHEN a.cohort_year < d.CAL_YEAR
                                       THEN c.CUSTOMERID END)
             / NULLIF(COUNT(DISTINCT c.CUSTOMERID), 0), 2)  AS recurring_share_pct,
       COUNT(DISTINCT f.ORDERNO)                            AS orders,
       ROUND(COUNT(DISTINCT f.ORDERNO) * 1.0
             / NULLIF(COUNT(DISTINCT c.CUSTOMERID), 0), 2)  AS orders_per_customer,
       ROUND(SUM(f.NETLINEAMOUNT), 2)                       AS revenue_rm
FROM   SALES_FACT f
JOIN   CUSTOMER_DIM      c  ON c.CUSTOMERKEY        = f.CUSTOMERKEY
JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
JOIN   BRANCH_DIM        b  ON b.BRANCHKEY          = f.BRANCHKEY
JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
JOIN   acquisition       a  ON a.CUSTOMERID         = c.CUSTOMERID
WHERE  c.CUSTOMERKEY <> -1
AND    op.ORDER_STATUS <> 'Cancelled'
AND    d.CAL_YEAR >= 2024          -- widen or remove for the full period
GROUP  BY b.BRANCHSTATE, b.BRANCHAREA, d.CAL_YEAR, d.CAL_QUARTER,
         CASE WHEN c.MEMBERID IS NULL THEN 'Non-Member' ELSE 'Member' END
ORDER  BY b.BRANCHSTATE, b.BRANCHAREA, d.CAL_YEAR, d.CAL_QUARTER, customer_type;
 
CLEAR BREAKS
TTITLE OFF

TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 2b : AREA LOYALTY RANKING' SKIP 1 -
       LEFT 'Full period 2020-2026  |  ranked by orders per customer' SKIP 1 -
       LEFT '========================================================' SKIP 2
 
WITH acquisition AS (
    SELECT c.CUSTOMERID,
           EXTRACT(YEAR FROM MIN(d.CAL_DATE)) AS cohort_year
    FROM   SALES_FACT f
    JOIN   CUSTOMER_DIM      c  ON c.CUSTOMERKEY        = f.CUSTOMERKEY
    JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
    JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
    WHERE  c.CUSTOMERKEY <> -1
    AND    op.ORDER_STATUS <> 'Cancelled'
    GROUP  BY c.CUSTOMERID
),
area_loyalty AS (
    SELECT b.BRANCHSTATE                                    AS state,
           b.BRANCHAREA                                     AS area,
           COUNT(DISTINCT c.CUSTOMERID)                     AS customers,
           COUNT(DISTINCT CASE WHEN c.MEMBERID IS NOT NULL
                               THEN c.CUSTOMERID END)       AS members,
           COUNT(DISTINCT f.ORDERNO)                        AS orders,
           SUM(f.NETLINEAMOUNT)                             AS revenue,
           -- customers who returned in a year after their first
           COUNT(DISTINCT CASE WHEN a.cohort_year < d.CAL_YEAR
                               THEN c.CUSTOMERID END)       AS returning_customers
    FROM   SALES_FACT f
    JOIN   CUSTOMER_DIM      c  ON c.CUSTOMERKEY        = f.CUSTOMERKEY
    JOIN   DATE_DIM          d  ON d.DATE_KEY           = f.DATEKEY
    JOIN   BRANCH_DIM        b  ON b.BRANCHKEY          = f.BRANCHKEY
    JOIN   ORDER_PROFILE_DIM op ON op.ORDER_PROFILE_KEY = f.ORDERPROFILEKEY
    JOIN   acquisition       a  ON a.CUSTOMERID         = c.CUSTOMERID
    WHERE  c.CUSTOMERKEY <> -1
    AND    op.ORDER_STATUS <> 'Cancelled'
    GROUP  BY b.BRANCHSTATE, b.BRANCHAREA
)
SELECT state, area, customers, members,
       ROUND(100 * members / NULLIF(customers, 0), 2)       AS member_share_pct,
       returning_customers,
       ROUND(100 * returning_customers
             / NULLIF(customers, 0), 2)                     AS ever_returned_pct,
       orders,
       ROUND(orders / NULLIF(customers, 0), 2)              AS orders_per_customer,
       RANK() OVER (ORDER BY orders / NULLIF(customers, 0) DESC)
                                                            AS loyalty_rank,
       ROUND(revenue, 2)                                    AS revenue_rm,
       ROUND(revenue / NULLIF(customers, 0), 2)             AS revenue_per_customer_rm
FROM   area_loyalty
ORDER  BY orders_per_customer DESC;
 
TTITLE OFF