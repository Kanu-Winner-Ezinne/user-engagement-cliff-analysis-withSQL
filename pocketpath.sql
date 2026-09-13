/*
Project: Pocketpath – The Stickiness Cliff
Author: Kanu Winner Ezinne
Database: PostgreSQL

Goal:
Investigate why dashboard stickiness dropped after Release 5.2
and determine whether real-user engagement actually declined.

Before release: 3–9 August 2026
After release: 17–23 August 2026
Release 5.2: 10 August 2026

Definitions:
DAU = distinct users with an app_open on that day
MAU = distinct users with an app_open during the rolling
      28-day window ending on that day
Stickiness = DAU / MAU
Internal users are excluded when measuring real-user engagement.

All timestamps are UTC.
*/



--  CREATE TABLES


CREATE TABLE users (
    user_id TEXT,
    signup_date DATE,
    platform TEXT,
    acquisition_channel TEXT,
    is_internal BOOLEAN
);

CREATE TABLE events (
    user_id TEXT,
    event_ts TIMESTAMP,
    event_name TEXT,
    app_version TEXT,
    platform TEXT
);



-- BASIC DATA EXPLORATION
-

SELECT COUNT(*) AS total_users
FROM users;

SELECT COUNT(*) AS total_events
FROM events;

SELECT *
FROM users
LIMIT 10;

SELECT *
FROM events
LIMIT 10;

SELECT
    MIN(event_ts) AS first_event,
    MAX(event_ts) AS last_event
FROM events;



--  INTERNAL USERS


SELECT
    is_internal,
    COUNT(*) AS number_of_users
FROM users
GROUP BY is_internal
ORDER BY is_internal;



-- EVENT TYPES


SELECT
    event_name,
    COUNT(*) AS events
FROM events
GROUP BY event_name
ORDER BY events DESC;

-- there are 17,5399 app_open event

--  APP VERSIONS AND PLATFORMS


SELECT
    app_version,
    platform,
    COUNT(*) AS events
FROM events
GROUP BY app_version, platform
ORDER BY app_version, platform;

-- for 5.1.4 app_ version we have 72,629 events for  android version and 65638 events for ios version
-- for 5.2.0 app_version we have 16731 events for android version and  20401 events for ios version



--  CHECK FOR DUPLICATE EVENT ROWS


SELECT
    user_id,
    event_ts,
    event_name,
    app_version,
    platform,
    COUNT(*) AS duplicate_count
FROM events
GROUP BY
    user_id,
    event_ts,
    event_name,
    app_version,
    platform
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;



-- creating  a temporary duplicate-free version of events
-- removing duplicate rows

WITH deduped_events AS (
    SELECT DISTINCT
        user_id,
        event_ts,
        event_name,
        app_version,
        platform
    FROM events
)

SELECT *
FROM deduped_events
WHERE event_name = 'app_open'
LIMIT 20;



-- 8. DAILY ACTIVE USERS


WITH deduped_events AS (
    SELECT DISTINCT
        user_id,
        event_ts,
        event_name,
        app_version,
        platform
    FROM events
)

SELECT
    event_ts::date AS event_date,
    COUNT(DISTINCT user_id) AS dau
FROM deduped_events
WHERE event_name = 'app_open'
GROUP BY event_ts::date
ORDER BY event_date;



--  DAILY DAU  WHICH EXCLUDes INTERNAL USERS


WITH deduped_events AS (
    SELECT DISTINCT
        user_id,
        event_ts,
        event_name,
        app_version,
        platform
    FROM events
)

SELECT
    e.event_ts::date AS event_date,
    COUNT(DISTINCT e.user_id) AS real_user_dau
FROM deduped_events e
JOIN users u
    ON e.user_id = u.user_id
WHERE e.event_name = 'app_open'
  AND u.is_internal = FALSE
GROUP BY e.event_ts::date
ORDER BY e.event_ts::date;


-- ROLLING 28-DAY MAU
--For each day, how many unique users opened the app at least once during that day and the previous 27 days?


WITH deduped_events AS (
    SELECT DISTINCT
        user_id,
        event_ts,
        event_name,
        app_version,
        platform
    FROM events
),

app_opens AS (
    SELECT
        user_id,
        event_ts::date AS event_date
    FROM deduped_events
    WHERE event_name = 'app_open'
),

dates AS (
    SELECT DISTINCT event_date
    FROM app_opens
)

SELECT
    d.event_date,
    COUNT(DISTINCT a.user_id) AS mau
FROM dates d
JOIN app_opens a
    ON a.event_date BETWEEN d.event_date - 27
                         AND d.event_date
GROUP BY d.event_date
ORDER BY d.event_date;



-- 11. REAL-USER ROLLING 28-DAY MAU


WITH deduped_events AS (
    SELECT DISTINCT
        user_id,
        event_ts,
        event_name,
        app_version,
        platform
    FROM events
),

