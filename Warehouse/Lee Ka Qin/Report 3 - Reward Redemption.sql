SET LINESIZE 250
SET PAGESIZE 100
CLEAR BREAKS
CLEAR COLUMNS
 
COLUMN reward_name     FORMAT A28
COLUMN reward_type     FORMAT A16
COLUMN tier_           FORMAT A10
COLUMN quarter_        FORMAT A6
 
 
--==============================================================================
-- LEVEL 1 : REDEMPTION VOLUME BY YEAR
--   Grain     : one row per year
--   Read this : POINTS_BURNED is the loyalty liability being discharged.
--               GROSS_COST_RM is what the company gave away in face value.
--==============================================================================
TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 1 : REWARD REDEMPTION VOLUME BY YEAR' SKIP 1 -
       LEFT 'All rewards  |  all members  |  2020-2026' SKIP 1 -
       LEFT 'NOTE: 2026 ends 20 July - counts understated, rates are not' SKIP 1 -
       LEFT '========================================================' SKIP 2
 
SELECT d.CAL_YEAR                                           AS issue_year,
       COUNT(*)                                             AS redemptions,
       COUNT(DISTINCT c.CUSTOMERID)                         AS redeeming_members,
       ROUND(COUNT(*) * 1.0
             / NULLIF(COUNT(DISTINCT c.CUSTOMERID), 0), 2)  AS redemptions_per_member,
       SUM(f.QUANTITYREDEEMED)                              AS vouchers_issued,
       SUM(f.POINTSPEND)                                    AS point_spent,
       ROUND(AVG(f.POINTSPEND), 0)                          AS avg_points_each,
       ROUND(SUM(f.REWARDVALUE), 2)                         AS gross_cost_rm,
       SUM(f.USEDCOUNT)                                     AS used_,
       SUM(f.EXPIREDCOUNT)                                  AS expired_,
       SUM(f.ACTIVECOUNT)                                   AS still_active,
       ROUND(100 * SUM(f.EXPIREDCOUNT)
             / NULLIF(SUM(f.USEDCOUNT) + SUM(f.EXPIREDCOUNT), 0), 2)
                                                            AS settled_waste_pct
FROM   REWARD_FACT  f
JOIN   DATE_DIM     d ON d.DATE_KEY    = f.DATEKEY
JOIN   CUSTOMER_DIM c ON c.CUSTOMERKEY = f.CUSTOMERKEY
GROUP  BY d.CAL_YEAR
ORDER  BY d.CAL_YEAR;
 
TTITLE OFF

--==============================================================================
-- LEVEL 1b : REDEMPTION BY REWARD TYPE AND YEAR
--   Grain      : one row per reward type per year
--   Drill from : Level 1, splitting into Discount / Free Delivery / Gift
--   Read this  : PCT_OF_YEAR shows type MIX, so a shift in what members want
--                is visible even while total volume grows.
--==============================================================================
TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 1b : REDEMPTION BY REWARD TYPE AND YEAR' SKIP 1 -
       LEFT 'Drill-down from Level 1  |  adds reward type' SKIP 1 -
       LEFT '========================================================' SKIP 2
 
BREAK ON reward_type SKIP 1
 
SELECT rd.REWARDTYPE                                        AS reward_type,
       d.CAL_YEAR                                           AS issue_year,
       COUNT(*)                                             AS redemptions,
       ROUND(100 * COUNT(*)
             / SUM(COUNT(*)) OVER (PARTITION BY d.CAL_YEAR), 2)
                                                            AS pct_of_year,
       SUM(f.POINTSPEND)                                    AS points_burned,
       ROUND(SUM(f.REWARDVALUE), 2)                         AS gross_cost_rm,
       ROUND(SUM(f.REWARDVALUE) / NULLIF(COUNT(*), 0), 2)   AS avg_value_rm
FROM   REWARD_FACT f
JOIN   DATE_DIM    d  ON d.DATE_KEY    = f.DATEKEY
JOIN   REWARD_DIM  rd ON rd.REWARD_KEY = f.REWARDKEY
GROUP  BY rd.REWARDTYPE, d.CAL_YEAR
ORDER  BY rd.REWARDTYPE, d.CAL_YEAR;
 
CLEAR BREAKS
TTITLE OFF

TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 2 : MOST REDEEMED REWARD  (full period)' SKIP 1 -
       LEFT 'Ranked by redemption count  |  2020-2026' SKIP 1 -
       LEFT '========================================================' SKIP 2
 
SELECT rd.REWARDNAME                                        AS reward_name,
       rd.REWARDTYPE                                        AS reward_type,
       rd.POINTSREQUIRED                                    AS points_price,
       ROUND(rd.REWARDVALUE, 2)                             AS face_value_rm,
       COUNT(*)                                             AS redemptions,
       RANK() OVER (ORDER BY COUNT(*) DESC)                 AS popularity_rank,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)     AS pct_of_all,
       COUNT(DISTINCT c.CUSTOMERID)                         AS distinct_members,
       SUM(f.POINTSPEND)                                    AS points_burned,
       ROUND(SUM(f.REWARDVALUE), 2)                         AS gross_cost_rm,
       -- RM of face value DELIVERED per 1,000 points burned
       ROUND(1000 * SUM(CASE WHEN f.USEDCOUNT = 1
                             THEN f.REWARDVALUE ELSE 0 END)
             / NULLIF(SUM(f.POINTSPEND), 0), 2)             AS rm_per_1k_points
FROM   REWARD_FACT  f
JOIN   REWARD_DIM   rd ON rd.REWARD_KEY = f.REWARDKEY
JOIN   CUSTOMER_DIM c  ON c.CUSTOMERKEY = f.CUSTOMERKEY
GROUP  BY rd.REWARDNAME, rd.REWARDTYPE, rd.POINTSREQUIRED, rd.REWARDVALUE
ORDER  BY redemptions DESC;
 
TTITLE OFF

TTITLE LEFT '========================================================' SKIP 1 -
       LEFT 'LEVEL 2b : REDEMPTION BY MEMBERSHIP TIER AND YEAR' SKIP 1 -
       LEFT 'Tier resolved as at the issue date  |  SCD Type 2' SKIP 1 -
       LEFT '========================================================' SKIP 2
 
BREAK ON tier_ SKIP 1
 
SELECT NVL(c.MEMBERSHIPTYPE, 'None')                        AS tier_,
       d.CAL_YEAR                                           AS issue_year,
       COUNT(DISTINCT c.CUSTOMERID)                         AS redeeming_members,
       COUNT(*)                                             AS redemptions,
       ROUND(COUNT(*) * 1.0
             / NULLIF(COUNT(DISTINCT c.CUSTOMERID), 0), 2)  AS redemptions_per_member,
       SUM(f.POINTSPEND)                                    AS points_burned,
       ROUND(AVG(f.POINTSPEND), 0)                          AS avg_points_each,
       ROUND(SUM(f.REWARDVALUE), 2)                         AS gross_cost_rm,
       ROUND(100 * SUM(f.EXPIREDCOUNT) / NULLIF(COUNT(*), 0), 2)
                                                            AS breakage_pct
FROM   REWARD_FACT  f
JOIN   DATE_DIM     d ON d.DATE_KEY    = f.DATEKEY
JOIN   CUSTOMER_DIM c ON c.CUSTOMERKEY = f.CUSTOMERKEY
GROUP  BY NVL(c.MEMBERSHIPTYPE, 'None'), d.CAL_YEAR
ORDER  BY tier_ DESC, d.CAL_YEAR;
 
CLEAR BREAKS
TTITLE OFF