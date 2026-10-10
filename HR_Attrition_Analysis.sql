/*
==============================================================================
 IBM HR ANALYTICS - EMPLOYEE ATTRITION ANALYSIS (SQL SERVER)
==============================================================================
 Reads your EXISTING table dbo.HR_Attrition (database HR_Attrition) and does
 not change it. The only object it creates is the view dbo.vw_HR_Clean
 (dropped and re-created each run), which is also the source for Power BI.

 If your database / table have different names, change them in:
   - USE ...            (line below)
   - section 0          (FROM dbo.HR_Attrition)
   - section 1          (FROM dbo.HR_Attrition)

 The view works whether Attrition / OverTime are Yes/No text or BIT, and
 whether the rating columns are 1-4 numbers or Low/Medium/High/Very High
 text. Unknown or missing values remain Unknown/NULL instead of being
 silently converted to No; KPI rates use only rows with known Attrition. It builds its own age / tenure / income bands from Age, YearsAtCompany
 and MonthlyIncome (same bands as the Excel dashboard), so existing
 AgeGroup / TenureBand / IncomeBand columns in the table are not needed.

 Reference sanity check for the standard IBM sample (if using the original data):
 1470 employees, 237 left, 1233 stayed, attrition rate 16.12%. Results vary if
 the source data differs or contains unknown values.
==============================================================================
*/
USE HR_Attrition;
GO
SET NOCOUNT ON;
GO

------------------------------------------------------------
-- 0. CLEAN VIEW
------------------------------------------------------------
IF OBJECT_ID('dbo.vw_HR_Clean','V') IS NOT NULL DROP VIEW dbo.vw_HR_Clean;
GO

CREATE VIEW dbo.vw_HR_Clean AS
SELECT
    B.*,

    -- Rating labels (sort column = 1..4 keeps the logical order)
    CHOOSE(B.JobSatisfactionSort, 'Low','Medium','High','Very High') AS JobSatisfactionLabel,
    CHOOSE(B.WorkLifeBalanceSort, 'Low','Medium','High','Very High') AS WorkLifeBalanceLabel,
    CHOOSE(B.EnvironmentSatisfactionSort, 'Low','Medium','High','Very High') AS EnvironmentSatisfactionLabel,
    CHOOSE(B.RelationshipSatisfactionSort, 'Low','Medium','High','Very High') AS RelationshipSatisfactionLabel,
    CHOOSE(B.JobInvolvementSort, 'Low','Medium','High','Very High') AS JobInvolvementLabel,

    -- Bands (same as the Excel dashboard)
    CASE WHEN B.Age < 30 THEN '18-29' WHEN B.Age < 40 THEN '30-39'
         WHEN B.Age < 50 THEN '40-49' ELSE '50+' END AS AgeGroup,
    CASE WHEN B.Age < 30 THEN 1 WHEN B.Age < 40 THEN 2 WHEN B.Age < 50 THEN 3 ELSE 4 END AS AgeGroupSort,

    CASE WHEN B.YearsAtCompany < 2  THEN '1. 0-1 yrs'
         WHEN B.YearsAtCompany < 5  THEN '2. 2-4 yrs'
         WHEN B.YearsAtCompany < 10 THEN '3. 5-9 yrs'
         ELSE '4. 10+ yrs' END AS TenureBand,
    CASE WHEN B.YearsAtCompany < 2 THEN 1 WHEN B.YearsAtCompany < 5 THEN 2
         WHEN B.YearsAtCompany < 10 THEN 3 ELSE 4 END AS TenureBandSort,

    CASE WHEN B.MonthlyIncome < 3000  THEN '1. Under 3K'
         WHEN B.MonthlyIncome < 6000  THEN '2. 3K-5.9K'
         WHEN B.MonthlyIncome < 10000 THEN '3. 6K-9.9K'
         ELSE '4. 10K+' END AS IncomeBand,
    CASE WHEN B.MonthlyIncome < 3000 THEN 1 WHEN B.MonthlyIncome < 6000 THEN 2
         WHEN B.MonthlyIncome < 10000 THEN 3 ELSE 4 END AS IncomeBandSort
