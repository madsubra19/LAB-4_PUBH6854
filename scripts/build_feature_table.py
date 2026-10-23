#!/usr/bin/env python3
"""Builds a 566-row wide feature table joining clinical metadata and target gene mutation counts."""

import os
import sqlite3
import pandas as pd


def main():
    db_path = "data/cohort.db"
    output_path = "output/feature_table.tsv"

    os.makedirs("output", exist_ok=True)
    conn = sqlite3.connect(db_path)

    # 1. Fetch clinical data
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
    print(
        f"clinical: {len(df_clinical)} rows, {df_clinical['patient_id'].nunique()} patients"
    )

    # 2. Fetch protein-altering mutation counts for target genes
    target_genes = ["TP53", "KRAS", "EGFR", "STK11", "KEAP1"]
    placeholders = ",".join("?" for _ in target_genes)

    mutations_sql = f"""
    SELECT
        s.patient_id,
        m.gene_symbol,
        COUNT(m.mutation_id) AS mutation_count
    FROM samples s
    JOIN mutations m ON s.sample_id = m.sample_id
    WHERE m.gene_symbol IN ({placeholders})
      AND m.variant_classification != 'Silent'
    GROUP BY s.patient_id, m.gene_symbol;
    """
    df_mutations = pd.read_sql_query(mutations_sql, conn, params=target_genes)
    print(
        f"mutations (long): {len(df_mutations)} rows, {df_mutations['patient_id'].nunique()} patients"
    )

    # 3. Report patients with no mutation calls at all (diagnostic)
    no_calls_sql = """
    SELECT s.patient_id
    FROM samples s
    LEFT JOIN mutations m ON m.sample_id = s.sample_id
    WHERE m.mutation_id IS NULL;
    """
    no_calls = pd.read_sql_query(no_calls_sql, conn)["patient_id"].tolist()
    print(f"samples with no mutation calls: {len(no_calls)} -> {no_calls}")

    conn.close()

    # 4. Reshape mutation counts from long to wide format
    df_wide_mut = df_mutations.pivot(
        index="patient_id", columns="gene_symbol", values="mutation_count"
    ).reset_index()
    df_wide_mut.columns.name = None
    print(f"mutations (wide): {len(df_wide_mut)} rows")

    # Ensure all target gene columns exist
    for gene in target_genes:
        if gene not in df_wide_mut.columns:
            df_wide_mut[gene] = 0

    # 5. Merge clinical data with mutation counts
    df_feature = pd.merge(df_clinical, df_wide_mut, on="patient_id", how="left")
    print(
        f"merged: {len(df_feature)} rows, {df_feature['patient_id'].nunique()} patients"
    )

    # 6. Fill missing counts with 0: a sequenced patient with no call in a gene has no mutation there.
    #    This also applies to the no-call patients printed in step 3
    df_feature[target_genes] = df_feature[target_genes].fillna(0).astype("Int64")

    # 7. Order columns: identifiers, clinical features, target genes
    cols = [
        "patient_id",
        "sex",
        "age_at_diagnosis",
        "stage",
        "tissue_source_site",
        "tmb_nonsynonymous",
    ] + target_genes
    df_feature = df_feature[cols]

    # 8. Integrity assertions
    assert len(df_feature) == 566, f"Expected 566 rows, got {len(df_feature)}"
    assert (
        df_feature["patient_id"].nunique() == 566
    ), "Duplicate patient_ids found!"

    # 9. Output TSV file
    df_feature.to_csv(output_path, sep="\t", index=False)
    print(
        f"Successfully generated {output_path} with shape {df_feature.shape}"
    )


if __name__ == "__main__":
    main()
