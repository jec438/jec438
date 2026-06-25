-- Winning account_id per businesslegalname for the Zendesk external_id reconciliation.
-- Keep this in lockstep with the Hightouch model (hightouch): the winner ranking is
--   status (today)  ->  most recent coverage end (desc)  ->  account_id (deterministic).
-- Output columns: businesslegalname, account_id.
WITH
  accounts_with_coverage AS (
    SELECT customer_id AS account_entity_id,
           MAX(end_date_coverage_exclusive) AS last_coverage_end
    FROM `production-storage-b567.policy_public.vehicle_coverage`
    WHERE COALESCE(is_archived, FALSE) = FALSE AND _fivetran_deleted = FALSE
      AND effective_date_inclusive IS NOT NULL AND end_date_coverage_exclusive IS NOT NULL
    GROUP BY customer_id
  ),
  cleaned AS (
    SELECT DISTINCT
      REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(INITCAP(a.businesslegalname),' Llc',' LLC'),' Llp',' LLP'),' Dba',' DBA'),' Usa',' USA'),'(Llc)','(LLC)') AS businesslegalname,
      REGEXP_REPLACE(a.contactemail, r'\+[^@]*', '') AS contactemail,
      a.account_id, a.status, awc.last_coverage_end
    FROM `production-storage-b567.scheduled_queries.accounts_latest` a
    LEFT JOIN accounts_with_coverage awc ON a.account_id = awc.account_entity_id
    WHERE a.demo IS FALSE
  ),
  valid_emails AS (SELECT * FROM cleaned WHERE REGEXP_CONTAINS(contactemail, r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$')),
  ranked_by_name AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY businesslegalname ORDER BY
      CASE WHEN status='Active' THEN 0 WHEN status='Pending Activation' THEN 1 WHEN status='Onboarding' THEN 2 ELSE 3 END,
      last_coverage_end DESC NULLS LAST, account_id) AS rn
    FROM valid_emails),
  ranked_by_email AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY contactemail ORDER BY
      CASE WHEN status='Active' THEN 0 WHEN status='Pending Activation' THEN 1 WHEN status='Onboarding' THEN 2 ELSE 3 END,
      last_coverage_end DESC NULLS LAST, account_id) AS rn_email
    FROM ranked_by_name WHERE rn = 1)
SELECT businesslegalname, account_id FROM ranked_by_email WHERE rn_email = 1
