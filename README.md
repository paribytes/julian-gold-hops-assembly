# Julian Gold Hops Genome Assembly

Short-read genome assembly pipeline for two *Humulus lupulus* cv. Julian
Gold accessions (JG2 and JG3), using MaSuRCA for de novo assembly and
RagTag for reference-guided scaffolding.

## Pipeline overview

1. Concatenate multi-lane raw reads into single R1/R2 files per sample
2. Estimate insert size with `fastp`
3. Assemble with MaSuRCA v4.1.4
4. Scaffold against a chromosome-scale *H. lupulus* reference with RagTag v2.1.0
5. Assess quality with QUAST v5.0.2 and BUSCO v4.1.4
6. Generate a whole-genome synteny plot against the reference

## Requirements

- MaSuRCA v4.1.4 (`mamba create -n masurca -c bioconda -c conda-forge masurca`)
- RagTag v2.1.0 (`mamba create -n ragtag -c bioconda -c conda-forge ragtag`)
- fastp, QUAST v5.0.2, BUSCO v4.1.4, seqkit (installed in separate conda envs — see `scripts/`)
- minimap2 (bundled with the `ragtag` env)
- R with `ggplot2`, `plotly`, `optparse` (for synteny plotting) — install via `mamba install -c conda-forge r-ggplot2 r-plotly r-optparse`
- [dotPlotly](https://github.com/tpoorten/dotPlotly) for synteny dot plots
- A chromosome-scale *H. lupulus* reference genome (not included in this repo — see Data section)

```
mamba create -n masurca -c bioconda -c conda-forge masurca=4.1.4
mamba create -n ragtag -c bioconda -c conda-forge ragtag=2.1.0
```

## Compute Environment

- This pipeline was run on an institutional HPC cluster using the PBS/Torque
scheduler. Job scripts in `scripts/` use PBS directives (`#PBS -l nodes=...`)
and will need adjustment for other schedulers (SLURM, etc.) or institutional
node-naming conventions.

### Notable resource requirements learned during this run:
- **MaSuRCA's super-reads step** requires a single memory allocation on the
  order of ~100GB for a genome this size (~2.3-2.6 Gb, repeat-rich). Standard
  compute nodes with ~128GB total RAM are not sufficient headroom; a
  high-memory node (several hundred GB+) is recommended.
  
- **MaSuRCA's CGW (scaffold graph) step** is single-threaded and can run for
  multiple days on a genome this size/complexity.
  
- **Job interruption during CGW**: if a MaSuRCA job is killed mid-CGW (e.g.,
  by scheduled cluster maintenance), the CGW checkpoint may be left in a
  corrupted state that segfaults on resume rather than resuming cleanly.
  Symptoms include implausible values in `cgw.out` logs (e.g., scaffold
  lengths many orders of magnitude too large) followed by a segfault. If
  this happens, back up and remove the `CA/7-0-CGW/` directory before
  resubmitting to force a clean rebuild of that stage — **do not trust a
  resumed checkpoint after an abrupt kill.**


## Directory structure

- `configs/`    MaSuRCA config files (per sample)
- `scripts/`  PBS job scripts and analysis scripts for each pipeline stage
- `figures/`  Output plots (e.g., synteny dot plots)
- `patches/`  Documented source-code patches required to run certain tools on this cluster

## Run order

```bash
# 1. Concatenate lanes
bash scripts/concat_lanes.sh

# 2. Get insert size from fastp, update configs/masurca_config_*.txt

# 3. Run MaSuRCA

qsub scripts/run_masurca_JG2.pbs
qsub scripts/run_masurca_JG3.pbs

# 4. Run RagTag (correct + scaffold)

qsub scripts/run_ragtag_JG2.pbs
qsub scripts/run_ragtag_JG3.pbs

# NOTE: apply patches in patches/ to the ragtag conda env first - see Known issues

# 5. QUAST
qsub scripts/run_quast_JG3_v3.pbs

# 6. BUSCO
qsub scripts/run_busco_JG3.pbs
# NOTE: apply patches/busco_rU_mode_fix.md to the busco conda env first

# 7. Synteny plot
bash scripts/run_synteny_analysis.sh
```

## QC Results (JG3)

| Metric | Value |
|---|---|
| Scaffolded N50 | 155,335,636 bp |
| Scaffolded L50 | 7 |
| Scaffolded total length | 2,576,951,664 bp |
| GC content | 38.41% |
| BUSCO complete | 93.0% (91.6% single-copy, 1.4% duplicated) |
| BUSCO fragmented | 3.9% |
| BUSCO missing | 3.1% |
| Mean synteny identity vs. reference (genome-wide) | 96.5% |
| Mean synteny identity vs. reference (filtered, MAPQ≥30, ≥5kb) | 97.2% |

Raw contig-level assembly (pre-scaffolding) had N50 = 2,192 bp across
1,672,287 contigs — reference-guided scaffolding substantially improved
contiguity to chromosome scale (see `figures/JG3_synteny_v3.png`).

QUAST misassembly/genome-fraction analysis could not be completed for
this assembly — see Known issues.

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

- **BUSCO 4.1.4 + Python 3.13 incompatibility**: the `busco` conda
  environment resolved to Python 3.13, which removed the deprecated `'rU'`
  file-open mode used in four places in BUSCO's `BuscoTools.py`. This
  causes a crash partway through analysis (`ValueError: invalid mode: 'rU'`),
  after `tblastn` completes but before gene prediction begins — easy to
  mistake for a long-running/hung job if you're only checking `top` rather
  than the actual log. See `patches/busco_rU_mode_fix.md`. Lost if the
  `busco` environment is recreated.

- **QUAST misassembly detection hang**: QUAST v5.0.2's Contig Analyzer
  module reproducibly hangs indefinitely (multiple days observed) during
  alignment-based misassembly detection on this assembly, independent of
  node memory, thread count, or misassembly-sensitivity thresholds tested
  (`--extensive-mis-size`, `--unaligned-part-size`, `--fragmented`,
  `--min-contig`). Basic Statistics (N50, total length, GC%) complete
  normally and reliably within minutes; only the misassembly/genome-fraction
  analysis is affected. Newer QUAST versions (5.2.0+) could not be installed
  due to the cluster's glibc 2.17 constraint. Workaround used: report Basic
  Statistics only; misassembly/genome-fraction analysis omitted.

- **dotPlotly color-scale identity is misleading**: dotPlotly's "Mean
  Percent Identity" color scale is computed as `matched_bases / alignment_length`
  per alignment record, averaged per query scaffold. With minimap2's default
  long-range join behavior, this ratio is severely deflated (~30-50%) because
  merged alignment blocks span large unaligned gaps that inflate the
  denominator. Even with `--no-long-join` and MAPQ/length filtering, the
  color scale (~55-60%) still understates true identity because it averages
  uniformly across many short, lower-quality alignment records. For an
  accurate identity figure, compute mean identity from minimap2's `dv:f:`
  divergence tag directly (`1 - divergence`) rather than citing dotPlotly's
  color-scale value — see `scripts/run_synteny_analysis.sh` step 5.

## Citations

- MaSuRCA: Zimin et al. 2013
- RagTag: Alonge et al. 2022
- QUAST: Gurevich et al. 2013
- BUSCO: Simão et al. 2015
- minimap2: Li 2018
- dotPlotly: https://github.com/tpoorten/dotPlotly
