# Lab 4 AI Usage
Model used: Claude
AI was utilized for some SQL and python script generation

# Prompts  used

1. Prompt: "Based on these details, can you generate a SQLite script counts protein altering mutations for each patient.
there are 5 target genes:  (TP53, KRAS, EGFR, STK11, and KEAP1) and four tables (`patients`, `samples`, `mutations`, and 
`genes` ). 

This was the SQL code I initially got: 
```sql
WITH target_genes AS (
    SELECT 'TP53' AS gene_symbol
    UNION ALL SELECT 'KRAS'
    UNION ALL SELECT 'EGFR'
    UNION ALL SELECT 'STK11'
    UNION ALL SELECT 'KEAP1'
),
altering_classes AS (
    SELECT 'Missense_Mutation' AS variant_classification
    UNION ALL SELECT 'Nonsense_Mutation'
    UNION ALL SELECT 'Nonstop_Mutation'
    UNION ALL SELECT 'Frame_Shift_Del'
    UNION ALL SELECT 'Frame_Shift_Ins'
    UNION ALL SELECT 'In_Frame_Del'
    UNION ALL SELECT 'In_Frame_Ins'
    UNION ALL SELECT 'Splice_Site'
    UNION ALL SELECT 'Translation_Start_Site'
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
   AND m.variant_classification IN (SELECT variant_classification FROM altering_classes)
GROUP BY grid.patient_id, grid.gene_symbol
ORDER BY grid.patient_id, grid.gene_symbol;
```
But in my code I removed `altering_classes` and instead added 'm.variant_classification != `Silent` 
then checked by running to see if I got 2,830 rows.

2. Prompt: "Based on these details help write a python script that builds a feature table.
there are 5 target genes:  (TP53, KRAS, EGFR, STK11, and KEAP1) and four tables (`patients`, `samples`, `mutations`, and 
`genes` ). The schema for the table can be found here in this word doc (I uploaded a word doc with more details about each table)" 

```python
"""
scripts/build_feature_table.py
Builds a wide feature table joining clinical metadata and 
protein-altering mutation counts for TP53, KRAS, EGFR, STK11, and KEAP1.
"""

import os
import sqlite3
import pandas as pd


def main():
    db_path = "data/cohort.db"
    output_path = "output/feature_table.tsv"

    os.makedirs("output", exist_ok=True)
    conn = sqlite3.connect(db_path)

    # 1. Fetch clinical data (1 row per patient, verified 1:1 with samples)
    clinical_sql = """
    SELECT 
        p.patient_id,
        p.sex,
        p.age_at_diagnosis,
        p.stage,
        s.tissue_source_site,
        s.tmb_nonsynonymous
    FROM patients p
    LEFT JOIN samples s ON p.patient_id = s.patient_id;
    """
    df_clinical = pd.read_sql_query(clinical_sql, conn)

    # 2. Fetch mutation counts for target genes (excluding Silent)
    target_genes = ["TP53", "KRAS", "EGFR", "STK11", "KEAP1"]
    genes_placeholder = ",".join(f"'{g}'" for g in target_genes)

    mutations_sql = f"""
    SELECT 
        s.patient_id,
        m.gene_symbol,
        COUNT(m.mutation_id) AS mutation_count
    FROM samples s
    JOIN mutations m ON s.sample_id = m.sample_id
    WHERE m.gene_symbol IN ({genes_placeholder})
      AND m.variant_classification != 'Silent'
    GROUP BY s.patient_id, m.gene_symbol;
    """
    df_mutations = pd.read_sql_query(mutations_sql, conn)
    conn.close()

    # 3. Reshape mutations from long to wide
    df_wide_mut = df_mutations.pivot(
        index="patient_id", columns="gene_symbol", values="mutation_count"
    ).reset_index()

    # Ensure all 5 target gene columns exist
    for gene in target_genes:
        if gene not in df_wide_mut.columns:
            df_wide_mut[gene] = 0

    # 4. Join clinical data with wide mutation counts
    df_feature = pd.merge(df_clinical, df_wide_mut, on="patient_id", how="left")

    # 5. Handle missing data explicitly:
    # - Gene mutation counts: Fill missing (NaN) with 0 for sequenced patients with no mutation in that gene.
    # - Clinical features (sex, age_at_diagnosis, stage): Retain NaN/None to represent unrecorded clinical data.
    df_feature[target_genes] = df_feature[target_genes].fillna(0).astype(int)

    # 6. Quality Assertions
    assert len(df_feature) == 566, f"Expected 566 rows, got {len(df_feature)}"
    assert (
        df_feature["patient_id"].nunique() == 566
    ), "Duplicate patient_ids found!"

    # 7. Write to TSV
    df_feature.to_csv(output_path, sep="\t", index=False)
    print(
        f"Successfully generated {output_path} with shape {df_feature.shape}"
    )


if __name__ == "__main__":
    main()
```

I tested this code and mostly got the results I wanted but wanted to change the order of columns by
so target_genes came out like this: TP53, KRAS, EGFR, STK11, KEAP. Then added some steps to 
check for NA values, a no mutation calls query, and printing progress at each step. 






