--Counting protein altering mutations for each patient 
--and for 5 genes (TP53, KRAS, EGFR, STK11, and KEAP1)
--Query A
WITH target_genes AS (
    SELECT 'TP53' AS gene_symbol
    UNION ALL SELECT 'KRAS'
    UNION ALL SELECT 'EGFR'
    UNION ALL SELECT 'STK11'
    UNION ALL SELECT 'KEAP1'
),
patient_gene_grid AS (
    SELECT p.patient_id, g.gene_symbol
    FROM patients p
    CROSS JOIN target_genes g
)
SELECT 
    grid.patient_id,
    grid.gene_symbol,
    COUNT(m.mutation_id) AS mutation_count
FROM patient_gene_grid grid
LEFT JOIN samples s 
    ON grid.patient_id = s.patient_id
LEFT JOIN mutations m 
    ON s.sample_id = m.sample_id 
   AND grid.gene_symbol = m.gene_symbol 
   AND m.variant_classification != 'Silent'
GROUP BY grid.patient_id, grid.gene_symbol
ORDER BY grid.patient_id, grid.gene_symbol;

--Expected Row Count: 2,830 rows (566 patients times 5 target genes)
-- Actual: 2,830