FROM (
    SELECT
        H.EmployeeNumber, H.Age, H.Department, H.JobRole, H.Gender, H.MaritalStatus,
        H.BusinessTravel, H.MonthlyIncome, H.DistanceFromHome, H.TotalWorkingYears,
        H.YearsAtCompany, H.YearsSinceLastPromotion,

        -- Yes/No text or BIT -> 'Yes'/'No' and 1/0
        CASE
            WHEN H.Attrition IS NULL OR LOWER(LTRIM(RTRIM(CONVERT(varchar(10), H.Attrition)))) NOT IN ('yes','no','1','0','true','false') THEN 'Unknown'
            WHEN LOWER(LTRIM(RTRIM(CONVERT(varchar(10), H.Attrition)))) IN ('yes','1','true') THEN 'Yes' ELSE 'No'
        END AS Attrition,
        CASE
            WHEN H.Attrition IS NULL OR LOWER(LTRIM(RTRIM(CONVERT(varchar(10), H.Attrition)))) NOT IN ('yes','no','1','0','true','false') THEN NULL
            WHEN LOWER(LTRIM(RTRIM(CONVERT(varchar(10), H.Attrition)))) IN ('yes','1','true') THEN 1 ELSE 0
        END AS AttritionFlag,
        CASE
            WHEN H.Attrition IS NULL OR LOWER(LTRIM(RTRIM(CONVERT(varchar(10), H.Attrition)))) NOT IN ('yes','no','1','0','true','false') THEN 'Unknown'
            WHEN LOWER(LTRIM(RTRIM(CONVERT(varchar(10), H.Attrition)))) IN ('yes','1','true') THEN 'Left' ELSE 'Stayed'
        END AS AttritionStatus,
        CASE
            WHEN H.OverTime IS NULL OR LOWER(LTRIM(RTRIM(CONVERT(varchar(10), H.OverTime)))) NOT IN ('yes','no','1','0','true','false') THEN 'Unknown'
            WHEN LOWER(LTRIM(RTRIM(CONVERT(varchar(10), H.OverTime)))) IN ('yes','1','true') THEN 'Yes' ELSE 'No'
        END AS OverTime,

        -- Ratings -> 1..4 (accepts 1-4 numbers or Low / Medium / High / Very High text)
        CASE LOWER(LTRIM(RTRIM(CONVERT(varchar(30), H.JobSatisfaction))))
            WHEN '1' THEN 1 WHEN 'low'    THEN 1 WHEN 'bad'    THEN 1
            WHEN '2' THEN 2 WHEN 'medium' THEN 2 WHEN 'good'   THEN 2
            WHEN '3' THEN 3 WHEN 'high'   THEN 3 WHEN 'better' THEN 3
            WHEN '4' THEN 4 WHEN 'very high' THEN 4 WHEN 'best' THEN 4
        END AS JobSatisfactionSort,
        CASE LOWER(LTRIM(RTRIM(CONVERT(varchar(30), H.WorkLifeBalance))))
            WHEN '1' THEN 1 WHEN 'low'    THEN 1 WHEN 'bad'    THEN 1
            WHEN '2' THEN 2 WHEN 'medium' THEN 2 WHEN 'good'   THEN 2
            WHEN '3' THEN 3 WHEN 'high'   THEN 3 WHEN 'better' THEN 3
            WHEN '4' THEN 4 WHEN 'very high' THEN 4 WHEN 'best' THEN 4
        END AS WorkLifeBalanceSort,
        CASE LOWER(LTRIM(RTRIM(CONVERT(varchar(30), H.EnvironmentSatisfaction))))
            WHEN '1' THEN 1 WHEN 'low'    THEN 1 WHEN 'bad'    THEN 1
            WHEN '2' THEN 2 WHEN 'medium' THEN 2 WHEN 'good'   THEN 2
            WHEN '3' THEN 3 WHEN 'high'   THEN 3 WHEN 'better' THEN 3
            WHEN '4' THEN 4 WHEN 'very high' THEN 4 WHEN 'best' THEN 4
        END AS EnvironmentSatisfactionSort,
        CASE LOWER(LTRIM(RTRIM(CONVERT(varchar(30), H.RelationshipSatisfaction))))
            WHEN '1' THEN 1 WHEN 'low'    THEN 1 WHEN 'bad'    THEN 1
            WHEN '2' THEN 2 WHEN 'medium' THEN 2 WHEN 'good'   THEN 2
            WHEN '3' THEN 3 WHEN 'high'   THEN 3 WHEN 'better' THEN 3
            WHEN '4' THEN 4 WHEN 'very high' THEN 4 WHEN 'best' THEN 4
        END AS RelationshipSatisfactionSort,
        CASE LOWER(LTRIM(RTRIM(CONVERT(varchar(30), H.JobInvolvement))))
            WHEN '1' THEN 1 WHEN 'low'    THEN 1 WHEN 'bad'    THEN 1
            WHEN '2' THEN 2 WHEN 'medium' THEN 2 WHEN 'good'   THEN 2
            WHEN '3' THEN 3 WHEN 'high'   THEN 3 WHEN 'better' THEN 3
            WHEN '4' THEN 4 WHEN 'very high' THEN 4 WHEN 'best' THEN 4
        END AS JobInvolvementSort
    FROM dbo.HR_Attrition AS H
) AS B;
GO

