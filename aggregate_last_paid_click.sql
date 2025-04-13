 -- создаю доп таблицу с платными кликами
with last_paid_clicks AS (
    SELECT 
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        -- нумерация визитов каждого лида
        ROW_NUMBER() OVER (
            PARTITION BY s.visitor_id 
            ORDER BY 
                CASE WHEN s.medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social') THEN 0 ELSE 1 END,
                s.visit_date DESC
        ) AS row_number
    FROM sessions s
    -- фильтрация по нужным каналам
    WHERE s.medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social') 
),
ad_costs AS (
    -- объединяю затраты из VK и Яндекс
    SELECT
        campaign_date AS visit_date, -- объединяю названия для упрощения объединения таблиц в будущем
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent AS cost
    FROM vk_ads
    WHERE utm_medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    
    UNION ALL
    
    SELECT
        campaign_date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent AS cost
    FROM ya_ads
    WHERE utm_medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),
-- агрегирую данные по визитам
visit_stats AS (
    SELECT
        DATE(lpc.visit_date) AS visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        COUNT(DISTINCT s.visitor_id) AS visitors_count,
        SUM(ac.cost) AS total_cost
    FROM last_paid_clicks lpc
    INNER JOIN sessions s ON lpc.visitor_id = s.visitor_id
    LEFT JOIN ad_costs ac ON 
        DATE(lpc.visit_date) = DATE(ac.visit_date) AND
        lpc.utm_source = ac.utm_source AND
        lpc.utm_medium = ac.utm_medium AND
        lpc.utm_campaign = ac.utm_campaign
    WHERE lpc.row_number = 1 -- только последний платный клик
    GROUP BY 
        DATE(lpc.visit_date),
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign
),
-- агрегирую данные по лидам
lead_stats AS (
    SELECT
        DATE(lpc.visit_date) AS visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        COUNT(DISTINCT l.lead_id) AS leads_count,
        COUNT(DISTINCT CASE 
            WHEN l.closing_reason = 'Успешно реализовано' OR l.status_id = 142 
            THEN l.lead_id 
        END) AS purchases_count,
        SUM(CASE 
            WHEN l.closing_reason = 'Успешно реализовано' OR l.status_id = 142 
            THEN l.amount 
            ELSE 0 
        END) AS revenue
    FROM last_paid_clicks lpc
    INNER JOIN leads l ON lpc.visitor_id = l.visitor_id
    WHERE lpc.row_number = 1 -- только последний платный клик
    GROUP BY 
        DATE(lpc.visit_date),
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign
)
-- финальный запрос для витрины данных
SELECT
    vs.visit_date,
    vs.utm_source,
    vs.utm_medium,
    vs.utm_campaign,
    vs.visitors_count,
    vs.total_cost,
    COALESCE(ls.leads_count, 0) AS leads_count,
    COALESCE(ls.purchases_count, 0) AS purchases_count,
    ls.revenue
FROM visit_stats vs
LEFT JOIN lead_stats ls ON 
    vs.visit_date = ls.visit_date AND
    vs.utm_source = ls.utm_source AND
    vs.utm_medium = ls.utm_medium AND
    vs.utm_campaign = ls.utm_campaign
ORDER BY
    ls.revenue DESC NULLS LAST,
    vs.visit_date ASC,
    vs.visitors_count DESC,
    vs.utm_source ASC,
    vs.utm_medium ASC,
    vs.utm_campaign ASC
LIMIT 15;