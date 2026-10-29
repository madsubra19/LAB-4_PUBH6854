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

--Expected Rows: It will be equal to the Number of sites X Number of stages if every site has a stage
-- Based on counts there are 34 distinct sites and 10 distinct stage (34 x 10 = 340), so 340 rows are expected

