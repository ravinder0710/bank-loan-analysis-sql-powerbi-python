-- ============================================================================
-- PROJECT      : BANK LOAN ANALYSIS (Data Analyst Portfolio Project)
-- DATABASE     : MySQL
-- TABLE        : financial_loan
-- AUTHOR       : [Ravinder Gupta]
-- ============================================================================
-- PROJECT OVERVIEW
-- ----------------------------------------------------------------------------
-- This project analyzes a bank's loan portfolio to answer key business
-- questions around loan applications, funded amounts, repayments, and
-- loan performance (Good Loan vs Bad Loan).
--
-- The SQL queries below are written and validated BEFORE building the
-- Power BI dashboard. This is a standard industry practice: SQL results
-- act as the "source of truth" to validate that dashboard numbers are
-- correct before showing them to a client or stakeholder.
--
-- The project is split into 2 dashboards:
--   Dashboard 1 : SUMMARY       -> High level KPIs for leadership
--   Dashboard 2 : OVERVIEW      -> Deep-dive dimensional analysis
-- ============================================================================


-- ============================================================================
-- IMPORTANT TECHNICAL NOTE (READ THIS FIRST)
-- ============================================================================
-- The original reference material for this project was built using
-- Microsoft SQL Server. This version has been rewritten for MySQL.
--
-- KEY DIFFERENCE TO REMEMBER:
-- The `issue_date` column in this dataset is stored as TEXT in the
-- format DD-MM-YYYY (example: "12-12-2021"), NOT as a native DATE type.
--
-- Because of this, MySQL date functions like MONTH(issue_date) and
-- YEAR(issue_date) will silently return WRONG results (often 0) if
-- used directly on this text column. This does not throw an error,
-- which makes it a dangerous, hard-to-catch bug.
--
-- SOLUTION used throughout this entire file:
--     STR_TO_DATE(issue_date, '%d-%m-%Y')
--
-- This function converts the text string into a real MySQL DATE object
-- using the format codes:
--     %d = day (2 digits)
--     %m = month (2 digits)
--     %Y = year (4 digits)
--
-- Once converted, MONTH(), YEAR(), and MONTHNAME() work correctly.
-- ============================================================================


-- ============================================================================
-- SETUP
-- ============================================================================
CREATE DATABASE IF NOT EXISTS bank_loan_db;
USE bank_loan_db;

-- Quick sanity check on the data
SELECT * FROM financial_loan LIMIT 10;

-- Check table structure (column names and data types)
DESCRIBE financial_loan;

-- Confirm the date range of the dataset
-- This tells us which month is the "latest" month (needed for MTD/PMTD below)
SELECT 
    MIN(STR_TO_DATE(issue_date, '%d-%m-%Y')) AS Min_Date,
    MAX(STR_TO_DATE(issue_date, '%d-%m-%Y')) AS Max_Date
FROM financial_loan;
-- Result: Min = 01-01-2021 , Max = 12-12-2021
-- So the latest month in our data = December 2021
-- and the previous month = November 2021


-- ############################################################################
-- DASHBOARD 1 : SUMMARY
-- ############################################################################
-- This dashboard shows the top-level KPIs that give management an overall
-- picture of how the bank's lending business is performing.
-- ############################################################################


-- ============================================================================
-- SECTION A : CORE KPIs
-- Pattern used in this entire section:
--   1. Overall value (full year)
--   2. MTD  value (latest month only      -> December 2021)
--   3. PMTD value (month before latest    -> November 2021)
--   4. MoM% change = (MTD - PMTD) / PMTD * 100
-- ============================================================================

-- ------------------------------------------------------------------------
-- Q1. Total Loan Applications
-- Each row in the table = one loan application, so COUNT(id) gives us
-- the total number of applications. We use `id` (the primary key)
-- instead of COUNT(*) because it is guaranteed to never be NULL.
-- ------------------------------------------------------------------------
SELECT 
    COUNT(id) AS Total_Loan_Applications
FROM financial_loan;
-- Result: 38576


-- ------------------------------------------------------------------------
-- Q2. MTD (Month-to-Date) Loan Applications
-- "MTD" means: applications received in the LATEST month only.
-- We filter on BOTH month and year -- if we only filtered on month=12,
-- and the dataset had multiple years, December from every year would
-- get mixed together. Filtering by year as well keeps this scalable.
-- ------------------------------------------------------------------------
SELECT 
    COUNT(id) AS MTD_Loan_Applications
