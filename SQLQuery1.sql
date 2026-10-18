select *
from [Healthcare Claims].dbo.members;

select member_gender, count(member_id)
from [Healthcare Claims].dbo.members
group by member_gender;
                                                                                                        
select plan_type,count(member_id)
from [Healthcare Claims].dbo.members
group by plan_type;

SELECT COUNT(DISTINCT provider_id) FROM [Healthcare Claims].dbo.claims;

select max(CAST(member_age AS DECIMAL(12,2)))  as max_age,min(CAST(member_age AS DECIMAL(12,2))) as min_age
from [Healthcare Claims].dbo.members ;

--Which claim types are the most expensive?

select * 
from [Healthcare Claims].dbo.claims ;

select claim_type ,sum(CAST(paid_amount AS DECIMAL(12,2))) as total_paid_amount,sum(CAST(billed_amount AS DECIMAL(12,2))) as total_billed_amount,count(CAST(claim_id AS DECIMAL(12,2))) as total_claims
from [Healthcare Claims].dbo.claims
group by claim_type 
order by total_paid_amount desc ;

-- clean CPT and ICD codes

--ALTER TABLE [Healthcare Claims].dbo.claims
--ADD cpt_code_clean VARCHAR(10),
 --   icd_code_clean VARCHAR(10);
--GO
UPDATE [Healthcare Claims].dbo.claims 
SET cpt_code = RIGHT('00000' + LTRIM(RTRIM(cpt_code)), 5)
WHERE LTRIM(RTRIM(cpt_code)) NOT LIKE '%[^0-9]%'   
  AND LEN(LTRIM(RTRIM(cpt_code))) BETWEEN 1 AND 4;
GO

UPDATE [Healthcare Claims].dbo.claims 
SET cpt_code_clean =
    CASE
        WHEN cpt_code IN ('00000','01234','11111','12345','22222','23456','33333',
                          '34567','45678','54321','55555','56789','67890','78901',
                          '89012','98765','99999')
             THEN 'Unknown'
        WHEN cpt_code LIKE '[0-9][0-9][0-9][0-9][0-9]'
          OR cpt_code LIKE '[A-V][0-9][0-9][0-9][0-9]'
          OR cpt_code LIKE '[0-9][0-9][0-9][0-9][FT]'
             THEN cpt_code
        ELSE 'Unknown'
    END;
GO

SELECT COUNT(*) AS cpt_unknown FROM [Healthcare Claims].dbo.claims  WHERE cpt_code_clean = 'Unknown';



-- Which CPT and ICD codes drive the highest spending? before the cleaning
  
select TOP 10 icd_code,sum(CAST(paid_amount AS DECIMAL(12,2))) as total_paid_amount
from [Healthcare Claims].dbo.claims
group by icd_code
order by total_paid_amount desc;

select TOP 10 cpt_code,sum(CAST(paid_amount AS DECIMAL(12,2))) as total_paid_amount,count(CAST(claim_id AS DECIMAL(12,2))) as total_claims
 from [Healthcare Claims].dbo.claims
 group by cpt_code 
 order by total_paid_amount desc ;

 -- Which CPT and ICD codes drive the highest spending? after the cleaning
  
select TOP 10 icd_code_clean,sum(CAST(paid_amount AS DECIMAL(12,2))) as total_paid_amount
from [Healthcare Claims].dbo.claims
group by icd_code_clean
order by total_paid_amount desc;

select TOP 10 cpt_code_clean,sum(CAST(paid_amount AS DECIMAL(12,2))) as total_paid_amount,count(CAST(claim_id AS DECIMAL(12,2))) as total_claims
 from [Healthcare Claims].dbo.claims
 group by cpt_code_clean
 order by total_paid_amount desc ;

-- average_paid_per_claim = total_paid_amount ÷ claim_count
 with cpt as  
 (select TOP 10 cpt_code_clean,sum(CAST(paid_amount AS DECIMAL(12,2))) as total_paid_amount,count(CAST(claim_id AS DECIMAL(12,2))) as total_claims
  from [Healthcare Claims].dbo.claims
  group by cpt_code_clean
  HAVING count(CAST(claim_id AS DECIMAL(12,2))) >= 5 
  order by total_paid_amount desc
    )
  select cpt_code_clean,total_paid_amount ,total_paid_amount /total_claims as average_paid_per_claim
  from cpt 
  order by average_paid_per_claim desc;


