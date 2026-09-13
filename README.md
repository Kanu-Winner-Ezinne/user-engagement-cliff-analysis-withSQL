# Pocketpath – The Stickiness Cliff

## Project Overview

Pocketpath Growth noticed that product stickiness dropped from around **35% to 28%** after Release 5.2 on **August 10, 2026**.

The team was concerned that real user engagement had suddenly declined.

My goal was to investigate the data and determine whether the drop was a real engagement problem or a measurement issue.

---

## Business Question

**Did real user engagement actually decline after Release 5.2?**

I used PostgreSQL to analyze:

- Daily Active Users (DAU)
- Rolling 28-day Monthly Active Users (MAU)
- Stickiness (DAU / MAU)
- Internal vs. external users
- App opens
- Duplicate events

---

## Data

The project contains two datasets:

**users.csv**
- User ID
- Signup date
- Platform
- Acquisition channel
- Internal account flag

**events.csv**
- User ID
- Event timestamp
- Event name
- App version
- Platform

The event data covers **July 6, 2026 through August 23, 2026; all timestamps are stored in UTC.**

---

## Approach

I followed a simple analysis process:

### 1. Explore the data

I checked the number of users, events, event types, app versions, dates, and internal accounts.

The dataset contains:

- **5,000 external users**
- **400 internal/test users**
- **175,399 app_open events**

### 2. Calculate DAU

DAU was calculated as the number of unique users who opened the app each day.

### 3. Calculate rolling 28-day MAU

MAU was calculated using the unique users who opened the app during the previous 28 days, including the current day.

### 4. Calculate stickiness

**Stickiness = DAU / MAU × 100**

I calculated this both with and without internal/test accounts.

### 5. Compare before and after Release 5.2

I compared user engagement before and after the August 10 release to understand what caused the dashboard decline.

---

## Key Findings

The overall dashboard showed a large drop:

**~35% → ~26% stickiness**

At first, this looked like a serious engagement problem.

However, internal/test accounts made up **26.1% of DAU** before the release.

When I removed these accounts and looked only at real users:

| Period | Real-user Stickiness |
|---|---:|
| Aug 3–9 | **28.5%** |
| Aug 17–23 | **28.4%** |

Real-user stickiness changed by only **0.1 percentage points**.

This shows that real customer engagement was essentially unchanged.

---

## Answers

| Question | Answer |
|---|---:|
| Average stickiness, Aug 3–9 | **28.5%** |
| Average stickiness, Aug 17–23 | **28.4%** |
| Average internal DAU share, Aug 3–9 | **26.1%** |
| Non-internal app opens, Aug 17–23 | **15,096** |
| Engagement emergency? | **No** |

---

## Conclusion

The apparent stickiness cliff was **not caused by real customers becoming less engaged**.

The main reason for the drop was that **internal/test accounts stopped using the production environment after Release 5.2**. Because these accounts were included in the original dashboard, their activity had been inflating the metric.

### Recommendation

**No, this is not an engagement emergency.**

The company should update its engagement dashboards to **exclude internal and test accounts** so that DAU, MAU, and stickiness represent real customer behavior.

This analysis shows why it is important to **validate a metric before reacting to a large change in the dashboard.**

---

## Tools

- PostgreSQL
- SQL
- GitHub

## Skills Demonstrated

- Data cleaning and validation
- SQL joins
- CTEs
- `COUNT(DISTINCT)`
- DAU and MAU calculations
- Rolling 28-day metrics
- Stickiness analysis
- Duplicate detection
- Business analysis
- Data-driven recommendations