------------------------------------------------------------
-- 1. DATA QUALITY CHECKS (on the original table)
------------------------------------------------------------
SELECT COUNT(*) AS TotalEmployees, COUNT(DISTINCT EmployeeNumber) AS DistinctEmployees
FROM dbo.HR_Attrition;

SELECT
    SUM(CASE WHEN EmployeeNumber IS NULL THEN 1 ELSE 0 END) AS MissingEmployeeNumber,
    SUM(CASE WHEN Attrition      IS NULL THEN 1 ELSE 0 END) AS MissingAttrition,
    SUM(CASE WHEN Department     IS NULL THEN 1 ELSE 0 END) AS MissingDepartment,
    SUM(CASE WHEN JobRole        IS NULL THEN 1 ELSE 0 END) AS MissingJobRole,
    SUM(CASE WHEN MonthlyIncome  IS NULL THEN 1 ELSE 0 END) AS MissingMonthlyIncome
FROM dbo.HR_Attrition;

SELECT MIN(Age) AS MinAge, MAX(Age) AS MaxAge,
       MIN(MonthlyIncome) AS MinMonthlyIncome, MAX(MonthlyIncome) AS MaxMonthlyIncome,
       MIN(YearsAtCompany) AS MinYearsAtCompany, MAX(YearsAtCompany) AS MaxYearsAtCompany
FROM dbo.HR_Attrition;

-- Additional checks: unexpected categories / values that would otherwise be hidden
SELECT
    SUM(CASE WHEN Attrition = 'Unknown' THEN 1 ELSE 0 END) AS UnknownAttritionRows,
    SUM(CASE WHEN OverTime = 'Unknown' THEN 1 ELSE 0 END) AS UnknownOverTimeRows,
    SUM(CASE WHEN JobSatisfactionSort IS NULL THEN 1 ELSE 0 END) AS UnmappedJobSatisfactionRows,
    SUM(CASE WHEN WorkLifeBalanceSort IS NULL THEN 1 ELSE 0 END) AS UnmappedWorkLifeBalanceRows,
    SUM(CASE WHEN EnvironmentSatisfactionSort IS NULL THEN 1 ELSE 0 END) AS UnmappedEnvironmentSatisfactionRows,
    SUM(CASE WHEN RelationshipSatisfactionSort IS NULL THEN 1 ELSE 0 END) AS UnmappedRelationshipSatisfactionRows,
    SUM(CASE WHEN JobInvolvementSort IS NULL THEN 1 ELSE 0 END) AS UnmappedJobInvolvementRows
FROM dbo.vw_HR_Clean;

------------------------------------------------------------
-- 2. EXECUTIVE KPIs
------------------------------------------------------------
SELECT COUNT(*)                                   AS TotalEmployees,
       SUM(AttritionFlag)                         AS EmployeesLeft,
       COUNT(*) - SUM(AttritionFlag)              AS EmployeesStayed,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct,
       CAST(AVG(1.0 * Age) AS decimal(5,2))              AS AverageAge,
       CAST(AVG(1.0 * MonthlyIncome) AS decimal(12,2))   AS AverageMonthlyIncome,
       CAST(AVG(1.0 * YearsAtCompany) AS decimal(6,2))   AS AverageYearsAtCompany,
       SUM(CASE WHEN OverTime = 'Yes' THEN 1 ELSE 0 END) AS OvertimeEmployees,
       SUM(CASE WHEN OverTime = 'Yes' AND AttritionFlag = 1 THEN 1 ELSE 0 END) AS OvertimeEmployeesWhoLeft,
       CAST(100.0 * SUM(CASE WHEN OverTime = 'Yes' AND AttritionFlag = 1 THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN OverTime = 'Yes' AND AttritionFlag IS NOT NULL THEN 1 ELSE 0 END), 0) AS decimal(5,2)) AS OvertimeAttritionRatePct
FROM dbo.vw_HR_Clean;

------------------------------------------------------------
-- 3. ATTRITION BY DEPARTMENT
------------------------------------------------------------
SELECT Department, COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY Department
ORDER BY AttritionRatePct DESC;

