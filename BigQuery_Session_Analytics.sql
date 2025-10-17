-- Estas consultas responden a las siguientes preguntas:

-- 1. What is the average amount of time that users spend in the app per session?
-- 2. Which parts of the app do users spend the most time on?
-- 3. Home is the part of the app in which users spend more time?


-- CONSULTA 1: Tiempo promedio de sesión por usuario

WITH session_data AS (
  SELECT
    user_pseudo_id,
    COALESCE(
      (SELECT ep.value.int_value    FROM UNNEST(event_params) ep WHERE ep.key = 'duration_ms'),
      CAST((SELECT ep.value.double_value FROM UNNEST(event_params) ep WHERE ep.key = 'duration_ms') AS INT64)
    ) AS duration_ms
  FROM `sumaq-a2de4.analytics_504174045.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20251015' AND '20251201'
    AND event_name = 'session_end_custom'
)
SELECT
  'Average Session Duration' AS metric,
  AVG(duration_ms)/1000 AS avg_seconds,
  AVG(duration_ms)/60000 AS avg_minutes,
  COUNTIF(duration_ms IS NOT NULL) AS total_sessions,
  COUNT(DISTINCT user_pseudo_id) AS unique_users
FROM session_data
UNION ALL
SELECT
  'Median Session Duration' AS metric,
  APPROX_QUANTILES(duration_ms, 100)[OFFSET(50)]/1000  AS avg_seconds,
  APPROX_QUANTILES(duration_ms, 100)[OFFSET(50)]/60000 AS avg_minutes,
  COUNTIF(duration_ms IS NOT NULL) AS total_sessions,
  COUNT(DISTINCT user_pseudo_id) AS unique_users
FROM session_data;

-- CONSULTA 2: Tiempo por pantalla

WITH screen_time AS (
  SELECT
    user_pseudo_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key='screen_name')      AS screen_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key='screen_category')  AS screen_category,

    COALESCE(
      (SELECT value.int_value    FROM UNNEST(event_params) WHERE key='screen_duration_seconds'),
      CAST((SELECT value.double_value FROM UNNEST(event_params) WHERE key='screen_duration_seconds') AS INT64),

      CAST(ROUND(COALESCE(
          (SELECT value.int_value    FROM UNNEST(event_params) WHERE key='duration_ms'),
          CAST((SELECT value.double_value FROM UNNEST(event_params) WHERE key='duration_ms') AS INT64)
      )/1000.0) AS INT64)
    ) AS duration_seconds
  FROM `sumaq-a2de4.analytics_504174045.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20251015' AND '20251201'
    AND event_name = 'screen_end'
)
SELECT
  CASE 
    WHEN screen_name IS NULL OR screen_name = '(unknown)' THEN 'other screens'
    ELSE screen_name
  END AS screen_name,
  
  CASE 
    WHEN screen_category IS NULL OR screen_category = '(none)' THEN 'other screens'
    ELSE screen_category
  END AS screen_category,

  AVG(duration_seconds)/60  AS avg_duration_minutes,
  SUM(duration_seconds)/60  AS total_time_minutes,
  COUNT(*)                  AS total_sessions,
  COUNT(DISTINCT user_pseudo_id) AS unique_users
FROM screen_time
WHERE duration_seconds IS NOT NULL
GROUP BY 1,2
ORDER BY total_time_minutes DESC;


-- CONSULTA 3: Comparación Home vs otras pantallas


WITH base AS (
  SELECT _TABLE_SUFFIX AS table_suffix, event_name, user_pseudo_id, event_params
  FROM `sumaq-a2de4.analytics_504174045.events_*`
  UNION ALL
  SELECT _TABLE_SUFFIX AS table_suffix, event_name, user_pseudo_id, event_params
  FROM `sumaq-a2de4.analytics_504174045.events_intraday_*`
),
screen_time AS (
  SELECT
    LOWER((SELECT value.string_value FROM UNNEST(event_params) WHERE key='screen_name')) AS screen_name_raw,
    COALESCE(
      (SELECT value.int_value    FROM UNNEST(event_params) WHERE key='screen_duration_seconds'),
      CAST((SELECT value.double_value FROM UNNEST(event_params) WHERE key='screen_duration_seconds') AS INT64),
      CAST(ROUND(COALESCE(
        (SELECT value.int_value    FROM UNNEST(event_params) WHERE key='duration_ms'),
        CAST((SELECT value.double_value FROM UNNEST(event_params) WHERE key='duration_ms') AS INT64)
      )/1000.0) AS INT64)
    ) AS duration_seconds
  FROM base
  WHERE table_suffix BETWEEN '20251015' AND '20251201'
    AND event_name = 'screen_end'
),
screen_time_clean AS (
  SELECT COALESCE(NULLIF(screen_name_raw,''), 'other screen') AS screen_name, duration_seconds
  FROM screen_time
  WHERE duration_seconds IS NOT NULL
),
screen_stats AS (
  SELECT
    screen_name,
    SUM(duration_seconds)/60.0 AS total_time_minutes,
    AVG(duration_seconds)/60.0 AS avg_duration_minutes,
    COUNT(*) AS total_sessions
  FROM screen_time_clean
  GROUP BY screen_name
),
home_stats AS (SELECT * FROM screen_stats WHERE screen_name = 'home'),
top_other AS (
  SELECT screen_name, total_time_minutes
  FROM screen_stats
  WHERE screen_name <> 'home'
  ORDER BY total_time_minutes DESC
  LIMIT 1
)
SELECT
  IFNULL((SELECT total_time_minutes FROM home_stats),0) >= IFNULL((SELECT total_time_minutes FROM top_other),0)
    AS home_is_top_by_total_time,
  IFNULL((SELECT total_time_minutes   FROM home_stats),0) AS home_total_minutes,
  IFNULL((SELECT avg_duration_minutes FROM home_stats),0) AS home_avg_minutes,
  IFNULL((SELECT total_time_minutes   FROM top_other),0)  AS top_other_total_minutes,
  IFNULL((SELECT screen_name          FROM top_other),'other screen') AS top_other_screen,
  IFNULL((SELECT total_time_minutes FROM home_stats),0)
  - IFNULL((SELECT total_time_minutes FROM top_other),0) AS diff_minutes;

