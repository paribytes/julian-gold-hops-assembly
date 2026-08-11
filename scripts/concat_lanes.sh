#!/bin/bash

# Concatenate lane-split fastqs into one R1/R2 pair per sample.
# Reads raw lanes from the shared folder, writes merged output into your own working directory.

set -euo pipefail

RAW_BASE_DIR=/usr/scratchF/shared/JULIAN-GOLD
WORK_DIR=/home/priyanshi/julian_gold_assembly
OUT_DIR=${WORK_DIR}/merged_reads
mkdir -p "$OUT_DIR"

for sample in JG2 JG3; do
    echo "Merging lanes for $sample ..."

    SAMPLE_DIR=${RAW_BASE_DIR}/${sample}

    R1_FILES=$(ls ${SAMPLE_DIR}/${sample}_*_R1.fastq.gz | sort)
    R2_FILES=$(ls ${SAMPLE_DIR}/${sample}_*_R2.fastq.gz | sort)

    echo "  R1 lanes: $R1_FILES"
    echo "  R2 lanes: $R2_FILES"

    # Concatenating gzip files directly
    cat $R1_FILES > ${OUT_DIR}/${sample}_R1.fastq.gz
    cat $R2_FILES > ${OUT_DIR}/${sample}_R2.fastq.gz

    # Sanity check to see if read counts match between R1 and R2
    r1_count=$(zcat ${OUT_DIR}/${sample}_R1.fastq.gz | wc -l)
    r2_count=$(zcat ${OUT_DIR}/${sample}_R2.fastq.gz | wc -l)
    echo "  $sample: R1 lines=$r1_count  R2 lines=$r2_count"
    if [ "$r1_count" != "$r2_count" ]; then
        echo "  WARNING: R1/R2 line counts differ for $sample - check your lane files!"
    fi
done

echo "Done. Merged files are in $OUT_DIR/"
