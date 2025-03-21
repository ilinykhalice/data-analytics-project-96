--создаю доп таблицу с платными кликами
WITH paid_clicks AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id,
        l.created_at AS lead_created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        --нумерация визитов каждого лида
        ROW_NUMBER() OVER (
            PARTITION BY l.lead_id
            ORDER BY s.visit_date DESC
        ) AS row_number
    FROM
        sessions AS s
    --присоединяю таблицу с лидами
    LEFT JOIN
        leads AS l
        ON
            s.visitor_id = l.visitor_id
            AND s.visit_date <= l.created_at
    --фильтрация по нужным каналам
    WHERE
        s.medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
)
SELECT
    visitor_id,
    visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    lead_id,
    lead_created_at,
    amount,
    closing_reason,
    status_id
FROM
    paid_clicks
WHERE
    row_number = 1
ORDER BY
    amount DESC NULLS LAST,
    visit_date ASC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC;

select *
from leads