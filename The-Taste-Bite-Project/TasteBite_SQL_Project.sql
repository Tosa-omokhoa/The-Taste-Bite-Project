-- =============================================================================
--  TASTEBITE RESTAURANT ANALYTICS — SQL PORTFOLIO PROJECT B
--  Author  : Omokhoa Oshose Tosayoname (Team Lead & Data Analyst)
--  Dataset : 1,500 customer records | 31 columns (19 original + 12 engineered)
--  Tool    : MySQL 8.0+
--  Version : 2.0  (Improved & Expanded)
-- =============================================================================
--
--  STRUCTURE
--  ---------
--  SECTION 0  — Database & Schema Setup
--  SECTION 1  — Table Normalisation (4NF-compliant schema)
--  SECTION 2  — Data Population
--  SECTION 3  — Data Validation & Quality Checks
--  SECTION 4  — Exploratory Analysis (12 analytical queries)
--  SECTION 5  — Business Intelligence Queries (10 advanced queries)
--  SECTION 6  — Stored Views (reusable for Power BI / dashboards)
-- =============================================================================


-- =============================================================================
--  SECTION 0 — DATABASE SETUP
-- =============================================================================

CREATE DATABASE IF NOT EXISTS tastebite_analytics_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE tastebite_analytics_db;

-- Refresh schema tab if using MySQL Workbench after creation


-- =============================================================================
--  SECTION 1 — SCHEMA: NORMALISED TABLE DESIGN
-- =============================================================================
--  Design rationale:
--  The flat source table is decomposed into 4 normalised tables to eliminate
--  redundancy, enforce referential integrity, and enable scalable querying.
--  Feedback is linked to Visit_ID (not Customer_ID) to correctly capture
--  per-visit ratings for customers who visit multiple times.
-- =============================================================================

-- ── 1a. Staging table (import target — mirrors the cleaned working Excel) ────

DROP TABLE IF EXISTS tastebite_staging;

CREATE TABLE tastebite_staging (
    Customer_ID             INT             NOT NULL,
    Age                     TINYINT UNSIGNED NOT NULL,
    Gender                  ENUM('Male','Female') NOT NULL,
    Income                  INT UNSIGNED    NOT NULL,
    Visit_Frequency         ENUM('Daily','Weekly','Monthly','Rarely') NOT NULL,
    Average_Spend           DECIMAL(8,2)    NOT NULL,
    Preferred_Cuisine       ENUM('Chinese','Indian','Italian','Mexican','American') NOT NULL,
    Time_Of_Visit           ENUM('Breakfast','Lunch','Dinner') NOT NULL,
    Group_Size              TINYINT UNSIGNED NOT NULL,
    Dining_Occasion         ENUM('Business','Casual','Celebration') NOT NULL,
    Meal_Type               ENUM('Dine-in','Takeaway') NOT NULL,
    Online_Reservation      TINYINT(1)      NOT NULL DEFAULT 0,
    Delivery_Order          TINYINT(1)      NOT NULL DEFAULT 0,
    Loyalty_Program_Member  TINYINT(1)      NOT NULL DEFAULT 0,
    Wait_Time               DECIMAL(6,2)    NOT NULL,
    Service_Rating          TINYINT         NOT NULL,
    Food_Rating             TINYINT         NOT NULL,
    Ambiance_Rating         TINYINT         NOT NULL,
    High_Satisfaction       TINYINT(1)      NOT NULL DEFAULT 0,
    -- Feature-engineered columns
    Age_Group               VARCHAR(10),
    Income_Band             VARCHAR(25),
    Satisfaction_Score      TINYINT,
    Satisfaction_Tier       VARCHAR(15),
    Spend_Tier              VARCHAR(20),
    Wait_Time_Category      VARCHAR(22),
    Group_Type              VARCHAR(15),
    Digital_Engagement_Score TINYINT,
    Digital_Engagement_Level VARCHAR(18),
    Revenue_Potential       DECIMAL(8,2),
    Revenue_Segment         VARCHAR(12),
    Loyal_and_Satisfied     TINYINT(1),
    PRIMARY KEY (Customer_ID)
);

-- IMPORT NOTE:
-- In MySQL Workbench → right-click tastebite_staging under the schema →
-- Table Data Import Wizard → select TasteBite_Working_Data_Cleaned.xlsx
-- (export the Working_Data sheet as CSV first) → follow prompts.
-- If the CustomerID header imports as ï»¿Customer_ID (BOM artifact), run:
--   ALTER TABLE tastebite_staging RENAME COLUMN `ï»¿Customer_ID` TO Customer_ID;


-- ── 1b. Normalised production tables ─────────────────────────────────────────

DROP TABLE IF EXISTS Feedback;
DROP TABLE IF EXISTS Visits;
DROP TABLE IF EXISTS Preferences;
DROP TABLE IF EXISTS Customers;

