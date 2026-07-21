# Julian Gold Hops Genome Assembly

Short-read genome assembly pipeline for two *Humulus lupulus* cv. Julian
Gold accessions (JG2 and JG3), using MaSuRCA for de novo assembly and
RagTag for reference-guided scaffolding.

## Pipeline overview

1. Concatenate multi-lane raw reads into single R1/R2 files per sample
2. Estimate insert size with `fastp`
3. Assemble with MaSuRCA v4.1.4
4. Scaffold against a chromosome-scale *H. lupulus* reference with RagTag v2.1.0
5. Assess quality with QUAST (BUSCO/Merqury planned)

## Requirements

- MaSuRCA v4.1.4 (`mamba create -n masurca -c bioconda -c conda-forge masurca`)
- RagTag v2.1.0 (`mamba create -n ragtag -c bioconda -c conda-forge ragtag`)
- fastp, QUAST, BUSCO (installed in separate conda envs — see `scripts/`)
- A chromosome-scale *H. lupulus* reference genome (not included in this repo — see Data section)

## Directory structure

- configs/    MaSuRCA config files (per sample)
- scripts/    PBS job scripts for each pipeline stage

## Run order

```bash
# 1. Concatenate lanes (see scripts/ for the concat script)
# 2. Get insert size from fastp, update configs/masurca_config_*.txt
# 3. Run MaSuRCA
qsub scripts/run_masurca_JG2.pbs
qsub scripts/run_masurca_JG3.pbs

# 4. Run RagTag (correct + scaffold)
qsub scripts/run_ragtag_JG2.pbs
qsub scripts/run_ragtag_JG3.pbs

# 5. QC
# quast.py <scaffold.fasta> -r <reference.fasta> -o quast_out --threads 16
```

## Data

Raw reads, reference genome, and all assembly outputs are **not** tracked
in this repo (see `.gitignore`) — too large for git, and not appropriate
to version this way. They live on cluster scratch storage.

## Known issues

- **Node memory constraints**: MaSuRCA's super-reads step needs substantially
  more memory than expected for a genome this size/repeat-content (~97GB+
  single allocation). Use high-memory nodes (`ram512`, or similar), not
  standard compute nodes.
- **RagTag + old pysam bug**: the `ragtag` conda environment on this cluster
  resolved to `pysam 0.8.3` (very old — glibc 2.17 constraint prevents
  installing a modern pysam here). This causes `fai.fetch()` to return
  `bytes` instead of `str`, which crashes two scripts:
  - `ragtag_utilities/utilities.py` (`reverse_complement()`)
  - `bin/ragtag_agp2fa.py` (line ~71, forward-strand FASTA writing)

  Both were patched in-place to decode bytes to `str` before use. If you
  reinstall/recreate the `ragtag` env, **these patches will be lost** and
  need to be reapplied (or pin an older pysam / find a version combo that
  doesn't hit this).
- **Stale `.fai` index**: if you ever regenerate a FASTA file in place
  (e.g., after fixing the above bug), **delete the old `.fai` index**
  before re-running anything that reads it with pysam. A stale index will
  silently return wrong byte ranges, causing corrupted output that looks
  fine on a quick spot-check but fails validation later (e.g., inflated
  header counts, truncated sequence lengths). Always verify total sequence
  length against expected values after any FASTA regeneration.

## Citations

- MaSuRCA: Zimin et al. 2013
- RagTag: Alonge et al. 2022
- QUAST: Gurevich et al. 2013