app_opens AS (
    SELECT
        e.user_id,
        e.event_ts::date AS event_date
    FROM deduped_events e
    JOIN users u
        ON e.user_id = u.user_id
    WHERE e.event_name = 'app_open'
      AND u.is_internal = FALSE
),

dates AS (
    SELECT DISTINCT event_date
    FROM app_opens
)

SELECT
    d.event_date,
    COUNT(DISTINCT a.user_id) AS real_user_mau
FROM dates d
JOIN app_opens a
    ON a.event_date BETWEEN d.event_date - 27
                         AND d.event_date
GROUP BY d.event_date
ORDER BY d.event_date;



--  REAL-USER DAILY STICKINESS
-- Remove duplicate events  to identify internal users →and calculate real-user DAU,
-- real-user 28-day MAU , divide DAU by MAU to get daily real-user stickiness.


WITH deduped_events AS (
    SELECT DISTINCT
        user_id,
        event_ts,
        event_name,
        app_version,
        platform
    FROM events
),

app_opens AS (
    SELECT
        e.user_id,
        e.event_ts::date AS event_date,
        u.is_internal
    FROM deduped_events e
    JOIN users u
        ON e.user_id = u.user_id
    WHERE e.event_name = 'app_open'
),

dates AS (
    SELECT DISTINCT event_date
    FROM app_opens
),

daily AS (
    SELECT
        event_date,
        COUNT(DISTINCT user_id) AS dau
    FROM app_opens
    WHERE is_internal = FALSE
    GROUP BY event_date
),

mau AS (
    SELECT
        d.event_date,
        COUNT(DISTINCT a.user_id) AS mau
    FROM dates d
    JOIN app_opens a
        ON a.event_date BETWEEN d.event_date - 27
                             AND d.event_date
    WHERE a.is_internal = FALSE
    GROUP BY d.event_date
)

SELECT
    daily.event_date,
    daily.dau,
    mau.mau,
    ROUND(
        100.0 * daily.dau / NULLIF(mau.mau, 0),
        2
    ) AS stickiness_percent
FROM daily
JOIN mau
    ON daily.event_date = mau.event_date
ORDER BY daily.event_date;



-- BUSINESS QUESTIONS


-- QUESTION 1
-- Average daily stickiness for 3–9 August
-- excluding internal accounts


WITH deduped_events AS (
    SELECT DISTINCT
        user_id,
        event_ts,
        event_name,
        app_version,
        platform
    FROM events
),

app_opens AS (
    SELECT
        e.user_id,
        e.event_ts::date AS event_date
    FROM deduped_events e
    JOIN users u
        ON e.user_id = u.user_id
    WHERE e.event_name = 'app_open'
      AND u.is_internal = FALSE
),

dates AS (
    SELECT DISTINCT event_date
    FROM app_opens
),

daily AS (
    SELECT
        event_date,
        COUNT(DISTINCT user_id) AS dau
    FROM app_opens
    GROUP BY event_date
),

mau AS (
    SELECT
        d.event_date,
        COUNT(DISTINCT a.user_id) AS mau
    FROM dates d
    JOIN app_opens a
        ON a.event_date BETWEEN d.event_date - 27
                             AND d.event_date
    GROUP BY d.event_date
)

SELECT
    ROUND(
        AVG(
            100.0 * daily.dau / NULLIF(mau.mau, 0)
        ),
        1
    ) AS average_stickiness
FROM daily
JOIN mau
    ON daily.event_date = mau.event_date
WHERE daily.event_date
      BETWEEN '2026-08-03' AND '2026-08-09';

----average real-user stickiness from 3–9 August 2026 is 28.5%.


-- QUESTION 2
-- Average daily stickiness for 17–23 August excluding internal accounts

WITH deduped_events AS (
    SELECT DISTINCT
        user_id,
        event_ts,
        event_name,
        app_version,
        platform
    FROM events
),

app_opens AS (
    SELECT
        e.user_id,
        e.event_ts::date AS event_date
    FROM deduped_events e
    JOIN users u
        ON e.user_id = u.user_id
    WHERE e.event_name = 'app_open'
      AND u.is_internal = FALSE
),

dates AS (
    SELECT DISTINCT event_date
    FROM app_opens
),

daily AS (
    SELECT
        event_date,
        COUNT(DISTINCT user_id) AS dau
    FROM app_opens
    GROUP BY event_date
),

mau AS (
    SELECT
        d.event_date,
        COUNT(DISTINCT a.user_id) AS mau
    FROM dates d
    JOIN app_opens a
        ON a.event_date BETWEEN d.event_date - 27
                             AND d.event_date
    GROUP BY d.event_date
)

SELECT
    ROUND(
        AVG(
            100.0 * daily.dau / NULLIF(mau.mau, 0)
        ),
        1
    ) AS average_stickiness