-- Customers: demographic & segmentation data
CREATE TABLE Customers (
    Customer_ID             INT             NOT NULL,
    Age                     TINYINT UNSIGNED NOT NULL,
    Gender                  ENUM('Male','Female') NOT NULL,
    Income                  INT UNSIGNED    NOT NULL,
    Loyalty_Program_Member  TINYINT(1)      NOT NULL DEFAULT 0,
    Age_Group               VARCHAR(10),
    Income_Band             VARCHAR(25),
    Digital_Engagement_Score TINYINT,
    Digital_Engagement_Level VARCHAR(18),
    Revenue_Segment         VARCHAR(12),
    CONSTRAINT pk_customers     PRIMARY KEY (Customer_ID),
    CONSTRAINT chk_age          CHECK (Age BETWEEN 18 AND 120),
    CONSTRAINT chk_income       CHECK (Income > 0)
);

-- Visits: per-visit transactional data
CREATE TABLE Visits (
    Visit_ID                INT             NOT NULL AUTO_INCREMENT,
    Customer_ID             INT             NOT NULL,
    Visit_Frequency         ENUM('Daily','Weekly','Monthly','Rarely') NOT NULL,
    Time_Of_Visit           ENUM('Breakfast','Lunch','Dinner') NOT NULL,
    Group_Size              TINYINT UNSIGNED NOT NULL,
    Group_Type              VARCHAR(15),
    Dining_Occasion         ENUM('Business','Casual','Celebration') NOT NULL,
    Meal_Type               ENUM('Dine-in','Takeaway') NOT NULL,
    Average_Spend           DECIMAL(8,2)    NOT NULL,
    Spend_Tier              VARCHAR(20),
    Revenue_Potential       DECIMAL(8,2),
    Online_Reservation      TINYINT(1)      NOT NULL DEFAULT 0,
    Delivery_Order          TINYINT(1)      NOT NULL DEFAULT 0,
    CONSTRAINT pk_visits        PRIMARY KEY (Visit_ID),
    CONSTRAINT fk_visits_cust   FOREIGN KEY (Customer_ID) REFERENCES Customers(Customer_ID)
                                ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_spend        CHECK (Average_Spend >= 0),
    CONSTRAINT chk_group_size   CHECK (Group_Size BETWEEN 1 AND 20)
);

-- Preferences: cuisine and channel preferences (one row per customer)
CREATE TABLE Preferences (
    Preference_ID           INT             NOT NULL AUTO_INCREMENT,
    Customer_ID             INT             NOT NULL,
    Preferred_Cuisine       ENUM('Chinese','Indian','Italian','Mexican','American') NOT NULL,
    CONSTRAINT pk_preferences   PRIMARY KEY (Preference_ID),
    CONSTRAINT fk_pref_cust     FOREIGN KEY (Customer_ID) REFERENCES Customers(Customer_ID)
                                ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uq_cust_cuisine  UNIQUE (Customer_ID)
);

-- Feedback: satisfaction ratings linked to a specific visit
CREATE TABLE Feedback (
    Feedback_ID             INT             NOT NULL AUTO_INCREMENT,
    Visit_ID                INT             NOT NULL,
    Wait_Time               DECIMAL(6,2)    NOT NULL,
    Wait_Time_Category      VARCHAR(22),
    Service_Rating          TINYINT         NOT NULL,
    Food_Rating             TINYINT         NOT NULL,
    Ambiance_Rating         TINYINT         NOT NULL,
    Satisfaction_Score      TINYINT         NOT NULL,
    Satisfaction_Tier       VARCHAR(15),
    High_Satisfaction       TINYINT(1)      NOT NULL DEFAULT 0,
    Loyal_and_Satisfied     TINYINT(1)      NOT NULL DEFAULT 0,
    CONSTRAINT pk_feedback      PRIMARY KEY (Feedback_ID),
    CONSTRAINT fk_feed_visit    FOREIGN KEY (Visit_ID) REFERENCES Visits(Visit_ID)
                                ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_wait         CHECK (Wait_Time >= 0),
    CONSTRAINT chk_service      CHECK (Service_Rating BETWEEN 1 AND 5),
    CONSTRAINT chk_food         CHECK (Food_Rating BETWEEN 1 AND 5),
    CONSTRAINT chk_ambiance     CHECK (Ambiance_Rating BETWEEN 1 AND 5),
    CONSTRAINT chk_sat_score    CHECK (Satisfaction_Score BETWEEN 3 AND 15)
);


-- =============================================================================
--  SECTION 2 — DATA POPULATION (Staging → Normalised Tables)
-- =============================================================================
--  Run AFTER importing the CSV into tastebite_staging.
--  Each INSERT uses SELECT from staging to ensure a single source of truth.
-- =============================================================================

-- ── 2a. Customers ─────────────────────────────────────────────────────────────
INSERT INTO Customers (
    Customer_ID, Age, Gender, Income, Loyalty_Program_Member,
    Age_Group, Income_Band, Digital_Engagement_Score,
    Digital_Engagement_Level, Revenue_Segment
)
SELECT
    Customer_ID,
    Age,
    Gender,
    Income,
    Loyalty_Program_Member,
    Age_Group,
    Income_Band,
    Digital_Engagement_Score,
    Digital_Engagement_Level,
    Revenue_Segment
