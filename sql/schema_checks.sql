-- Schema and data checks on data/cohort.db
-- Paste into: sqlite3 -header -column data/cohort.db

-- Tables, columns, and keys
.tables
.schema patients
.schema samples
.schema mutations
.schema genes
PRAGMA foreign_key_list(mutations);
PRAGMA foreign_key_list(samples);

-- Does any patient have more than one sample?   566 | 566 (no)
SELECT COUNT(*), COUNT(DISTINCT patient_id) FROM samples;

-- Does any patient have no sample?  0 (no)
SELECT COUNT(*) FROM patients p
LEFT JOIN samples s ON s.patient_id = p.patient_id
WHERE s.sample_id IS NULL;

-- What mutation types exist?  10 types, all coding-region
SELECT DISTINCT variant_classification FROM mutations;

-- How common is each type?  Silent = 45,833 of 200,789 (~23%)
SELECT variant_classification, COUNT(*) AS n
FROM mutations GROUP BY variant_classification ORDER BY n DESC;

-- Any NULL mutation type? expect 0
SELECT COUNT(*) FROM mutations WHERE variant_classification IS NULL;

-- Any mutation with a gene not in genes?  0
SELECT COUNT(*) FROM mutations m
LEFT JOIN genes g ON g.gene_symbol = m.gene_symbol
WHERE g.gene_symbol IS NULL;

-- Any case/whitespace variants in gene_symbol?  2431 (see next query)
SELECT COUNT(*) FROM mutations WHERE gene_symbol != UPPER(TRIM(gene_symbol));

-- What are they?  C1orf177 etc.: real HGNC names, not dirty data
SELECT DISTINCT gene_symbol FROM mutations
WHERE gene_symbol != UPPER(TRIM(gene_symbol))
LIMIT 20;

-- Any leading/trailing whitespace?   0
SELECT COUNT(*) FROM mutations WHERE gene_symbol != TRIM(gene_symbol);

-- Are the five target genes spelled consistently? one spelling each
SELECT gene_symbol, LENGTH(gene_symbol) FROM mutations
WHERE gene_symbol IN ('TP53','KRAS','EGFR','STK11','KEAP1')
GROUP BY gene_symbol;