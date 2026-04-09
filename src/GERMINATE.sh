GERMINATE.sh

#!/bin/bash
mkdir -p "$OUTDIR"
SEED_DIR="seeds"
DB="refseq/bacteria_proteins.faa"
OUTDIR="result"
THREADS=${1:-4}

process_gene () {
    GENE=$1
    SEEDFILE="${SEED_DIR}/${GENE}_seeds.faa"
    
    echo "====================================="
    echo " Welcome to the GERMINATE Pipeline :)"
    echo " v.001"
    echo " PROCESSING GENE: $GENE"
    echo "====================================="

    if [[ ! -f $SEEDFILE ]]; then
        echo "Seed file $SEEDFILE not found, skipping."
        return
    fi

    #  1. MULTIPLE SEQUENCE ALIGNMENT 
    echo "Running Clustal Omega..."
    clustalo -i "$SEEDFILE" -o "${OUTDIR}/${GENE}_aligned.faa" --force

    #  2. BUILD HMM 
    echo "Building HMM with hmmbuild..."
    hmmbuild "${OUTDIR}/${GENE}.hmm" "${OUTDIR}/${GENE}_aligned.faa"

    #  3. HMMSEARCH 
    echo "Running hmmsearch against RefSeq DB..."
    hmmsearch --cpu $THREADS \
          -E 1e-100 \
          --tblout "${OUTDIR}/${GENE}.tbl" \
          "${OUTDIR}/${GENE}.hmm" "$DB" \
          > "${OUTDIR}/${GENE}.out"

    #  4. FILTER HITS 
    SCORE_CUTOFF=1e-100
    echo "Filtering hits with e-value >= $SCORE_CUTOFF..."
    awk '{ if ($5 + 0 <= 1e-100) print $1 }'  \
        "${OUTDIR}/${GENE}.tbl" > "${OUTDIR}/${GENE}_hits.list"

    #  5. EXTRACT MATCHING FASTA SEQUENCES 
    echo "Extracting FASTA for hits..."
    seqkit grep -f "${OUTDIR}/${GENE}_hits.list" "$DB" > "${OUTDIR}/${GENE}_hits.faa"


    #  6. REMOVE REDUNDANCY WITH CD-HIT 
    echo "Running CD-HIT..."
    cd-hit -i "${OUTDIR}/${GENE}_hits.faa" \
           -o "${OUTDIR}/${GENE}_nr.faa" \
           -c 0.95 -n 5 -M 16000 -T $THREADS

    echo "    → Output: ${OUTDIR}/${GENE}_nr.faa"
    echo "Done with $GENE!"
}


echo "=== Starting gene catalog pipeline ==="

for file in ${SEED_DIR}/*_seeds.faa; do
    gene=$(basename "$file" _seeds.faa)
    process_gene "$gene"
done

echo "=== Pipeline finished! ==="