FROM tastebite_staging;

-- ── 2b. Preferences ──────────────────────────────────────────────────────────
INSERT INTO Preferences (Customer_ID, Preferred_Cuisine)
SELECT Customer_ID, Preferred_Cuisine
FROM tastebite_staging;

-- ── 2c. Visits ────────────────────────────────────────────────────────────────
-- NOTE: In this dataset each customer record represents one visit.
-- The Visit_ID is auto-generated; it maps 1-to-1 with Customer_ID here,
-- but the schema supports multiple visits per customer in production use.
INSERT INTO Visits (
    Customer_ID, Visit_Frequency, Time_Of_Visit, Group_Size, Group_Type,
    Dining_Occasion, Meal_Type, Average_Spend, Spend_Tier,
    Revenue_Potential, Online_Reservation, Delivery_Order
)
SELECT
    Customer_ID,
    Visit_Frequency,
    Time_Of_Visit,
    Group_Size,
    Group_Type,
    Dining_Occasion,
    Meal_Type,
    Average_Spend,
    Spend_Tier,
    Revenue_Potential,
    Online_Reservation,
    Delivery_Order
FROM tastebite_staging;

-- ── 2d. Feedback ──────────────────────────────────────────────────────────────
-- JOIN on Customer_ID to fetch the correct auto-generated Visit_ID.
-- The 1-to-1 nature of this dataset means no duplicates are introduced.
INSERT INTO Feedback (
    Visit_ID, Wait_Time, Wait_Time_Category,
    Service_Rating, Food_Rating, Ambiance_Rating,
    Satisfaction_Score, Satisfaction_Tier,
    High_Satisfaction, Loyal_and_Satisfied
)
SELECT
    v.Visit_ID,
    s.Wait_Time,
    s.Wait_Time_Category,
    s.Service_Rating,
    s.Food_Rating,
    s.Ambiance_Rating,
    s.Satisfaction_Score,
    s.Satisfaction_Tier,
    s.High_Satisfaction,
    s.Loyal_and_Satisfied
FROM tastebite_staging s
JOIN Visits v ON s.Customer_ID = v.Customer_ID;


-- =============================================================================
--  SECTION 3 — DATA VALIDATION & QUALITY CHECKS
-- =============================================================================
--  Run these after population to confirm integrity before analysis.
-- =============================================================================

-- ── 3a. Row count verification ───────────────────────────────────────────────
SELECT 'Staging'   AS tbl, COUNT(*) AS row_count FROM tastebite_staging
UNION ALL
SELECT 'Customers',        COUNT(*) FROM Customers
UNION ALL
SELECT 'Preferences',      COUNT(*) FROM Preferences
UNION ALL
SELECT 'Visits',           COUNT(*) FROM Visits
UNION ALL
SELECT 'Feedback',         COUNT(*) FROM Feedback;
-- Expected: all 1500 except Feedback (also 1500, 1-to-1 with Visits)

-- ── 3b. Null checks on critical columns ──────────────────────────────────────
SELECT
    SUM(CASE WHEN Age IS NULL                   THEN 1 ELSE 0 END) AS null_age,
    SUM(CASE WHEN Income IS NULL                THEN 1 ELSE 0 END) AS null_income,
    SUM(CASE WHEN Gender IS NULL                THEN 1 ELSE 0 END) AS null_gender,
    SUM(CASE WHEN Loyalty_Program_Member IS NULL THEN 1 ELSE 0 END) AS null_loyalty
FROM Customers;

SELECT
    SUM(CASE WHEN Average_Spend IS NULL THEN 1 ELSE 0 END) AS null_spend,
    SUM(CASE WHEN Visit_Frequency IS NULL THEN 1 ELSE 0 END) AS null_freq
FROM Visits;

SELECT
    SUM(CASE WHEN Service_Rating IS NULL THEN 1 ELSE 0 END) AS null_service,
    SUM(CASE WHEN Satisfaction_Score IS NULL THEN 1 ELSE 0 END) AS null_sat_score
FROM Feedback;

-- ── 3c. Rating range integrity ────────────────────────────────────────────────
SELECT COUNT(*) AS out_of_range_ratings
FROM Feedback
WHERE Service_Rating NOT BETWEEN 1 AND 5
   OR Food_Rating    NOT BETWEEN 1 AND 5
   OR Ambiance_Rating NOT BETWEEN 1 AND 5;
-- Expected: 0

-- ── 3d. Orphan record check ───────────────────────────────────────────────────
SELECT COUNT(*) AS visits_without_customer
FROM Visits v
LEFT JOIN Customers c ON v.Customer_ID = c.Customer_ID
WHERE c.Customer_ID IS NULL;

SELECT COUNT(*) AS feedback_without_visit
FROM Feedback f
LEFT JOIN Visits v ON f.Visit_ID = v.Visit_ID
WHERE v.Visit_ID IS NULL;
-- Both expected: 0


-- =============================================================================
--  SECTION 4 — EXPLORATORY ANALYSIS
-- =============================================================================