FROM financial_loan
WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 12
  AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021;
-- Result: 4314


-- ------------------------------------------------------------------------
-- Q3. PMTD (Previous Month-to-Date) Loan Applications
-- "PMTD" means: applications received in the month BEFORE the latest
-- month. Latest = December(12), so previous = November(11).
-- ------------------------------------------------------------------------
SELECT 
    COUNT(id) AS PMTD_Loan_Applications
FROM financial_loan
WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 11
  AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021;
-- Result: 4035


-- ------------------------------------------------------------------------
-- Q4. MoM% (Month-over-Month) Change in Loan Applications
-- Formula: (Current Month - Previous Month) / Previous Month * 100
-- This is the standard "growth percentage" formula used everywhere
-- in business analytics (sales growth, revenue growth, etc.)
--
-- Technique used: CTE (Common Table Expression) via the WITH clause.
-- A CTE lets us name a temporary result and reuse it later in the
-- query -- this keeps the final SELECT clean and easy to read,
-- instead of writing one giant nested query.
--
-- CROSS JOIN explanation: `mtd` and `pmtd` are each a temporary table
-- containing exactly ONE row (one number). CROSS JOIN simply places
-- these two single-row tables side by side so we can do math between
-- their columns in the same SELECT statement.
-- ------------------------------------------------------------------------
WITH mtd AS (
    SELECT COUNT(id) AS MTD
    FROM financial_loan
    WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 12
      AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021
),
pmtd AS (
    SELECT COUNT(id) AS PMTD
    FROM financial_loan
    WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 11
      AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021
)
SELECT 
    CONCAT(ROUND((MTD - PMTD) / PMTD * 100, 2), '%') AS MoM_Loan_Applications
FROM mtd
CROSS JOIN pmtd;
-- Result: 6.91%  (Applications grew 6.91% from Nov to Dec)


-- ------------------------------------------------------------------------
-- Q5. Total Funded Amount
-- "Funded Amount" = how much money the BANK gave OUT to the customer.
-- Column used: loan_amount
-- ------------------------------------------------------------------------
SELECT 
    SUM(loan_amount) AS Total_Funded_Amount
FROM financial_loan;
-- Result: 435757075


-- ------------------------------------------------------------------------
-- Q6. MTD Total Funded Amount
-- ------------------------------------------------------------------------
SELECT 
    SUM(loan_amount) AS MTD_Total_Funded_Amount
FROM financial_loan
WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 12
  AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021;
-- Result: 53981425


-- ------------------------------------------------------------------------
-- Q7. PMTD Total Funded Amount
-- ------------------------------------------------------------------------
SELECT 
    SUM(loan_amount) AS PMTD_Total_Funded_Amount
FROM financial_loan
WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 11
  AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021;
-- Result: 47754825


-- ------------------------------------------------------------------------
-- Q8. MoM% Change in Total Funded Amount
-- Same CTE + CROSS JOIN pattern as Q4, just applied to loan_amount
-- instead of counting applications.
-- ------------------------------------------------------------------------
WITH mtd AS (
    SELECT SUM(loan_amount) AS MTD
    FROM financial_loan
    WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 12
      AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021
),
pmtd AS (
    SELECT SUM(loan_amount) AS PMTD
    FROM financial_loan
    WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 11
      AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021
)
SELECT 
    CONCAT(ROUND((MTD - PMTD) / PMTD * 100, 2), '%') AS MoM_Funded_Amount
FROM mtd
CROSS JOIN pmtd;
-- Result: 13.04%


-- ------------------------------------------------------------------------
-- Q9. Total Amount Received
-- "Amount Received" = how much money the bank got BACK from customers
-- (via EMIs/installments). Column used: total_payment
-- ------------------------------------------------------------------------
SELECT 
    SUM(total_payment) AS Total_Amount_Received
FROM financial_loan;
-- Result: 473070933
-- Business Insight: Received (473M) > Funded (435M)
-- This means the bank is profitable overall because of interest earned.


-- ------------------------------------------------------------------------
-- Q10. MTD Total Amount Received
-- ------------------------------------------------------------------------
SELECT 
    SUM(total_payment) AS MTD_Total_Amount_Received
FROM financial_loan
WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 12
  AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021;
-- Result: 58074380