-- the difference prices in different providers

 with ret as(
    select cpt_code_clean, claim_type, provider_id,
           sum(CAST(paid_amount AS DECIMAL(12,2))) as total_paid_amount,
           count(CAST(claim_id AS DECIMAL(12,2))) as total_claims
    from [Healthcare Claims].dbo.claims
    where cpt_code_clean <> 'unknown'
    group by provider_id, cpt_code_clean, claim_type
    having count(CAST(claim_id AS DECIMAL(12,2))) >= 2),

ret2 as(
    select *,
           total_paid_amount / total_claims as average_paid_per_claim,
           count(provider_id) over (partition by cpt_code_clean, claim_type) as providers
    from ret)

select *
from ret2
where providers >= 2
order by cpt_code_clean, claim_type

-- Calculate total paid amount per member

select top 10 member_id ,SUM(CAST(paid_amount AS DECIMAL(12,2))) AS total_paid_amount
from [Healthcare Claims].dbo.claims
group by member_id
order by total_paid_amount desc ;

--- for each high-cost member, break down which claim types (inpatient, outpatient, ER, pharmacy) drive their costs

WITH top10 AS (
    SELECT TOP 10
        member_id,
        SUM(CAST(paid_amount AS DECIMAL(12,2))) AS total_paid_amount
    FROM [Healthcare Claims].dbo.claims
    GROUP BY member_id
    ORDER BY total_paid_amount DESC
)
SELECT
    t.member_id,
    c.claim_type,
    SUM(CAST(c.paid_amount AS DECIMAL(12,2))) AS type_paid_amount,
    t.total_paid_amount
FROM top10 AS t
LEFT JOIN [Healthcare Claims].dbo.claims AS c
    ON t.member_id = c.member_id
GROUP BY
    t.member_id,
    t.total_paid_amount,
    c.claim_type
ORDER BY
    t.total_paid_amount DESC,
    type_paid_amount DESC;

 
--5. Billed vs Paid Ratio

SELECT
    ROUND(
        CAST(paid_amount AS DECIMAL(12,2))
        / NULLIF(CAST(billed_amount AS DECIMAL(12,2)), 0) * 100,
        1
    ) AS paid_ratio
FROM [Healthcare Claims].dbo.claims;


-- compare average paid ratios by:claim_type ,provider,CPT code

with paid_ratio as(
SELECT *,
    ROUND(
        CAST(paid_amount AS DECIMAL(12,2))
        / NULLIF(CAST(billed_amount AS DECIMAL(12,2)), 0) * 100,
        1
    ) AS paid_ratio 
FROM [Healthcare Claims].dbo.claims)

select claim_type , avg(paid_ratio) as avg_paid_ratio ,count(*) as total_claims
from paid_ratio
group by claim_type
having count(*) >= 5
order by avg_paid_ratio desc;


with paid_ratio2 as(
SELECT *,
    ROUND(
        CAST(paid_amount AS DECIMAL(12,2))
        / NULLIF(CAST(billed_amount AS DECIMAL(12,2)), 0) * 100,
        1
    ) AS paid_ratio 
FROM [Healthcare Claims].dbo.claims)

select provider_id, avg(paid_ratio) avg_paid_ratio ,count(*) as total_claims
from paid_ratio2
group by provider_id
having count(*) >= 5
order by avg_paid_ratio desc;

with paid_ratio3 as(
SELECT *,
    ROUND(
        CAST(paid_amount AS DECIMAL(12,2))
        / NULLIF(CAST(billed_amount AS DECIMAL(12,2)), 0) * 100,
        1
    ) AS paid_ratio 
FROM [Healthcare Claims].dbo.claims)

select cpt_code_clean, avg(paid_ratio) avg_paid_ratio ,count(*) as total_claims
from paid_ratio3
group by cpt_code_clean
having count(*) >= 5
order by avg_paid_ratio desc;