-- ── Q1. Customer distribution by age group and gender ────────────────────────
--  Original query retained and corrected with proper ordering.
SELECT
    c.Age_Group,
    c.Gender,
    COUNT(*)                                        AS Customer_Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS Pct_of_Total
FROM Customers c
GROUP BY c.Age_Group, c.Gender
ORDER BY
    FIELD(c.Age_Group, '18-25','26-35','36-45','46-55','56-69'),
    c.Gender;


-- ── Q2. Average spend per cuisine, with rank ─────────────────────────────────
--  Upgraded with RANK() window function.
SELECT
    p.Preferred_Cuisine,
    COUNT(v.Visit_ID)                   AS Visit_Count,
    ROUND(AVG(v.Average_Spend), 2)      AS Avg_Spend,
    ROUND(MIN(v.Average_Spend), 2)      AS Min_Spend,
    ROUND(MAX(v.Average_Spend), 2)      AS Max_Spend,
    RANK() OVER (ORDER BY AVG(v.Average_Spend) DESC) AS Spend_Rank
FROM Preferences p
JOIN Visits v ON p.Customer_ID = v.Customer_ID
GROUP BY p.Preferred_Cuisine
ORDER BY Avg_Spend DESC;


-- ── Q3. Most popular dining times ────────────────────────────────────────────
--  Upgraded with percentage share.
SELECT
    v.Time_Of_Visit,
    COUNT(*)                                            AS Visit_Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS Pct_Share
FROM Visits v
GROUP BY v.Time_Of_Visit
ORDER BY Visit_Count DESC;


-- ── Q4. Ratings across customers visiting at different frequencies ────────────
--  Original query retained; upgraded with customer count and High_Satisfaction rate.
SELECT
    v.Visit_Frequency,
    COUNT(DISTINCT v.Customer_ID)          AS Customer_Count,
    ROUND(AVG(f.Service_Rating), 2)        AS Avg_Service,
    ROUND(AVG(f.Food_Rating), 2)           AS Avg_Food,
    ROUND(AVG(f.Ambiance_Rating), 2)       AS Avg_Ambiance,
    ROUND(AVG(f.Satisfaction_Score), 2)    AS Avg_Sat_Score,
    ROUND(AVG(f.High_Satisfaction) * 100, 1) AS High_Sat_Rate_Pct
FROM Visits v
JOIN Feedback f ON v.Visit_ID = f.Visit_ID
GROUP BY v.Visit_Frequency
ORDER BY FIELD(v.Visit_Frequency,'Daily','Weekly','Monthly','Rarely');


-- ── Q5. Loyalty programme member satisfaction ────────────────────────────────
--  Original query retained; upgraded with absolute counts.
SELECT
    CASE c.Loyalty_Program_Member WHEN 1 THEN 'Member' ELSE 'Non-Member' END AS Loyalty_Status,
    COUNT(DISTINCT c.Customer_ID)              AS Customer_Count,
    ROUND(AVG(f.Service_Rating), 2)            AS Avg_Service,
    ROUND(AVG(f.Food_Rating), 2)               AS Avg_Food,
    ROUND(AVG(f.Ambiance_Rating), 2)           AS Avg_Ambiance,
    ROUND(AVG(f.Satisfaction_Score), 2)        AS Avg_Sat_Score,
    ROUND(AVG(f.High_Satisfaction) * 100, 1)   AS High_Sat_Rate_Pct,
    SUM(f.High_Satisfaction)                   AS Highly_Satisfied_Count
FROM Customers c
JOIN Visits v   ON c.Customer_ID = v.Customer_ID
JOIN Feedback f ON v.Visit_ID    = f.Visit_ID
GROUP BY c.Loyalty_Program_Member
ORDER BY c.Loyalty_Program_Member DESC;


-- ── Q6. Revenue distribution by income band ──────────────────────────────────
SELECT
    c.Income_Band,
    COUNT(DISTINCT c.Customer_ID)          AS Customer_Count,
    ROUND(AVG(v.Average_Spend), 2)         AS Avg_Spend,
    ROUND(SUM(v.Average_Spend), 2)         AS Total_Spend,
    ROUND(AVG(v.Revenue_Potential), 2)     AS Avg_Revenue_Potential,
    ROUND(AVG(f.High_Satisfaction)*100,1)  AS High_Sat_Rate_Pct
FROM Customers c
JOIN Visits v   ON c.Customer_ID = v.Customer_ID
JOIN Feedback f ON v.Visit_ID    = f.Visit_ID
GROUP BY c.Income_Band
ORDER BY FIELD(c.Income_Band,
    'Low (<$40K)','Lower-Mid ($40K–$79K)',
    'Upper-Mid ($80K–$119K)','High ($120K+)');


-- ── Q7. Impact of wait time on satisfaction ──────────────────────────────────
SELECT
    f.Wait_Time_Category,
    COUNT(*)                                    AS Visit_Count,
    ROUND(AVG(f.Satisfaction_Score), 2)         AS Avg_Sat_Score,
    ROUND(AVG(f.Service_Rating), 2)             AS Avg_Service,
    ROUND(AVG(f.High_Satisfaction) * 100, 1)    AS High_Sat_Rate_Pct
