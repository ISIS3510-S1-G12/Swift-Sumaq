-- =============================================
-- BIGQUERY QUERIES FOR SESSION ANALYTICS
-- =============================================
-- 
-- Estas consultas responden a las siguientes preguntas:
-- 1. What is the average amount of time that users spend in the app per session?
-- 2. Which parts of the app do users spend the most time on?
-- 3. Home is the part of the app in which users spend more time?
--
-- INSTRUCCIONES:
-- 1. Reemplaza 'your-project.analytics_XXXXXX' con tu proyecto real
-- 2. Ajusta las fechas en _TABLE_SUFFIX según necesites
-- 3. Ejecuta las consultas en BigQuery Console
-- =============================================

-- =============================================
-- CONSULTA 1: Tiempo promedio de sesión por usuario
-- =============================================
-- Pregunta: What is the average amount of time that users spend in the app per session?

WITH session_data AS (
  SELECT 
    user_pseudo_id,
    event_timestamp,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'session_duration_seconds') as session_duration
  FROM `your-project.analytics_XXXXXX.events_*`
  WHERE event_name = 'session_end'
    AND _TABLE_SUFFIX BETWEEN '20241201' AND '20241231'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'session_duration_seconds') IS NOT NULL
)
SELECT 
  'Average Session Duration' as metric,
  AVG(session_duration) as avg_seconds,
  AVG(session_duration)/60 as avg_minutes,
  COUNT(*) as total_sessions,
  COUNT(DISTINCT user_pseudo_id) as unique_users
FROM session_data

UNION ALL

SELECT 
  'Median Session Duration' as metric,
  APPROX_QUANTILES(session_duration, 100)[OFFSET(50)] as avg_seconds,
  APPROX_QUANTILES(session_duration, 100)[OFFSET(50)]/60 as avg_minutes,
  COUNT(*) as total_sessions,
  COUNT(DISTINCT user_pseudo_id) as unique_users
FROM session_data;

-- =============================================
-- CONSULTA 2: Tiempo por pantalla/categoría
-- =============================================
-- Pregunta: Which parts of the app do users spend the most time on?

WITH screen_time AS (
  SELECT 
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'screen_name') as screen_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'screen_category') as screen_category,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'screen_duration_seconds') as duration_seconds
  FROM `your-project.analytics_XXXXXX.events_*`
  WHERE event_name = 'screen_end'
    AND _TABLE_SUFFIX BETWEEN '20241201' AND '20241231'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'screen_duration_seconds') IS NOT NULL
)
SELECT 
  screen_name,
  screen_category,
  AVG(duration_seconds)/60 as avg_duration_minutes,
  SUM(duration_seconds)/60 as total_time_minutes,
  COUNT(*) as total_sessions,
  COUNT(DISTINCT user_pseudo_id) as unique_users
FROM screen_time
GROUP BY screen_name, screen_category
ORDER BY total_time_minutes DESC;

-- =============================================
-- CONSULTA 3: Comparación específica - Home vs otras pantallas
-- =============================================
-- Pregunta: Home is the part of the app in which users spend more time?

WITH screen_time AS (
  SELECT 
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'screen_name') as screen_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'screen_category') as screen_category,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'screen_duration_seconds') as duration_seconds
  FROM `your-project.analytics_XXXXXX.events_*`
  WHERE event_name = 'screen_end'
    AND _TABLE_SUFFIX BETWEEN '20241201' AND '20241231'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'screen_duration_seconds') IS NOT NULL
),
screen_stats AS (
  SELECT 
    screen_name,
    AVG(duration_seconds)/60 as avg_duration_minutes,
    SUM(duration_seconds)/60 as total_time_minutes,
    COUNT(*) as total_sessions,
    COUNT(DISTINCT user_pseudo_id) as unique_users
  FROM screen_time
  GROUP BY screen_name
),
home_stats AS (
  SELECT * FROM screen_stats WHERE screen_name = 'home'
),
other_screens AS (
  SELECT * FROM screen_stats WHERE screen_name != 'home'
)
SELECT 
  'Home Screen' as screen_type,
  (SELECT total_time_minutes FROM home_stats) as total_time_minutes,
  (SELECT avg_duration_minutes FROM home_stats) as avg_duration_minutes,
  (SELECT total_sessions FROM home_stats) as total_sessions
FROM home_stats

UNION ALL

SELECT 
  'Other Screens Combined' as screen_type,
  SUM(total_time_minutes) as total_time_minutes,
  AVG(avg_duration_minutes) as avg_duration_minutes,
  SUM(total_sessions) as total_sessions
FROM other_screens

UNION ALL

SELECT 
  'Comparison: Home vs Others' as screen_type,
  (SELECT total_time_minutes FROM home_stats) - (SELECT SUM(total_time_minutes) FROM other_screens) as time_difference_minutes,
  (SELECT avg_duration_minutes FROM home_stats) - (SELECT AVG(avg_duration_minutes) FROM other_screens) as avg_duration_difference_minutes,
  0 as total_sessions;

-- =============================================
-- CONSULTA ADICIONAL: Top 5 pantallas por tiempo total
-- =============================================
-- Para complementar el análisis

WITH screen_time AS (
  SELECT 
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'screen_name') as screen_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'screen_category') as screen_category,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'screen_duration_seconds') as duration_seconds
  FROM `your-project.analytics_XXXXXX.events_*`
  WHERE event_name = 'screen_end'
    AND _TABLE_SUFFIX BETWEEN '20241201' AND '20241231'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'screen_duration_seconds') IS NOT NULL
)
SELECT 
  screen_name,
  screen_category,
  ROUND(AVG(duration_seconds)/60, 2) as avg_duration_minutes,
  ROUND(SUM(duration_seconds)/60, 2) as total_time_minutes,
  COUNT(*) as total_sessions,
  COUNT(DISTINCT user_pseudo_id) as unique_users,
  ROUND(SUM(duration_seconds)/60 * 100.0 / SUM(SUM(duration_seconds)/60) OVER(), 2) as percentage_of_total_time
FROM screen_time
GROUP BY screen_name, screen_category
ORDER BY total_time_minutes DESC
LIMIT 5;