FROM daily
JOIN mau
    ON daily.event_date = mau.event_date
WHERE daily.event_date
      BETWEEN '2026-08-17' AND '2026-08-23';
--- 28.4% average real-user stickiness after the release (17–23 Aug 2026).

-- QUESTION 3
-- Average share of DAU that were internal accounts during 3–9 August

WITH deduped_events AS (
    SELECT DISTINCT
        user_id,
        event_ts,
        event_name,
        app_version,
        platform
    FROM events
),

daily AS (
    SELECT
        e.event_ts::date AS event_date,

        COUNT(DISTINCT e.user_id) AS total_dau,

        COUNT(DISTINCT e.user_id)
            FILTER (WHERE u.is_internal = TRUE) AS internal_dau

    FROM deduped_events e
    JOIN users u
        ON e.user_id = u.user_id

    WHERE e.event_name = 'app_open'
      AND e.event_ts::date
          BETWEEN '2026-08-03' AND '2026-08-09'

    GROUP BY e.event_ts::date
)

SELECT
    ROUND(
        AVG(
            100.0 * internal_dau / NULLIF(total_dau, 0)
        ),
        1
    ) AS average_internal_share
FROM daily;



-- QUESTION 4
-- Number of non-internal app opens during 17–23 August One open = one distinct (user_id, event_ts) pair.


SELECT
    COUNT(
        DISTINCT (e.user_id, e.event_ts)
    ) AS non_internal_app_opens
FROM events e
JOIN users u
    ON e.user_id = u.user_id
WHERE e.event_name = 'app_open'
  AND u.is_internal = FALSE
  AND e.event_ts::date
      BETWEEN '2026-08-17' AND '2026-08-23';



-- QUESTION 5
-- DID REAL USER ENGAGEMENT DECLINE?


WITH deduped_events AS (
    SELECT DISTINCT
        user_id,
        event_ts,
        event_name,
        app_version,
        platform
    FROM events
),

app_opens AS (
    SELECT
        e.user_id,
        e.event_ts::date AS event_date
    FROM deduped_events e
    JOIN users u
        ON e.user_id = u.user_id
    WHERE e.event_name = 'app_open'
      AND u.is_internal = FALSE
),

dates AS (
    SELECT DISTINCT event_date
    FROM app_opens
),

daily AS (
    SELECT
        event_date,
        COUNT(DISTINCT user_id) AS dau
    FROM app_opens
    GROUP BY event_date
),

mau AS (
    SELECT
        d.event_date,
        COUNT(DISTINCT a.user_id) AS mau
    FROM dates d
    JOIN app_opens a
        ON a.event_date BETWEEN d.event_date - 27
                             AND d.event_date
    GROUP BY d.event_date
),

stickiness AS (
    SELECT
        daily.event_date,
        100.0 * daily.dau / NULLIF(mau.mau, 0) AS stickiness
    FROM daily
    JOIN mau
        ON daily.event_date = mau.event_date
)

SELECT
    CASE
        WHEN event_date BETWEEN '2026-08-03' AND '2026-08-09'
            THEN 'Before'
        WHEN event_date BETWEEN '2026-08-17' AND '2026-08-23'
            THEN 'After'
    END AS period,

    ROUND(AVG(stickiness), 1) AS average_stickiness

FROM stickiness

WHERE event_date BETWEEN '2026-08-03' AND '2026-08-09'
   OR event_date BETWEEN '2026-08-17' AND '2026-08-23'

GROUP BY
    CASE
        WHEN event_date BETWEEN '2026-08-03' AND '2026-08-09'
            THEN 'Before'
        WHEN event_date BETWEEN '2026-08-17' AND '2026-08-23'
            THEN 'After'
    END

ORDER BY period;


/*
Question 1:
Average stickiness, 3–9 August = 28.5%

Question 2:
Average stickiness, 17–23 August = 28.4%

Question 3:
Average internal DAU share, 3–9 August = 26.1%

Question 4:
Non-internal app opens, 17–23 August = 15,096

Question 5:
No — real-user stickiness was essentially unchanged.
*/

--

/*
The drop in stickiness after Release 5.2 does NOT mean
real customers stopped using the app.

Before the release, internal/QA users made up 26.1% of DAU.
Release 5.2 moved QA users from production to staging.

So after the release, those internal users were no longer
being counted in the production dashboard.

When we look only at real customers:
- Before release: 28.5% stickiness
- After release: 28.4% stickiness

That's only a 0.1 percentage-point drop.

So real customer engagement basically stayed the same.

The dashboard should remove internal and QA users from
DAU, MAU, and stickiness calculations.

Because real customer engagement did not fall,
the roadmap should NOT stay paused because of this issue.

The iOS duplicate-logging problem should be checked
separately, but it does not change our main conclusion.
*/