FROM Feedback f
GROUP BY f.Wait_Time_Category
ORDER BY FIELD(f.Wait_Time_Category,
    'Short (≤15 min)','Moderate (16–30 min)',
    'Long (31–45 min)','Very Long (>45 min)');


-- ── Q8. Meal type (Dine-in vs Takeaway) performance ──────────────────────────
SELECT
    v.Meal_Type,
    COUNT(*)                                    AS Visit_Count,
    ROUND(AVG(v.Average_Spend), 2)              AS Avg_Spend,
    ROUND(SUM(v.Average_Spend), 2)              AS Total_Revenue,
    ROUND(AVG(f.Satisfaction_Score), 2)         AS Avg_Sat_Score,
    ROUND(AVG(f.High_Satisfaction) * 100, 1)    AS High_Sat_Rate_Pct,
    SUM(v.Delivery_Order)                       AS Delivery_Orders,
    SUM(v.Online_Reservation)                   AS Online_Reservations
FROM Visits v
JOIN Feedback f ON v.Visit_ID = f.Visit_ID
GROUP BY v.Meal_Type;


-- ── Q9. Satisfaction by dining occasion ──────────────────────────────────────
SELECT
    v.Dining_Occasion,
    COUNT(*)                                    AS Visit_Count,
    ROUND(AVG(v.Average_Spend), 2)              AS Avg_Spend,
    ROUND(AVG(f.Service_Rating), 2)             AS Avg_Service,
    ROUND(AVG(f.Food_Rating), 2)                AS Avg_Food,
    ROUND(AVG(f.Ambiance_Rating), 2)            AS Avg_Ambiance,
    ROUND(AVG(f.High_Satisfaction) * 100, 1)    AS High_Sat_Rate_Pct
FROM Visits v
JOIN Feedback f ON v.Visit_ID = f.Visit_ID
GROUP BY v.Dining_Occasion
ORDER BY High_Sat_Rate_Pct DESC;


-- ── Q10. Digital engagement and its relationship to satisfaction & spend ──────
SELECT
    c.Digital_Engagement_Level,
    COUNT(DISTINCT c.Customer_ID)              AS Customer_Count,
    ROUND(AVG(v.Average_Spend), 2)             AS Avg_Spend,
    ROUND(AVG(f.Satisfaction_Score), 2)        AS Avg_Sat_Score,
    ROUND(AVG(f.High_Satisfaction) * 100, 1)   AS High_Sat_Rate_Pct,
    SUM(v.Online_Reservation)                  AS Online_Reservations,
    SUM(v.Delivery_Order)                      AS Delivery_Orders
FROM Customers c
JOIN Visits v   ON c.Customer_ID = v.Customer_ID
JOIN Feedback f ON v.Visit_ID    = f.Visit_ID
GROUP BY c.Digital_Engagement_Level
ORDER BY FIELD(c.Digital_Engagement_Level,
    'Offline','Low Digital','Moderate Digital','Fully Digital');


-- ── Q11. Group size category vs spending and satisfaction ─────────────────────
SELECT
    v.Group_Type,
    COUNT(*)                                    AS Visit_Count,
    ROUND(AVG(v.Average_Spend), 2)              AS Avg_Spend,
    ROUND(AVG(v.Group_Size), 1)                 AS Avg_Group_Size,
    ROUND(AVG(f.Satisfaction_Score), 2)         AS Avg_Sat_Score,
    ROUND(AVG(f.High_Satisfaction) * 100, 1)    AS High_Sat_Rate_Pct
FROM Visits v
JOIN Feedback f ON v.Visit_ID = f.Visit_ID
GROUP BY v.Group_Type
ORDER BY FIELD(v.Group_Type,'Solo','Small (2–3)','Medium (4–6)','Large (7+)');


-- ── Q12. Spend tier distribution across meal types and dining occasions ────────
SELECT
    v.Spend_Tier,
    v.Meal_Type,
    v.Dining_Occasion,
    COUNT(*)                        AS Visit_Count,
    ROUND(AVG(f.High_Satisfaction) * 100, 1) AS High_Sat_Rate_Pct
FROM Visits v
JOIN Feedback f ON v.Visit_ID = f.Visit_ID
GROUP BY v.Spend_Tier, v.Meal_Type, v.Dining_Occasion
ORDER BY FIELD(v.Spend_Tier,
    'Low ($0–$50)','Mid ($51–$100)','High ($101–$150)','Premium ($151+)'),
    v.Meal_Type, v.Dining_Occasion;


-- =============================================================================
--  SECTION 5 — BUSINESS INTELLIGENCE QUERIES (Advanced)
-- =============================================================================