-- ------------------------------------------------------------------------
-- Q11. PMTD Total Amount Received
-- ------------------------------------------------------------------------
SELECT 
    SUM(total_payment) AS PMTD_Total_Amount_Received
FROM financial_loan
WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 11
  AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021;
-- Result: 50132030


-- ------------------------------------------------------------------------
-- Q12. MoM% Change in Total Amount Received
-- ------------------------------------------------------------------------
WITH mtd AS (
    SELECT SUM(total_payment) AS MTD
    FROM financial_loan
    WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 12
      AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021
),
pmtd AS (
    SELECT SUM(total_payment) AS PMTD
    FROM financial_loan
    WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 11
      AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021
)
SELECT 
    CONCAT(ROUND((MTD - PMTD) / PMTD * 100, 2), '%') AS MoM_Amount_Received
FROM mtd
CROSS JOIN pmtd;
-- Result: 15.84%


-- ------------------------------------------------------------------------
-- Q13. Average Interest Rate
-- Column `int_rate` is stored as a decimal (e.g. 0.12 = 12%), so we
-- multiply by 100 to convert it into a readable percentage.
-- ------------------------------------------------------------------------
SELECT 
    CONCAT(ROUND(AVG(int_rate) * 100, 3), '%') AS Avg_Interest_Rate
FROM financial_loan;
-- Result: 12.049%


-- ------------------------------------------------------------------------
-- Q14. MTD Average Interest Rate
-- ------------------------------------------------------------------------
SELECT 
    CONCAT(ROUND(AVG(int_rate) * 100, 3), '%') AS MTD_Avg_Interest_Rate
FROM financial_loan
WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 12
  AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021;
-- Result: 12.356%


-- ------------------------------------------------------------------------
-- Q15. PMTD Average Interest Rate
-- ------------------------------------------------------------------------
SELECT 
    CONCAT(ROUND(AVG(int_rate) * 100, 3), '%') AS PMTD_Avg_Interest_Rate
FROM financial_loan
WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 11
  AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021;
-- Result: 11.942%


-- ------------------------------------------------------------------------
-- Q16. MoM% Change in Average Interest Rate
-- ------------------------------------------------------------------------
WITH mtd AS (
    SELECT AVG(int_rate) * 100 AS MTD
    FROM financial_loan
    WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 12
      AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021
),
pmtd AS (
    SELECT AVG(int_rate) * 100 AS PMTD
    FROM financial_loan
    WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 11
      AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021
)
SELECT 
    CONCAT(ROUND((MTD - PMTD) / PMTD * 100, 3), '%') AS MoM_Interest_Rate
FROM mtd
CROSS JOIN pmtd;
-- Result: 3.47%
-- Business Insight: Higher interest rate = more profit for the bank,
-- but more expensive for the customer.


-- ------------------------------------------------------------------------
-- Q17. Average DTI (Debt-to-Income Ratio)
-- DTI = Monthly Debt Payments / Monthly Income.
-- Banks use this to judge a borrower's financial health.
-- A DTI that is too high OR too low can both be a concern -- most
-- banks consider a DTI range of roughly 20%-35% as healthy.
-- ------------------------------------------------------------------------
SELECT 
    CONCAT(ROUND(AVG(dti) * 100, 3), '%') AS Avg_DTI
FROM financial_loan;
-- Result: 13.327%


-- ------------------------------------------------------------------------
-- Q18. MTD Average DTI
-- ------------------------------------------------------------------------
SELECT 
    CONCAT(ROUND(AVG(dti) * 100, 3), '%') AS MTD_Avg_DTI
FROM financial_loan
WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 12
  AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021;
-- Result: 13.666%


-- ------------------------------------------------------------------------
-- Q19. PMTD Average DTI
-- ------------------------------------------------------------------------
SELECT 
    CONCAT(ROUND(AVG(dti) * 100, 3), '%') AS PMTD_Avg_DTI
FROM financial_loan
WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 11
  AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021;
-- Result: 13.303%


-- ------------------------------------------------------------------------
-- Q20. MoM% Change in Average DTI
-- ------------------------------------------------------------------------
WITH mtd AS (
    SELECT AVG(dti) * 100 AS MTD
    FROM financial_loan
    WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 12
      AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021
),
pmtd AS (
    SELECT AVG(dti) * 100 AS PMTD
    FROM financial_loan
    WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 11
      AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021
)
SELECT 
    CONCAT(ROUND((MTD - PMTD) / PMTD * 100, 3), '%') AS MoM_DTI
