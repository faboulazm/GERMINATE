# GERMINATE 🌱

A bash pipeline for building Hidden Markov Model (HMM) profiles from non-redundant protein seed sequences scrabed by SEEDscraper, searching them against a protein database, and producing non-redundant gene catalog automated across multiple genes.
---

## Overview

GERMINATE takes seed sequences for one or more genes of interest, builds a HMM profile after multiple sequence alignment, searches that profile against a reference protein database (e.g. RefSeq), filters hits by E-value, and removes redundancies. Output provides a non-redundant FASTA file for each gene of interest to map against metagenomic contigs. 

```
SEEDscraper
        ↓
Seed sequences (.faa)
        ↓
Multiple Sequence Alignment (Clustal Omega)
        ↓
HMM Profile Construction (hmmbuild)
        ↓
Database Search (hmmsearch)
        ↓
Hit Extraction (seqkit)
        ↓
Redundancy Removal (CD-HIT)
        ↓
Non-redundant gene catalog (.faa)
```

---

## Dependencies

| Tool | Version tested | Purpose |
|---|---|---|
| [Clustal Omega](http://www.clustal.org/omega/) | ≥ 1.2.4 | Multiple sequence alignment of seed sequences |
| [HMMER](http://hmmer.org/) | ≥ 3.3 | HMM profile construction and database search |
| [seqkit](https://bioinf.shenwei.me/seqkit/) | ≥ 2.0 | FASTA sequence extraction by ID |
| [CD-HIT](https://sites.google.com/view/cd-hit) | ≥ 4.8.1 | Redundancy removal at 95% identity |

### Installation via conda (recommended)

```bash
conda create -n germinate -c bioconda clustalo hmmer seqkit cd-hit
conda activate germinate
```

---

## Usage

### 1. Prepare your inputs

**Seed sequences** — Place one FASTA file per gene in the `seeds/` directory. 

Seeds must have same naming convention: 
```
seeds/{gene_name}_seeds.faa
```

Each seed file should contain a small set of curated, representative protein sequences for that gene (5+ sequences). SEEDscraper can be used to automate extraction of reviewed sequences to your desktop.

**Reference database**: Provide a protein database in FASTA format (e.g. RefSeq bacterial proteins):

```
refseq/
└── bacteria_proteins.faa
```

### 2. Configure the pipeline

Open `run_pipeline.sh` and edit the top-level variables to match your setup:

```bash
SEED_DIR="seeds"                        # Directory containing seed .faa files
DB="refseq/bacteria_proteins.faa"       # Path to reference protein database
OUTDIR="results"                        # Output directory (created automatically)
THREADS=4                               # CPU threads (or pass as argument: bash run_pipeline.sh 8)
```

### 3. Run

```bash
bash run_pipeline.sh
```

Or specify thread count directly:

```bash
bash run_pipeline.sh 8
```

---

## Output

For each gene, the following files are generated in `results/`:

| File | Description |
|---|---|
| `{gene}_aligned.faa` | Multiple sequence alignment of seed sequences |
| `{gene}.hmm` | HMM profile built from the alignment |
| `{gene}.tbl` | Full hmmsearch tabular output |
| `{gene}.out` | Full hmmsearch standard output |
| `{gene}_hits.list` | Filtered list of hit accessions |
| `{gene}_hits.faa` | FASTA sequences of all hits |
| `{gene}_nr.faa` | **Final output:** non-redundant hits at 95% identity |

---

## Parameters

| Parameter | Default | Description |
|---|---|---|
| E-value cutoff | `1e-100` | Stringent threshold for hmmsearch hits; adjust in script for less conserved genes |
| CD-HIT identity | `0.95` | Sequence identity threshold for redundancy removal |
| CD-HIT word size | `5` | Word size for CD-HIT clustering (5 recommended for ≥ 0.7 identity) |
| Memory (CD-HIT) | `16000 MB` | Adjust based on available RAM |

> **Note on E-value stringency:** The default cutoff of `1e-100` is intentionally strict, designed for highly conserved gene families (e.g. SCFA biosynthesis genes). 
---

## Example

A small example dataset is provided in `seeds/example/` to verify your installation:

```bash
# Test with example data
SEED_DIR="seeds/example" bash run_pipeline.sh
```

Expected output is in `results/example_expected/` for comparison.

---

## Citation

If you use GERMINATE in your research, please cite the underlying tools:

- **Clustal Omega:** Sievers F. et al. (2011) *Mol Syst Biol* 7:539
- **HMMER:** Eddy SR. (2011) *PLoS Comput Biol* 7(10):e1002195
- **seqkit:** Shen W. et al. (2016) *PLoS ONE* 11(10):e0163962
- **CD-HIT:** Li W. & Godzik A. (2006) *Bioinformatics* 22(13):1658–9

---

## Author

**Fatima A. Aboulalazm**
PhD Candidate, Microbiology & Immunology — Medical College of Wisconsin
[LinkedIn](https://www.linkedin.com/in/fatima-aboulalazm/) · [GitHub](https://github.com/faboulazm)

---

## License

MIT License — free to use, modify, and distribute with attribution.