-- ── BI-1. Top 10 highest-value customers (Revenue Potential) ─────────────────
SELECT
    c.Customer_ID,
    c.Age,
    c.Gender,
    c.Income_Band,
    v.Visit_Frequency,
    p.Preferred_Cuisine,
    ROUND(v.Average_Spend, 2)          AS Avg_Spend,
    ROUND(v.Revenue_Potential, 2)      AS Revenue_Potential,
    v.Revenue_Segment,
    f.Satisfaction_Tier,
    f.High_Satisfaction
FROM Customers c
JOIN Visits v   ON c.Customer_ID = v.Customer_ID
JOIN Preferences p ON c.Customer_ID = p.Customer_ID
JOIN Feedback f ON v.Visit_ID    = f.Visit_ID
ORDER BY v.Revenue_Potential DESC
LIMIT 10;


-- ── BI-2. Satisfaction driver analysis: correlation proxy ─────────────────────
--  Breaks down which rating dimension most differentiates satisfied vs not.
SELECT
    CASE f.High_Satisfaction WHEN 1 THEN 'Highly Satisfied' ELSE 'Not Highly Satisfied' END AS Satisfaction_Status,
    COUNT(*)                                AS Customer_Count,
    ROUND(AVG(f.Service_Rating), 3)         AS Avg_Service,
    ROUND(AVG(f.Food_Rating), 3)            AS Avg_Food,
    ROUND(AVG(f.Ambiance_Rating), 3)        AS Avg_Ambiance,
    ROUND(AVG(f.Satisfaction_Score), 3)     AS Avg_Composite_Score,
    ROUND(AVG(v.Wait_Time), 2)              AS Avg_Wait_Time_Mins,
    ROUND(AVG(v.Average_Spend), 2)          AS Avg_Spend
FROM Feedback f
JOIN Visits v ON f.Visit_ID = v.Visit_ID
GROUP BY f.High_Satisfaction
ORDER BY f.High_Satisfaction DESC;


-- ── BI-3. Loyal-and-satisfied customer profile ────────────────────────────────
--  Who are the customers who are BOTH loyalty members AND highly satisfied?
SELECT
    c.Age_Group,
    c.Gender,
    c.Income_Band,
    p.Preferred_Cuisine,
    v.Visit_Frequency,
    COUNT(*)                            AS Count,
    ROUND(AVG(v.Average_Spend), 2)      AS Avg_Spend,
    ROUND(AVG(f.Satisfaction_Score), 2) AS Avg_Sat_Score
FROM Customers c
JOIN Visits v      ON c.Customer_ID = v.Customer_ID
JOIN Preferences p ON c.Customer_ID = p.Customer_ID
JOIN Feedback f    ON v.Visit_ID    = f.Visit_ID
WHERE f.Loyal_and_Satisfied = 1
GROUP BY c.Age_Group, c.Gender, c.Income_Band,
         p.Preferred_Cuisine, v.Visit_Frequency
ORDER BY Count DESC
LIMIT 20;


-- ── BI-4. Cuisine preference by age group (cross-tabulation style) ────────────
SELECT
    c.Age_Group,
    SUM(CASE WHEN p.Preferred_Cuisine = 'Chinese'  THEN 1 ELSE 0 END) AS Chinese,
    SUM(CASE WHEN p.Preferred_Cuisine = 'American' THEN 1 ELSE 0 END) AS American,
    SUM(CASE WHEN p.Preferred_Cuisine = 'Indian'   THEN 1 ELSE 0 END) AS Indian,
    SUM(CASE WHEN p.Preferred_Cuisine = 'Mexican'  THEN 1 ELSE 0 END) AS Mexican,
    SUM(CASE WHEN p.Preferred_Cuisine = 'Italian'  THEN 1 ELSE 0 END) AS Italian,
    COUNT(*)                                                            AS Total
FROM Customers c
JOIN Preferences p ON c.Customer_ID = p.Customer_ID
GROUP BY c.Age_Group
ORDER BY FIELD(c.Age_Group,'18-25','26-35','36-45','46-55','56-69');


-- ── BI-5. Revenue segment analysis ───────────────────────────────────────────
SELECT
    v.Revenue_Segment,
    COUNT(DISTINCT c.Customer_ID)              AS Customer_Count,
    ROUND(AVG(v.Average_Spend), 2)             AS Avg_Spend,
    ROUND(AVG(v.Revenue_Potential), 2)         AS Avg_Revenue_Potential,
    ROUND(SUM(v.Revenue_Potential), 2)         AS Total_Revenue_Potential,
    ROUND(SUM(v.Revenue_Potential) * 100.0 /
          SUM(SUM(v.Revenue_Potential)) OVER (), 1) AS Pct_Revenue_Share,
    ROUND(AVG(f.High_Satisfaction) * 100, 1)   AS High_Sat_Rate_Pct
FROM Visits v
JOIN Customers c ON v.Customer_ID = c.Customer_ID
JOIN Feedback f  ON v.Visit_ID    = f.Visit_ID
GROUP BY v.Revenue_Segment
ORDER BY Total_Revenue_Potential DESC;


