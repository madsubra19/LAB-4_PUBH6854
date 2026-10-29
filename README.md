# Lab 4 — Database-Driven Feature Table

## Overview
This lab uses SQL Queries against a database to build one row per patient table with 
protein altering mutations for specific genes (TP53, KRAS, EGFR, STK11, KEAP1, and clinical covariates) 
by exploring the schema, building a feature table, handling missing data, and producing a data dictionary. 

## Setup
```bash
mamba env create -f environment.yml
mamba activate week09
```
The environment.yml was exported --from-history, this lists what was installed:
Python 3.12, pandas, pyarrow, and python-duckdb (used here) 
`sqlite3` is part of Python's standard library. 

## Data
Source: cBioPortal luad_tcga_pan_can_atlas_2018 (link:https://www.cbioportal.org/study/summary?id=luad_tcga_pan_can_atlas_2018 )
Data files committed: data/cohort.db 
Data files not committed: cohort_rebuild.db

## Rebuild check (Optional):
All 4 tables were rebuilt from the original download from cBioPortal and 
produced the same counts as the provided table under `data/cohort.db`

| Table | Provided `data/cohort.db` | Rebuilt from raw download |
|---|---|---|
| patients | 566 | 566 |
| samples | 566 | 566 |
| genes | 17,756 | 17,756 |
| mutations | 200,789 | 200,789 |

## Schema
Four tables in this schema: `patients`, `samples`, `mutations`, and 
`genes`, that are connected in a chain patients <-- samples <-- mutations --> genes.
To get from a patient to their mutated genes you go through samples. Clinical Covariates
are split across `patients` (sex, age, stage) and samples (tissue source site, TMB) 
so the feature table joins both.

### Tables and keys
| Table | Grain | Primary key | Foreign keys | Other columns |
|---|---|---|---|---|
| `patients` | one patient | `patient_id` | — | `sex`, `age_at_diagnosis`, `stage`, `vital_status`, `followup_months` |
| `samples` | one sample | `sample_id` | `patient_id` --> `patients` | `tissue_source_site`, `tmb_nonsynonymous`, `aneuploidy_score`, `msi_mantis_score` |
| `mutations` | one variant call | `mutation_id` | `sample_id` -->`samples`, `gene_symbol` --> `genes` | `variant_classification`, `variant_type`, `protein_change`, `chromosome`, `start_pos`, `end_pos`, `t_ref_count`, `t_alt_count` |
| `genes` | one gene | `gene_symbol` | — | `entrez_gene_id`, `chromosome` |


### Grain checks
The Grain checks can be run by 
```bash
sqlite3 -header -column data/cohort.db < sql/grain_checks.sql
```
####  What each  Grain check does and results. 
1. Checks whether any patient appears more than once in `samples`;
the two counts are equal so none does; 566 | 566 

2. Checks if there are any patients with 0 samples. 
The result was 0, so no patient is missing a sample. 

3. Checks if there are samples with more than one mutation. There are 200,789 mutation rows
but only 562 distinct rows in `sample_id`, so many mutations share a sample. The 4 missing samples are the
no mutation samples mentioned in `Missing data` section.

4.Checks if one gene can have many mutations. 200,789 mutation rows but
  only 17,756 distinct rows in `gene_symbol`, which is the size of the `genes` table.
  so every listen gene has at least one mutation call. 

Checks 1 and 2 show that `patients` and `samples` are one-to-one in this database: 
since no patient has more than one sample, and none of the patients have zero samples. 
Check 3 shows `samples` and `mutatuin` table shoe a one to many relationship. Check 4 shows 
`mutations` to `genes` is a many to one relationship. 

### Mutation types and the protein-altering rule
As seen in the mutations table, there are 10 variant_classifications.
They are listed below in the table. Out of all-coding region (200,789 mutation calls), 
about 45,833 are silent mutations. I decided to exclude Silent mutations since
those mutations do not lead to any changes in the proteins. Splice_site mutations 
were included since they don't alter a codon directly, making the mutation more 
similar to a frame shift or nonsense mutation. 

| variant_classification | n |
|---|---|
| Missense_Mutation | 133,460 |
| Silent | 45,833 |
| Nonsense_Mutation | 11,075 |
| Splice_Site | 4,497 |
| Frame_Shift_Del | 3,936 |
| Frame_Shift_Ins | 1,172 |
| In_Frame_Del | 378 |
| Translation_Start_Site | 223 |
| Nonstop_Mutation | 178 |
| In_Frame_Ins | 37 |

### Gene cleanliness
Three checks were done on `mutations.gene_symbol`
1. Make sure every symbol maps to a row in `genes`, results: 0 orphans
2. Look for leading or trailing white space, results: 0 rows differ under `TRIM()`
3. Do each of the 5 target genes appear with exactly one spelling? results: yes. 
###  Running Schema  Checks
This bash command runs checks from above for mutation types and gene cleanliness. 
```bash
sqlite3 -header -column data/cohort.db < sql/schema_checks.sql
```

## SQL Queries
Queries are in `sql/query_a.sql` and `sql/query_b.sql`; the checks that support the numbers below are in `sql/verification.sql`.

Use this bash command below to run the SQL files
```bash
sqlite3 -header -column data/cohort.db < sql/query_a.sql
sqlite3 -header -column data/cohort.db < sql/query_b.sql
sqlite3 -header -column data/cohort.db < sql/verification.sql
```
Below is an explanation of each query file and the corresponding checks 
### Query A:  Protein-altering mutations per patient per gene
For This query, the goal was to get one row for each patient, for each of 
our target genes. Based on this information we expected that we will get 
2,830 rows, since we have 566 patients and 5 target genes, so 566 x 5 = 2,830. 
The query returned as 2,830, matching expectations. The query builds a scaffold
of all 2,830 patient-gene pairs with a `CROSS JOIN` and a `LEFT JOIN` through
`samples` to `mutations`. The gene and silent filters are placed in the ON clause of that LEFT JOIN,
not in WHERE, so pairs with no matching mutation keep theri row with a count of 0 instead of being dropped. 

Check 1 (counting): Query A says TCGA-78-7147 has 3 EGFR mutations. 
Pulling that patient's raw mutations rows directly gives 3, all non-Silent: so the join through samples is not duplicating or dropping rows. 
This patient had no Silent EGFR rows, though, so it doesn't test the filter.

Check 2 (filtering): A look up found TCGA-17-Z023 with a Silent TP53 call.
Its raw rows are one Nonsense and one Silent; Query A reports 1, so the Silent row was excluded 
nd the count is right.

### Query B : Patients per tissue source site per stage
For This Query, the goal was one row per combination of tissue source site and tumor stage that actually occurs, 
with the number of patients in each. With 34 distinct sites and 10 stage groups (9 stage values plus a NULL group), 
the result can have at most 340 rows; the exact count can't be predicted in advance because not every site 
contributed patients at every stage. The actual result is 142 rows. The 54 patients with no recorded stage are kept,
they form their own group within each site rather than being dropped, which is why NULL counts as a tenth stage group and
why `COUNT(DISTINCT patient_id)` summed across all rows still reaches 566.

Check 1: Three bound queries return 34 sites, 9 stage values, and 54 patients with
no stage; 340 is the ceiling

Check 2: This check looks to add up the patient_count across all 142 rows, which should be 566, since every patient
belongs to exactly one site and one stage group. The check shows that it is actually 566, so no patient was dropped or duplicated. 

## Feature table

### How to run
```bash
mamba activate week09
python scripts/build_feature_table.py
```
The `week09` environment is created in the Setup section above (`mamba env create -f environment.yml`); it only needs to be built once. 
If you use conda rather than mamba, the same commands work with `conda` in place of `mamba`

**Input:** `data/cohort.db`
**Output:** `output/feature_table.tsv`

### What the script does
This is how `build_feature_table.py` works. 

1. Runs two SQL queries against `data/cohort.db`: one pulls the clinical columns (one row per patient, `LEFT JOIN` from `patients` to `samples`);
  the other counts protein-altering mutations per patient per target gene, passing the gene list with `?` placeholders rather than pasting it into the SQL string.
2. Reports any samples with no mutation calls at all (a diagnostic; see Missing data).
3. Pivots the mutation counts from long format (patient, gene, count) to wide format, one column per gene.
4. Left-merges the wide counts onto the clinical table so every patient is kept, then fills missing gene counts with 0.
5. Orders the columns, asserts the result has 566 rows and 566 unique patients, and writes `output/feature_table.tsv`.

### Row and patient counts at each step
| Step | Rows | Distinct patients |
|---|---|---|
| clinical | 566 | 566 |
| mutations (long) | 700 | 457 |
| mutations (wide) | 457 | 457 |
| merged | 566 | 566 |

The long table has 457 distinct patients rather than 566 because 109 patients have no protein-altering mutation in any of the five genes, 
so they produce no rows in that query. The left merge in step 4 brings those 109 back with a count of 0 in every gene column, 
which is why the merged table returns to 566.

### How the result was checked
The result was checked three ways.
1. Query A has 700 nonzero rows, matching the 700 rows of the script's long table
2. The two hand-checked patients match: TCGA-17-Z023 `TP53 = 1`, TCGA-78-7147 `EGFR = 3`.
3. Column sums in the TSV equal the SQL per-gene totals: TP53 305, KRAS 172, EGFR 85,
  STK11 81, KEAP1 103.
  
## Missing data
Two kinds of gaps are treated differently. Clinical values that were not recorded (sex, age, stage) are left as NA,
NA in this case means not recorded. Gene count columns use 0: The sample was sequenced and no protein-altering mutation was called in that gene. 
No patient is dropped for having NAs. 

### Clinical columns
| Column | NA count | Note |
|---|---|---|
| `sex` | 52 | all from Washington University |
| `age_at_diagnosis` | 71 | 52 from Washington University + 19 others |
| `stage` | 54 | 52 from Washington University + 2 others |

### Patients with no mutation calls
Four patients (TCGA-64-1678, TCGA-69-8453, TCGA-78-7143, TCGA-86-A4D0) have no
mutation calls at all. I kept their gene counts at 0 because the source reports
TMB = 0.0 rather than missing, i.e. sequenced with nothing called. 

## Data dictionary
`output/data_dictionary.tsv`, generated by `scripts/make_data_dictionary.py`.
The Data Dictionary describes every column of the feature table,
meaning, units, source table and column, and how missing values are coded;
the units for age (years) and TMB (mutations per Mb) are inferred, 
since the cBioPortal headers do not state them. 

## Reproducibility
The two scripts above regenerate every output from data/cohort.db. 
Development was done on the sql-queries and feature-table branches, 
merged into main; git log --graph shows the history.

## AI use
Take a look at `AI_USAGE.md` to see model used and prompts. AI was used for some SQL and Python Scripts generation. 

## Comments for instructor
1. Run order is just the two scripts