------------------------------------------------------------
-- 4. ATTRITION BY JOB ROLE
------------------------------------------------------------
SELECT JobRole, COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct,
       CAST(AVG(1.0 * MonthlyIncome) AS decimal(12,2)) AS AverageMonthlyIncome
FROM dbo.vw_HR_Clean
GROUP BY JobRole
ORDER BY AttritionRatePct DESC;

------------------------------------------------------------
-- 5. ATTRITION BY OVERTIME
------------------------------------------------------------
SELECT OverTime, COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY OverTime
ORDER BY AttritionRatePct DESC;

------------------------------------------------------------
-- 6. ATTRITION BY AGE GROUP
------------------------------------------------------------
SELECT AgeGroup, COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY AgeGroup, AgeGroupSort
ORDER BY AgeGroupSort;

------------------------------------------------------------
-- 7. ATTRITION BY TENURE BAND
------------------------------------------------------------
SELECT TenureBand, COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY TenureBand, TenureBandSort
ORDER BY TenureBandSort;

------------------------------------------------------------
-- 8. ATTRITION BY INCOME BAND
------------------------------------------------------------
SELECT IncomeBand, COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY IncomeBand, IncomeBandSort
ORDER BY IncomeBandSort;

------------------------------------------------------------
-- 9. SATISFACTION, WORK-LIFE BALANCE AND INVOLVEMENT
--    (ordered from the lowest rating to the highest)
------------------------------------------------------------
SELECT JobSatisfactionSort AS RatingValue, JobSatisfactionLabel AS JobSatisfaction,
       COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY JobSatisfactionSort, JobSatisfactionLabel
ORDER BY RatingValue;

SELECT WorkLifeBalanceSort AS RatingValue, WorkLifeBalanceLabel AS WorkLifeBalance,
       COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY WorkLifeBalanceSort, WorkLifeBalanceLabel
ORDER BY RatingValue;

SELECT EnvironmentSatisfactionSort AS RatingValue, EnvironmentSatisfactionLabel AS EnvironmentSatisfaction,
       COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY EnvironmentSatisfactionSort, EnvironmentSatisfactionLabel
ORDER BY RatingValue;

SELECT RelationshipSatisfactionSort AS RatingValue, RelationshipSatisfactionLabel AS RelationshipSatisfaction,
       COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY RelationshipSatisfactionSort, RelationshipSatisfactionLabel
ORDER BY RatingValue;

SELECT JobInvolvementSort AS RatingValue, JobInvolvementLabel AS JobInvolvement,
       COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY JobInvolvementSort, JobInvolvementLabel
ORDER BY RatingValue;

------------------------------------------------------------
-- 10. BUSINESS TRAVEL AND MARITAL STATUS
------------------------------------------------------------
SELECT BusinessTravel, COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY BusinessTravel
ORDER BY AttritionRatePct DESC;

SELECT MaritalStatus, COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY MaritalStatus
ORDER BY AttritionRatePct DESC;

------------------------------------------------------------
-- 11. EMPLOYEES WHO LEFT VS STAYED
------------------------------------------------------------
SELECT AttritionStatus, COUNT(*) AS Employees,
       CAST(AVG(1.0 * Age) AS decimal(5,2))                     AS AvgAge,
       CAST(AVG(1.0 * MonthlyIncome) AS decimal(12,2))          AS AvgMonthlyIncome,
       CAST(AVG(1.0 * DistanceFromHome) AS decimal(6,2))        AS AvgDistanceFromHome,
       CAST(AVG(1.0 * TotalWorkingYears) AS decimal(6,2))       AS AvgTotalWorkingYears,
       CAST(AVG(1.0 * YearsAtCompany) AS decimal(6,2))          AS AvgYearsAtCompany,
       CAST(AVG(1.0 * YearsSinceLastPromotion) AS decimal(6,2)) AS AvgYearsSincePromotion
FROM dbo.vw_HR_Clean
GROUP BY AttritionStatus;

------------------------------------------------------------
-- 12. DEPARTMENT + OVERTIME
------------------------------------------------------------
SELECT Department, OverTime, COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean
GROUP BY Department, OverTime
ORDER BY Department, AttritionRatePct DESC;