-- ── BI-6. Online reservation impact on satisfaction and spend ─────────────────
SELECT
    CASE v.Online_Reservation WHEN 1 THEN 'Used Online Reservation'
                               ELSE 'No Reservation' END AS Reservation_Status,
    COUNT(*)                                    AS Visit_Count,
    ROUND(AVG(v.Average_Spend), 2)              AS Avg_Spend,
    ROUND(AVG(f.Satisfaction_Score), 2)         AS Avg_Sat_Score,
    ROUND(AVG(f.High_Satisfaction) * 100, 1)    AS High_Sat_Rate_Pct,
    ROUND(AVG(v.Wait_Time), 2)                  AS Avg_Wait_Time
FROM Visits v
JOIN Feedback f ON v.Visit_ID = f.Visit_ID
GROUP BY v.Online_Reservation;


-- ── BI-7. Satisfaction tier breakdown by customer segment ─────────────────────
--  Uses CTE for cleaner logic; shows how satisfaction tiers distribute
--  across key demographic and behavioural segments.
WITH SegmentSat AS (
    SELECT
        c.Age_Group,
        c.Income_Band,
        CASE c.Loyalty_Program_Member WHEN 1 THEN 'Member' ELSE 'Non-Member' END AS Loyalty,
        f.Satisfaction_Tier,
        COUNT(*) AS cnt
    FROM Customers c
    JOIN Visits v   ON c.Customer_ID = v.Customer_ID
    JOIN Feedback f ON v.Visit_ID    = f.Visit_ID
    GROUP BY c.Age_Group, c.Income_Band, c.Loyalty_Program_Member, f.Satisfaction_Tier
)
SELECT
    Age_Group,
    Income_Band,
    Loyalty,
    SUM(CASE WHEN Satisfaction_Tier = 'Delighted'     THEN cnt ELSE 0 END) AS Delighted,
    SUM(CASE WHEN Satisfaction_Tier = 'Satisfied'     THEN cnt ELSE 0 END) AS Satisfied,
    SUM(CASE WHEN Satisfaction_Tier = 'Neutral'       THEN cnt ELSE 0 END) AS Neutral,
    SUM(CASE WHEN Satisfaction_Tier = 'Dissatisfied'  THEN cnt ELSE 0 END) AS Dissatisfied,
    SUM(cnt)                                                                 AS Total
FROM SegmentSat
GROUP BY Age_Group, Income_Band, Loyalty
ORDER BY FIELD(Age_Group,'18-25','26-35','36-45','46-55','56-69'),
         FIELD(Income_Band,'Low (<$40K)','Lower-Mid ($40K–$79K)',
               'Upper-Mid ($80K–$119K)','High ($120K+)');


-- ── BI-8. Cuisine profitability vs satisfaction score ─────────────────────────
--  Which cuisine drives both high spend AND high satisfaction?
WITH CuisineSummary AS (
    SELECT
        p.Preferred_Cuisine,
        COUNT(*)                                AS Visit_Count,
        ROUND(AVG(v.Average_Spend), 2)          AS Avg_Spend,
        ROUND(SUM(v.Revenue_Potential), 2)      AS Total_Revenue_Potential,
        ROUND(AVG(f.Satisfaction_Score), 3)     AS Avg_Sat_Score,
        ROUND(AVG(f.High_Satisfaction)*100, 1)  AS High_Sat_Pct
    FROM Preferences p
    JOIN Visits v   ON p.Customer_ID = v.Customer_ID
    JOIN Feedback f ON v.Visit_ID    = f.Visit_ID
    GROUP BY p.Preferred_Cuisine
)
SELECT
    *,
    RANK() OVER (ORDER BY Avg_Spend DESC)              AS Spend_Rank,
    RANK() OVER (ORDER BY Avg_Sat_Score DESC)           AS Sat_Rank
FROM CuisineSummary
ORDER BY Avg_Spend DESC;


