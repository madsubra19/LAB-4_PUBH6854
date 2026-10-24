-- Verification checks for query_a.sql and query_b.sql
-- Run: sqlite3 -header -column data/cohort.db < sql/verification.sql
-- Row counts were taken with:  sqlite3 data/cohort.db < sql/query_X.sql | wc -l

-- Query A (protein-altering mutations per patient per gene)

-- Expected rows: 566 patients x 5 genes = 2830.  Actual (wc -l): 2830

-- Hand-check 1, counting: TCGA-78-7147 / EGFR.  Query A says 3
-- Result: 3 rows, all non-Silent. Matches.
SELECT m.variant_classification, m.protein_change
FROM mutations m
JOIN samples s ON s.sample_id = m.sample_id
WHERE s.patient_id = 'TCGA-78-7147' AND m.gene_symbol = 'EGFR';

-- Find a patient with a Silent call in a target gene (to test the filter)
-- Result: TCGA-17-Z023 / TP53
SELECT s.patient_id, m.gene_symbol, m.variant_classification
FROM mutations m
JOIN samples s ON s.sample_id = m.sample_id
WHERE m.gene_symbol IN ('TP53','KRAS','EGFR','STK11','KEAP1')
  AND m.variant_classification = 'Silent'
LIMIT 5;

-- Hand-check 2, filtering: TCGA-17-Z023 / TP53.  Query A says 1
-- Result: 2 rows, Nonsense_Mutation and Silent. Silent excluded, count matches.
SELECT m.variant_classification
FROM mutations m
JOIN samples s ON s.sample_id = m.sample_id
WHERE s.patient_id = 'TCGA-17-Z023' AND m.gene_symbol = 'TP53';

-- Query B (patients per tissue source site per stage)

-- Upper bound on rows: sites x stages (+1 for the NULL stage group)
-- Result: 34 sites, 9 stages, 54 patients with NULL stage. Max 34 x 10 = 340
-- Actual (wc -l): 142
SELECT COUNT(DISTINCT tissue_source_site) FROM samples;
SELECT COUNT(DISTINCT stage) FROM patients;
SELECT COUNT(*) FROM patients WHERE stage IS NULL;

-- Every patient counted exactly once across all site x stage groups
-- Result: 566
SELECT SUM(patient_count) FROM (
    SELECT s.tissue_source_site, p.stage,
           COUNT(DISTINCT p.patient_id) AS patient_count
    FROM patients p
    LEFT JOIN samples s ON p.patient_id = s.patient_id
    GROUP BY s.tissue_source_site, p.stage
);