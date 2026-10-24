#!/usr/bin/env python3
"""Writes output/data_dictionary.tsv describing every column of output/feature_table.tsv."""

import pandas as pd

GENE_MEANING = "Count of protein-altering mutations (all variant_classification values except Silent)"
GENE_MISSING = "none; 0 = no mutation called (4 patients have no calls in any gene; see README)"

rows = [
    ["patient_id", "TCGA patient barcode", "-", "patients", "PATIENT_ID", "none"],
    ["sex", "Patient sex", "-", "patients", "SEX", "empty (52 missing)"],
    ["age_at_diagnosis", "Age at which the disease was first diagnosed", "years (inferred; not stated in source header)", "patients", "AGE", "empty (71 missing)"],
    ["stage", "AJCC pathologic tumor stage; mixed granularity (I vs IA/IB) across staging editions; NULL kept as its own group", "-", "patients", "AJCC_PATHOLOGIC_TUMOR_STAGE", "empty (54 missing; 52 from Washington University)"],
    ["tissue_source_site", "Name of the TCGA Tissue Source Site (contributing institution) that collected the sample", "-", "samples", "TISSUE_SOURCE_SITE", "none"],
    ["tmb_nonsynonymous", "Tumor mutation burden, nonsynonymous mutations only", "mutations per Mb (cBioPortal convention; not stated in source header)", "samples", "TMB_NONSYNONYMOUS", "none (0.0 for the 4 no-call patients)"],
]
for gene in ["TP53", "KRAS", "EGFR", "STK11", "KEAP1"]:
    rows.append([gene, GENE_MEANING, "count", "mutations", "GENE_SYMBOL / VARIANT_CLASSIFICATION", GENE_MISSING])

df = pd.DataFrame(rows, columns=["column", "meaning", "units", "source_table", "source_column", "missing_code"])
df.to_csv("output/data_dictionary.tsv", sep="\t", index=False)
print(f"Wrote output/data_dictionary.tsv ({len(df)} rows)")