FROM mtd
CROSS JOIN pmtd;
-- Result: 2.727%


-- ============================================================================
-- SECTION B : GOOD LOAN KPIs
-- Business Definition: A loan is "Good" if loan_status is either
-- 'Fully Paid' (customer paid everything back) OR 'Current' (customer
-- is actively repaying on schedule). Both outcomes are healthy for the
-- bank.
-- ============================================================================

-- ------------------------------------------------------------------------
-- Q21. Good Loan Application Percentage
--
-- TECHNIQUE: CASE WHEN + COUNT()
-- `CASE WHEN condition THEN id END` returns the id ONLY when the
-- condition is true; otherwise it returns NULL (implicitly).
-- COUNT() automatically IGNORES NULL values, so
-- COUNT(CASE WHEN condition THEN id END) effectively counts only the
-- rows where the condition was true. This is the standard SQL pattern
-- for "conditional counting".
--
-- We use a CTE here because we need BOTH the "Good Loan count" and the
-- "Total count" together to compute a percentage. Wrapping this in a
-- CTE first, then dividing in the outer SELECT, keeps the query clean.
-- ------------------------------------------------------------------------
WITH CTE AS (
    SELECT 
        COUNT(CASE 
                WHEN loan_status IN ('Fully Paid', 'Current') THEN id 
              END) AS Good_Loan_Applications,
        COUNT(id) AS Total_Applications
    FROM financial_loan
)
SELECT 
    CONCAT(ROUND((Good_Loan_Applications / Total_Applications) * 100, 2), '%') 
        AS Good_Loan_Percentage
FROM CTE;
-- Result: 86%


-- ------------------------------------------------------------------------
-- Q22. Good Loan Applications (Count)
-- Here we only need the FILTERED count (not a percentage), so a
-- simple WHERE clause is enough -- no need for CASE WHEN.
--
-- RULE OF THUMB:
--   - Need ONLY filtered data            -> use WHERE
--   - Need a comparison/percentage       -> use CASE WHEN + COUNT()
-- ------------------------------------------------------------------------
SELECT 
    COUNT(id) AS Good_Loan_Applications
FROM financial_loan
WHERE loan_status IN ('Fully Paid', 'Current');
-- Result: 33243


-- ------------------------------------------------------------------------
-- Q23. Good Loan Funded Amount
-- ------------------------------------------------------------------------
SELECT 
    SUM(loan_amount) AS Good_Loan_Funded_Amount
FROM financial_loan
WHERE loan_status IN ('Fully Paid', 'Current');
-- Result: ~370 Million


-- ------------------------------------------------------------------------
-- Q24. Good Loan Total Received Amount
-- ------------------------------------------------------------------------
SELECT 
    SUM(total_payment) AS Good_Loan_Total_Received_Amount
FROM financial_loan
WHERE loan_status IN ('Fully Paid', 'Current');
-- Result: ~435 Million
-- Business Insight: Bank funded ~370M and received back ~435M on Good
-- Loans alone -> Profit of ~65M from Good Loans.


-- ============================================================================
-- SECTION C : BAD LOAN KPIs
-- Business Definition: A loan is "Bad" if loan_status = 'Charged Off',
-- meaning the customer defaulted and stopped repaying.
-- ============================================================================

-- ------------------------------------------------------------------------
-- Q25. Bad Loan Application Percentage
-- Same CASE WHEN + CTE pattern as Q21, applied to a single condition.
-- ------------------------------------------------------------------------
WITH CTE AS (
    SELECT 
        COUNT(CASE 
                WHEN loan_status = 'Charged Off' THEN id 
              END) AS Bad_Loan_Applications,
        COUNT(id) AS Total_Applications
    FROM financial_loan
)
SELECT 
    CONCAT(ROUND((Bad_Loan_Applications / Total_Applications) * 100, 2), '%') 
        AS Bad_Loan_Percentage
FROM CTE;
-- Result: 13.82%


-- ------------------------------------------------------------------------
-- Q26. Bad Loan Applications (Count)
-- ------------------------------------------------------------------------
SELECT 
    COUNT(id) AS Bad_Loan_Applications
FROM financial_loan
WHERE loan_status = 'Charged Off';
-- Result: ~5300


