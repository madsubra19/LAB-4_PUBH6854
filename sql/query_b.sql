-- count patients per tissue source per tumor stage 
-- Query B
SELECT 
s.tissue_source_Site,
p.stage,
COUNT(DISTINCT p.patient_id) AS patient_count
FROM patients p
LEFT JOIN samples s ON p.patient_id = s.patient_id
GROUP BY s.tissue_source_site, p.stage
ORDER BY s.tissue_source_site, p.stage; 