------------------------------------------------------------
-- 13. CTE + DENSE_RANK: ATTRITION RATE BY JOB ROLE
------------------------------------------------------------
;WITH RoleMetrics AS (
    SELECT JobRole, COUNT(*) AS TotalEmployees, SUM(AttritionFlag) AS EmployeesLeft,
           100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS AttritionRatePct
    FROM dbo.vw_HR_Clean
    GROUP BY JobRole
)
SELECT JobRole, TotalEmployees, EmployeesLeft,
       CAST(AttritionRatePct AS decimal(5,2)) AS AttritionRatePct,
       DENSE_RANK() OVER (ORDER BY AttritionRatePct DESC) AS AttritionRateRank
FROM RoleMetrics
ORDER BY AttritionRateRank, JobRole;

------------------------------------------------------------
-- 14. ROW_NUMBER: TOP 3 EARNERS IN EACH DEPARTMENT
------------------------------------------------------------
;WITH RankedIncome AS (
    SELECT EmployeeNumber, Department, JobRole, MonthlyIncome, AttritionStatus,
           ROW_NUMBER() OVER (PARTITION BY Department ORDER BY MonthlyIncome DESC, EmployeeNumber) AS IncomeRankInDepartment
    FROM dbo.vw_HR_Clean
)
SELECT Department, IncomeRankInDepartment, EmployeeNumber, JobRole, MonthlyIncome, AttritionStatus
FROM RankedIncome
WHERE IncomeRankInDepartment <= 3
ORDER BY Department, IncomeRankInDepartment;

------------------------------------------------------------
-- 15. RETENTION REVIEW LIST (current employees only - screening, not prediction)
--     Working overtime AND (low/medium job satisfaction OR low/medium work-life balance)
------------------------------------------------------------
SELECT EmployeeNumber, Age, Department, JobRole, MonthlyIncome, YearsAtCompany,
       JobSatisfactionLabel AS JobSatisfaction,
       WorkLifeBalanceLabel AS WorkLifeBalance,
       OverTime
FROM dbo.vw_HR_Clean
WHERE AttritionFlag = 0
  AND OverTime = 'Yes'
  AND (JobSatisfactionSort <= 2 OR WorkLifeBalanceSort <= 2)
ORDER BY YearsAtCompany ASC, MonthlyIncome ASC;

------------------------------------------------------------
-- 16. MEDIAN ANALYSIS (PERCENTILE_CONT as a window function)
------------------------------------------------------------
SELECT DISTINCT
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(Age AS float))            OVER () AS decimal(10,2)) AS MedianAge,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(MonthlyIncome AS float))  OVER () AS decimal(12,2)) AS MedianMonthlyIncome,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(YearsAtCompany AS float)) OVER () AS decimal(10,2)) AS MedianYearsAtCompany
FROM dbo.vw_HR_Clean;

------------------------------------------------------------
-- 17. DASHBOARD SUMMARY DATASET
------------------------------------------------------------
SELECT Department, AgeGroup, TenureBand, IncomeBand, OverTime,
       COUNT(*) AS EmployeeCount,
       SUM(AttritionFlag) AS EmployeesLeft,
       CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct,
       CAST(AVG(1.0 * MonthlyIncome) AS decimal(12,2)) AS AverageMonthlyIncome
FROM dbo.vw_HR_Clean
GROUP BY Department, AgeGroup, AgeGroupSort, TenureBand, TenureBandSort, IncomeBand, IncomeBandSort, OverTime
ORDER BY Department, AgeGroupSort, TenureBandSort, IncomeBandSort;


------------------------------------------------------------
-- 18. FINAL VALIDATION SUMMARY
------------------------------------------------------------
SELECT
    COUNT(*) AS TotalRows,
    COUNT(DISTINCT EmployeeNumber) AS DistinctEmployeeNumbers,
    SUM(CASE WHEN AttritionFlag = 1 THEN 1 ELSE 0 END) AS EmployeesLeft,
    SUM(CASE WHEN AttritionFlag = 0 THEN 1 ELSE 0 END) AS EmployeesStayed,
    SUM(CASE WHEN AttritionFlag IS NULL THEN 1 ELSE 0 END) AS UnknownAttritionRows,
    CAST(100.0 * SUM(AttritionFlag) / NULLIF(COUNT(AttritionFlag), 0) AS decimal(5,2)) AS AttritionRatePct
FROM dbo.vw_HR_Clean;

-- Expected for the original IBM HR sample: 1470 rows, 1470 distinct employees,
-- 237 left, 1233 stayed, 0 unknown attrition rows, attrition rate 16.12%.
-- If these differ, check that the correct source table/data is loaded.