-- ------------------------------------------------------------------------
-- Q27. Bad Loan Funded Amount
-- ------------------------------------------------------------------------
SELECT 
    SUM(loan_amount) AS Bad_Loan_Funded_Amount
FROM financial_loan
WHERE loan_status = 'Charged Off';
-- Result: ~65 Million


-- ------------------------------------------------------------------------
-- Q28. Bad Loan Total Received Amount
-- ------------------------------------------------------------------------
SELECT 
    SUM(total_payment) AS Bad_Loan_Total_Received_Amount
FROM financial_loan
WHERE loan_status = 'Charged Off';
-- Result: ~37 Million
-- Business Insight: Bank funded ~65M on Bad Loans but only recovered
-- ~37M -> Loss of ~28M from defaulters. This is why banks closely
-- monitor credit scores and DTI before approving a loan.


-- ============================================================================
-- SECTION D : LOAN STATUS GRID VIEW
-- A single consolidated view showing every metric, broken down by
-- each loan_status value (Fully Paid / Current / Charged Off).
-- ============================================================================

-- ------------------------------------------------------------------------
-- Q29. Loan Status Summary Grid (Full Year)
--
-- TECHNIQUE: GROUP BY
-- We are selecting `loan_status` (a plain/non-aggregated column)
-- alongside several aggregated columns (COUNT, SUM, AVG). Whenever
-- this combination happens, GROUP BY is MANDATORY on the
-- non-aggregated column. It tells MySQL: "split the data into groups
-- based on loan_status, then calculate each aggregate PER group."
-- Without GROUP BY here, this query would throw an error.
-- ------------------------------------------------------------------------
SELECT
    loan_status,
    COUNT(id)                                   AS Loan_Count,
    SUM(total_payment)                          AS Total_Amount_Received,
    SUM(loan_amount)                            AS Total_Funded_Amount,
    CONCAT(ROUND(AVG(int_rate * 100), 2), '%')  AS Avg_Interest_Rate,
    CONCAT(ROUND(AVG(dti * 100), 2), '%')       AS Avg_DTI
FROM financial_loan
GROUP BY loan_status
ORDER BY loan_status;


-- ------------------------------------------------------------------------
-- Q30. MTD Loan Status Grid (Latest Month = December 2021)
-- Same grid as Q29, but filtered to only the latest month.
-- ------------------------------------------------------------------------
SELECT
    loan_status,
    SUM(total_payment) AS MTD_Total_Amount_Received,
    SUM(loan_amount)   AS MTD_Total_Funded_Amount
FROM financial_loan
WHERE MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 12
  AND YEAR(STR_TO_DATE(issue_date, '%d-%m-%Y')) = 2021
GROUP BY loan_status
ORDER BY loan_status;


-- ############################################################################
-- DASHBOARD 2 : OVERVIEW
-- ############################################################################
-- This dashboard breaks the data down by different business dimensions
-- (month, state, term, employment length, purpose, home ownership) so
-- stakeholders can "slice and dice" the lending activity from multiple
-- angles.
--
-- NOTICE THE REPEATING TEMPLATE PATTERN below:
--     SELECT [dimension], COUNT(id), SUM(loan_amount), SUM(total_payment)
--     FROM financial_loan
--     GROUP BY [dimension]
--     ORDER BY [dimension]
--
-- Once you understand this template, you can reuse it for ANY new
-- dimension (grade, sub_grade, verification_status, etc.) just by
-- swapping the dimension column -- the overall logic never changes.
-- ############################################################################

-- ------------------------------------------------------------------------
-- Q1. Monthly Trends by Issue Date
--
-- TECHNIQUE: MONTH() vs MONTHNAME()
--   MONTH()     -> returns a NUMBER (1-12)   -> used for sorting
--   MONTHNAME() -> returns a NAME ("January") -> used for display
--
-- WHY WE NEED BOTH:
-- If we only used MONTHNAME() and ordered by it, MySQL would sort
-- alphabetically (April, August, December, February...) which is
-- WRONG for a time-based chart. So we always calculate the month
-- NUMBER purely to control the sort order, while the month NAME is
-- what actually gets displayed to the user.
-- ------------------------------------------------------------------------
SELECT 
    MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y'))      AS Month_Number,
    MONTHNAME(STR_TO_DATE(issue_date, '%d-%m-%Y'))  AS Month_Name,
    COUNT(id)            AS Total_Loan_Applications,
    SUM(loan_amount)     AS Total_Funded_Amount,
    SUM(total_payment)   AS Total_Amount_Received
