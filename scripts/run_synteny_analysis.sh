#!/bin/bash

# Synteny analysis: JG3 scaffolded assembly vs. H. lupulus reference genome (Humulus_lupulus_lupulus_21110M_HAP2_v1.0.fa)
# Run interactively or adapt into a PBS job (see run_synteny_minimap2.pbs for the standalone alignment-only PBS version).
#
# Steps:
#   1. Filter assembly to chromosome-scale placed scaffolds only
#   2. Align against reference with minimap2 (--no-long-join for accurate per-alignment identity - see README.md)
#   3. Filter alignments by mapping quality and length
#   4. Generate dot plot with dotPlotly

set -euo pipefail

BASE_DIR=/usr/scratch/priyanshi/julian_gold_assembly/JG3_ragtag/scaffold
REFERENCE=/sdm/scratch/priyanshi/RefHopsGenomeHudAl/Humulus_lupulus_lupulus_21110M_HAP2_v1.0.fa
cd $BASE_DIR

# Step 1: filter to placed scaffolds (Chr01-09, ChrX) 
mamba activate seqkit_env

seqkit grep -r -p "^Chr" ragtag.scaffold.fasta > ragtag.scaffold.placed_only.fasta

# Step 2: align with minimap2
mamba activate ragtag

minimap2 -x asm5 -t 16 --no-long-join \
    $REFERENCE \
    ragtag.scaffold.placed_only.fasta \
    > JG3_vs_ref_nolongjoin.paf

# Step 3: filter by mapping quality and length
awk '$12 >= 30' JG3_vs_ref_nolongjoin.paf > JG3_vs_ref_filtered.paf

# Step 4: generate synteny plot 
mamba activate genomescope_env   # has R + ggplot2/plotly/optparse installed - Use a different one if you have a custom R environment with these packages

cd /usr/scratch/priyanshi/julian_gold_assembly/dotPlotly

Rscript pafCoordsDotPlotly.R \
    -i ${BASE_DIR}/JG3_vs_ref_filtered.paf \
    -o JG3_synteny_v3 \
    -m 5000 \
    -q 5000 \
    -k 10 \
    -s \
    -t \
    -l \
    -p 12

# Step 5: compute real mean identity from minimap2's dv:f tag (do NOT report dotPlotly's color-scale identity as the headline figure - see README.md for details)
cd $BASE_DIR
echo "Genome-wide mean identity (all alignments):"
awk '{for(i=13;i<=NF;i++) if($i~/^dv:f:/) {split($i,a,":"); print 1-a[3]}}' JG3_vs_ref_nolongjoin.paf | \
    awk '{sum+=$1; n++} END {print "Mean identity:", sum/n, "  N alignments:", n}'

echo "Mean identity (filtered, MAPQ>=30, >=5kb):"
awk '{for(i=13;i<=NF;i++) if($i~/^dv:f:/) {split($i,a,":"); print 1-a[3]}}' JG3_vs_ref_filtered.paf | \
    awk '{sum+=$1; n++} END {print "Mean identity (filtered):", sum/n, "  N alignments:", n}'

echo "Done. Synteny plot: /usr/scratch/priyanshi/julian_gold_assembly/dotPlotly/JG3_synteny_v3.png"
