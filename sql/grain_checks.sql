-- Grain checks
-- Does any patient have more than one sample?   566 | 566 
SELECT COUNT(*), COUNT(DISTINCT patient_id) FROM samples;

-- Does any patient have no sample?  0 
SELECT COUNT(*) FROM patients p
LEFT JOIN samples s ON s.patient_id = p.patient_id
WHERE s.sample_id IS NULL;

-- Does one sample have more than one mutation? 200789 | 562
SELECT COUNT(*), COUNT(DISTINCT sample_id) FROM mutations; 

-- Does many mutations have the same gene? 200789 | 17756   
SELECT COUNT(*), COUNT(DISTINCT gene_symbol) FROM mutations;