FROM financial_loan
GROUP BY 
    MONTH(STR_TO_DATE(issue_date, '%d-%m-%Y')),
    MONTHNAME(STR_TO_DATE(issue_date, '%d-%m-%Y'))
ORDER BY Month_Number;


-- ------------------------------------------------------------------------
-- Q2. Regional Analysis by State
-- Shows which states have the highest lending activity.
-- ------------------------------------------------------------------------
SELECT 
    address_state AS State,
    COUNT(id)           AS Total_Loan_Applications,
    SUM(loan_amount)    AS Total_Funded_Amount,
    SUM(total_payment)  AS Total_Amount_Received
FROM financial_loan
GROUP BY address_state
ORDER BY Total_Funded_Amount DESC;
-- Insight: California (CA) has the highest total funded amount.


-- ------------------------------------------------------------------------
-- Q3. Loan Term Analysis
-- Compares 36-month vs 60-month loans.
-- ------------------------------------------------------------------------
SELECT 
    term AS Term,
    COUNT(id)           AS Total_Loan_Applications,
    SUM(loan_amount)    AS Total_Funded_Amount,
    SUM(total_payment)  AS Total_Amount_Received
FROM financial_loan
GROUP BY term
ORDER BY term;


-- ------------------------------------------------------------------------
-- Q4. Employee Length Analysis
-- Shows how lending activity varies by the borrower's years of
-- employment (e.g. "< 1 year", "10+ years").
-- ------------------------------------------------------------------------
SELECT 
    emp_length AS Employee_Length,
    COUNT(id)           AS Total_Loan_Applications,
    SUM(loan_amount)    AS Total_Funded_Amount,
    SUM(total_payment)  AS Total_Amount_Received
FROM financial_loan
GROUP BY emp_length
ORDER BY emp_length;


-- ------------------------------------------------------------------------
-- Q5. Loan Purpose Analysis
-- Shows WHY people are taking loans (debt consolidation, credit card,
-- home improvement, etc.) and which purpose brings in the most funding.
-- ------------------------------------------------------------------------
SELECT 
    purpose AS Purpose,
    COUNT(id)           AS Total_Loan_Applications,
    SUM(loan_amount)    AS Total_Funded_Amount,
    SUM(total_payment)  AS Total_Amount_Received
FROM financial_loan
GROUP BY purpose
ORDER BY Total_Funded_Amount DESC;
-- Insight: "debt_consolidation" is the most common loan purpose.


-- ------------------------------------------------------------------------
-- Q6. Home Ownership Analysis
-- Shows whether borrowers rent, own, or have a mortgage on their home.
-- ------------------------------------------------------------------------
SELECT 
    home_ownership AS Home_Ownership,
    COUNT(id)           AS Total_Loan_Applications,
    SUM(loan_amount)    AS Total_Funded_Amount,
    SUM(total_payment)  AS Total_Amount_Received
FROM financial_loan
GROUP BY home_ownership
ORDER BY home_ownership;


-- ------------------------------------------------------------------------
-- Q7. Filtered Analysis Example (Grade = 'A')
--
-- TECHNIQUE: Query Execution Order
-- This query demonstrates that WHERE is applied BEFORE GROUP BY.
-- MySQL executes a query internally in roughly this order:
--     FROM -> WHERE -> GROUP BY -> HAVING -> SELECT -> ORDER BY
-- So here, MySQL first filters the table down to ONLY Grade 'A' rows,
-- and THEN groups those filtered rows by purpose. This is useful for
-- demonstrating how dashboard filters (like a "Grade" slicer in
-- Power BI) would affect the underlying numbers.
-- ------------------------------------------------------------------------
SELECT
    purpose AS Purpose,
    COUNT(id)           AS Total_Loan_Applications,
    SUM(loan_amount)    AS Total_Funded_Amount,
    SUM(total_payment)  AS Total_Amount_Received
FROM financial_loan
WHERE grade = 'A'
GROUP BY purpose
ORDER BY Total_Funded_Amount DESC;


-- ############################################################################
-- END OF SQL PROJECT
-- Next Step: Build Power BI dashboard and cross-check every number
-- above against the dashboard visuals to validate correctness before
-- presenting to stakeholders.
-- ############################################################################