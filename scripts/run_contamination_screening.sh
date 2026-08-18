#!/bin/bash

# Contamination screening: JG3 scaffolded assembly
# Uses NCBI's FCS-adaptor (v0.5.5) via Apptainer/Singularity (v1.5.3).
#
# NOTE: fcs.py clean genome applies NCBI's standard 200bp minimum contig length filter as a side effect of cleaning - this removes short unplaced
# fragments in addition to actual adapter-contaminated sequence. Verified this is intentional/standard behavior, not data corruption - see repo
# README Known Issues for details.

set -euo pipefail

BASE_DIR=/usr/scratch/priyanshi/contaminant_screening
SCAFFOLD=/usr/scratch/priyanshi/julian_gold_assembly/JG3_ragtag/scaffold/ragtag.scaffold.fasta
cd $BASE_DIR

# Remove zero-length sequences (RagTag correction artifacts)
mamba activate seqkit_env
seqkit seq -m 1 $SCAFFOLD > ragtag.scaffold.no_empty.fasta

# Download FCS-adaptor tooling (one-time setup)
# curl -LO https://github.com/ncbi/fcs/raw/main/dist/run_fcsadaptor.sh
# chmod 755 run_fcsadaptor.sh
# curl https://ftp.ncbi.nlm.nih.gov/genomes/TOOLS/FCS/releases/latest/fcs-adaptor.sif -Lo fcs-adaptor.sif

# Run FCS-adaptor screening (eukaryote mode)
mkdir -p outputdir_JG3
./run_fcsadaptor.sh \
    --fasta-input ragtag.scaffold.no_empty.fasta \
    --output-dir ./outputdir_JG3 \
    --euk \
    --container-engine singularity \
    --image fcs-adaptor.sif

# Download FCS-GX image for cleaning (one-time setup)
# curl -LO https://github.com/ncbi/fcs/raw/main/dist/fcs.py
# curl https://ftp.ncbi.nlm.nih.gov/genomes/TOOLS/FCS/releases/latest/fcs-gx.sif -Lo fcs-gx.sif

# Clean genome using the adaptor report
export FCS_DEFAULT_IMAGE=fcs-gx.sif
cat ragtag.scaffold.no_empty.fasta | \
    python3 ./fcs.py clean genome \
    --action-report ./outputdir_JG3/fcs_adaptor_report.txt \
    --output JG3_scaffold.decontaminated.fasta \
    --contam-fasta-out JG3_contam_removed.fasta

echo "Done. Cleaned assembly: ${BASE_DIR}/JG3_scaffold.decontaminated.fasta"
