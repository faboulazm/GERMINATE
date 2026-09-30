#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "ERROR: pipeline failed at line %s. Outputs may be incomplete.\n" "$LINENO" >&2' ERR

SEED_DIR=${SEED_DIR:-seeds}
DB=${DB:-refseq/bacteria_proteins.faa}
OUTDIR=${OUTDIR:-results}
THREADS=${1:-${THREADS:-4}}
EVALUE=${EVALUE:-1e-100}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $# -le 1 ]] || die 'Usage: bash src/GERMINATE.sh [threads]'
[[ $THREADS =~ ^[1-9][0-9]*$ ]] || die 'Threads must be a positive integer.'
[[ $EVALUE =~ ^[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?$ ]] || die 'EVALUE must be a positive number.'
awk -v value="$EVALUE" 'BEGIN { exit !(value + 0 > 0) }' || die 'EVALUE must be greater than zero.'
[[ -d $SEED_DIR ]] || die "Seed directory not found: $SEED_DIR"
[[ -s $DB && -r $DB ]] || die "Database is missing, empty, or unreadable: $DB"
shopt -s nullglob
seed_files=("$SEED_DIR"/*_seeds.faa)
[[ ${#seed_files[@]} -gt 0 ]] || die "No *_seeds.faa files found in $SEED_DIR"
for seed in "${seed_files[@]}"; do
    [[ -s $seed && -r $seed ]] || die "Seed file is empty or unreadable: $seed"
done
for tool in clustalo hmmbuild hmmsearch seqkit cd-hit; do
    command -v "$tool" >/dev/null 2>&1 || die "Required tool not found: $tool"
done
mkdir -p "$OUTDIR"

process_gene() {
    local seedfile=$1 gene prefix
    gene=$(basename "$seedfile" _seeds.faa)
    [[ -n $gene ]] || die 'Seed filename must include a gene name before _seeds.faa.'
    prefix="${OUTDIR}/${gene}"
    # Refuse to mix an earlier run's products with this run.
    local existing=("${prefix}.hmm" "${prefix}.tbl" "${prefix}.out" "${prefix}"_*.faa "${prefix}"_hits.list "${prefix}"_nr.faa.clstr)
    local path
    for path in "${existing[@]}"; do
        [[ ! -e $path ]] || die "Output already exists: $path. Choose a fresh OUTDIR."
    done
    printf '\n=== Processing gene: %s ===\n' "$gene"
    echo 'Running Clustal Omega...'
    clustalo -i "$seedfile" -o "${prefix}_aligned.faa" --threads="$THREADS"
    echo 'Building HMM...'
    hmmbuild "${prefix}.hmm" "${prefix}_aligned.faa"
    echo 'Searching protein database...'
    hmmsearch --cpu "$THREADS" -E "$EVALUE" --tblout "${prefix}.tbl" \
        "${prefix}.hmm" "$DB" > "${prefix}.out"
    printf 'Filtering hits with E-value <= %s...\n' "$EVALUE"
    awk -v cutoff="$EVALUE" '!/^#/ && NF >= 5 && $5 ~ /^[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?$/ && $5 + 0 <= cutoff + 0 { print $1 }' \
        "${prefix}.tbl" > "${prefix}_hits.list"
    if [[ ! -s ${prefix}_hits.list ]]; then
        : > "${prefix}_hits.faa"
        : > "${prefix}_nr.faa"
        : > "${prefix}_nr.faa.clstr"
        echo "No hits passed the cutoff for $gene; wrote empty FASTA and cluster files."
        return
    fi
    echo 'Extracting matching sequences...'
    seqkit grep -f "${prefix}_hits.list" "$DB" > "${prefix}_hits.faa"
    [[ -s ${prefix}_hits.faa ]] || die "No sequences extracted for $gene despite reported hits. Check database IDs."
    echo 'Removing redundancy at 95% identity...'
    cd-hit -i "${prefix}_hits.faa" -o "${prefix}_nr.faa" -c 0.95 -n 5 -M 16000 -T "$THREADS"
    [[ -s ${prefix}_nr.faa ]] || die "CD-HIT produced no sequences for $gene."
    printf 'Done with %s. Output: %s_nr.faa\n' "$gene" "$prefix"
}

echo '=== Starting GERMINATE ==='
for seed in "${seed_files[@]}"; do
    process_gene "$seed"
done
echo '=== Pipeline finished successfully! ==='