-- ── BI-9. Running cumulative revenue by customer (window function) ─────────────
--  Identifies at what percentile of customers we capture 80% of revenue.
WITH CustomerRevenue AS (
    SELECT
        c.Customer_ID,
        c.Age_Group,
        c.Gender,
        v.Visit_Frequency,
        ROUND(v.Revenue_Potential, 2) AS Revenue_Potential,
        ROUND(SUM(v.Revenue_Potential) OVER (
            ORDER BY v.Revenue_Potential DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 2) AS Cumulative_Revenue,
        ROUND(SUM(v.Revenue_Potential) OVER () , 2) AS Grand_Total_Revenue
    FROM Customers c
    JOIN Visits v ON c.Customer_ID = v.Customer_ID
)
SELECT
    Customer_ID,
    Age_Group,
    Gender,
    Visit_Frequency,
    Revenue_Potential,
    Cumulative_Revenue,
    ROUND(Cumulative_Revenue * 100.0 / Grand_Total_Revenue, 2) AS Cumulative_Pct
FROM CustomerRevenue
ORDER BY Revenue_Potential DESC
LIMIT 50;


-- ── BI-10. Full customer 360° profile (master view query) ─────────────────────
--  One row per customer with all key metrics — designed for Power BI import.
SELECT
    c.Customer_ID,
    c.Age,
    c.Age_Group,
    c.Gender,
    c.Income,
    c.Income_Band,
    c.Loyalty_Program_Member,
    c.Digital_Engagement_Level,
    c.Revenue_Segment,
    p.Preferred_Cuisine,
    v.Visit_Frequency,
    v.Time_Of_Visit,
    v.Group_Size,
    v.Group_Type,
    v.Dining_Occasion,
    v.Meal_Type,
    ROUND(v.Average_Spend, 2)           AS Average_Spend,
    v.Spend_Tier,
    ROUND(v.Revenue_Potential, 2)       AS Revenue_Potential,
    v.Online_Reservation,
    v.Delivery_Order,
    ROUND(f.Wait_Time, 2)               AS Wait_Time,
    f.Wait_Time_Category,
    f.Service_Rating,
    f.Food_Rating,
    f.Ambiance_Rating,
    f.Satisfaction_Score,
    f.Satisfaction_Tier,
    f.High_Satisfaction,
    f.Loyal_and_Satisfied
FROM Customers c
JOIN Visits v      ON c.Customer_ID = v.Customer_ID
JOIN Preferences p ON c.Customer_ID = p.Customer_ID
JOIN Feedback f    ON v.Visit_ID    = f.Visit_ID
ORDER BY c.Customer_ID;


-- =============================================================================
--  SECTION 6 — STORED VIEWS (For Power BI / Dashboard)
-- =============================================================================
--  These views act as clean, pre-joined data sources that can be connected
--  directly to Power BI via the MySQL connector.
-- =============================================================================

-- ── VIEW 1: Full customer 360 (Power BI master view) ─────────────────────────
CREATE OR REPLACE VIEW vw_customer_360 AS
SELECT
    c.Customer_ID, c.Age, c.Age_Group, c.Gender, c.Income, c.Income_Band,
    c.Loyalty_Program_Member, c.Digital_Engagement_Level, c.Revenue_Segment,
    p.Preferred_Cuisine,
    v.Visit_Frequency, v.Time_Of_Visit, v.Group_Size, v.Group_Type,
    v.Dining_Occasion, v.Meal_Type, ROUND(v.Average_Spend, 2) AS Average_Spend,
    v.Spend_Tier, ROUND(v.Revenue_Potential, 2) AS Revenue_Potential,
    v.Online_Reservation, v.Delivery_Order,
    ROUND(f.Wait_Time, 2) AS Wait_Time, f.Wait_Time_Category,
    f.Service_Rating, f.Food_Rating, f.Ambiance_Rating,
    f.Satisfaction_Score, f.Satisfaction_Tier,
    f.High_Satisfaction, f.Loyal_and_Satisfied
FROM Customers c
JOIN Visits v      ON c.Customer_ID = v.Customer_ID
JOIN Preferences p ON c.Customer_ID = p.Customer_ID
JOIN Feedback f    ON v.Visit_ID    = f.Visit_ID;

-- ── VIEW 2: Satisfaction summary by segment ───────────────────────────────────
CREATE OR REPLACE VIEW vw_satisfaction_summary AS
SELECT
    c.Age_Group, c.Gender, c.Income_Band,
    CASE c.Loyalty_Program_Member WHEN 1 THEN 'Member' ELSE 'Non-Member' END AS Loyalty_Status,
    f.Satisfaction_Tier,
    COUNT(*)                                AS Count,
    ROUND(AVG(f.Satisfaction_Score), 2)     AS Avg_Sat_Score,
    ROUND(AVG(f.High_Satisfaction)*100, 1)  AS High_Sat_Rate_Pct
FROM Customers c
JOIN Visits v   ON c.Customer_ID = v.Customer_ID
JOIN Feedback f ON v.Visit_ID    = f.Visit_ID
GROUP BY c.Age_Group, c.Gender, c.Income_Band,
         c.Loyalty_Program_Member, f.Satisfaction_Tier;

-- ── VIEW 3: Revenue summary by cuisine and segment ───────────────────────────
CREATE OR REPLACE VIEW vw_revenue_by_cuisine AS
SELECT
    p.Preferred_Cuisine,
    c.Income_Band,
    v.Visit_Frequency,
    COUNT(*)                                AS Visit_Count,
    ROUND(AVG(v.Average_Spend), 2)          AS Avg_Spend,
    ROUND(SUM(v.Revenue_Potential), 2)      AS Total_Revenue_Potential,
    ROUND(AVG(f.High_Satisfaction)*100, 1)  AS High_Sat_Pct
FROM Preferences p
JOIN Customers c ON p.Customer_ID = c.Customer_ID
JOIN Visits v    ON c.Customer_ID = v.Customer_ID
JOIN Feedback f  ON v.Visit_ID    = f.Visit_ID
GROUP BY p.Preferred_Cuisine, c.Income_Band, v.Visit_Frequency;

-- =============================================================================
--  END OF SCRIPT
--  Next step: Connect MySQL to Power BI via the MySQL ODBC connector and
--  import vw_customer_360 as the primary data source for the dashboard.
-- =============================================================================
