# Attach ULTRASort / TDT data to a merged CCF `.sessiondir`

Status: **attach function written.** Matcher `_02` and `fn_load_stored_pathname` are done. Always-on smoke + batch wrapper exist; channel I/O (`datafilt2` / `dataspikes` / 160 ch) not yet run on the pilot.  
Audience: a fresh agent continuing this work. Read this file before touching code.

**MUST — Windows/Linux paths:** new FQNs via `fullfile` + `fn_get_SESSIONLOGS_dir_for_host`. Every **stored** FQN through `fn_load_stored_pathname` **before** `isfile` / `fileparts` / `copyfile`. Do not hardcode `Y:\` / `/Volumes/…`. Do not reimplement the translator. Full rule: **Locked decision 5**.

Downstream MUA/LFP/PETH should treat the synthetic tank like a normal single-run tank:

```matlab
tdt_s = convert(ccf_s, CCF, TDT, tbc_1)   % first-run TBC, also the merged TBC
idx   = round(tdt_s * sr)                 % fn_convert_TDT_ts_struct_to_TDT_binned_idx_struct; no +1
```

---

## Goal

After CCF behavioral merge, create:

```
<merged.sessiondir>/TDT/<synthetic_TANKDIR>/
```

containing:

- requested continuous products **gap-filled onto the first-run TDT clock** (unix time via per-run TBC → tbc_1)
- remapped `dataspikes` on that same clock
- first-run TDT header files (renamed) so `TDTbin2mat('HEADERS')` works
- `timebase_conversion_BEHAVIOUR_EPHYS.mat` = **tbc_1** (copy / re-save via `timebase_conversion/` helpers — not a synthetic `ccf - t0` map)

`fn_parse_CCF_data` and `fn_prepare_and_export_PETH_from_broadband_data` (`MUA.input_wild_card_string = 'datafilt2_ch*.mat'`) should then work without a merged-session special case in the conversion math.

---

## Non-goals / layering rules


| Do                                                                  | Do not                                                                                                                   |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Gap-fill **analysis copies** in `.sessiondir/TDT/...-000000`        | Insert wall-clock gaps into `.mergedir` — `filtfilt` / MAD / covariance on the whole concat would break or invent spikes |
| Remap already-sorted `dataspikes` onto the gapped (tbc_1) clock     | Re-run SpikeFilter / SpikeDetection / clustering on gapped files                                                         |
| Copy first-run `.tsq/.tev/...` so `TDTbin2mat('HEADERS')` works     | Concatenate or rewrite TDT binary stores (undocumented internals)                                                        |
| Copy `merged_TANKdirs_ch*.mat` from `.mergedir` as the SEV stand-in | Copy `*_RSn*_ch*.sev` (huge; already consumed)                                                                           |


ULTRASort wants **gapless neural time**. Analysis selects events in **CCF time**, which in this pipeline **is** posix/unix-epoch seconds (`word_written_timestamp_s`) — not a third clock. Sample indices live on the **tbc_1 TDT** axis. Do not fold wall-clock gaps into `fn_merge_TDT_TANKdirs_4_ULTRASort`.

---

## Current pieces (do not break)


| Piece                | Path                                                                              | Role                                                                                                                                                              |
| -------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CCF behavioral merge | `CCF_merge_runs/fn_merge_same_session_CCF_sessiondirs.m`                          | Writes `.sessiondir`. Accepts `merge_TDT_TANK_dir_list.txt` by stripping to `.sessiondir`. **Leave as-is** (2 h JSONL/h5).                                        |
| SM stub              | `CCF_merge_runs/fn_merge_same_session_CCF_sessiondirs_SM.m`                       | Empty. Thin wrapper later, not the implementation dump.                                                                                                           |
| ULTRASort concat     | `Ephys/ULTRASort_Matlab/helper_functions/fn_merge_TDT_TANKdirs_4_ULTRASort.m`     | Concat SEVs **no wall-clock gap** → `.mergedir/merged_TANKdirs_ch*.mat` + `TDT_TANKdir_merge_struct.mat`                                                          |
| ULTRASort preprocess | `fn_ULTRASort_preprocess_TDT_SCP01_v03`                                           | `merged_TANKdirs_ch*.mat` → `datafilt*`, `dataspikes_*`. `index` = ms from concat t=0: `(sample_idx / par.sr) * 1000`                                             |
| Resplit              | `fn_resplit_merged_TDT_TANKdirs_AFTR_ULTRASort.m`                                 | Slices concat back to source tanks; subtracts segment offset from `index` / `cluster_class(:,2)`                                                                  |
| Per-run TBC          | `<source.sessiondir>/TDT/<tank>/timebase_conversion_BEHAVIOUR_EPHYS.mat`          | Linear `TDT2CCF` / `CCF2TDT`. TDT = seconds from that tank’s start. CCF = **unix epoch seconds**                                                                  |
| Helpers              | `CCF_analysis_matlab/timebase_conversion/`                                        | `fn_create_timing_conversion_struct_CCF`, `fn_convert_time_between_named_timebases_CCF`, `fn_translate_between_named_timebases_CCF`                               |
| Tank locator         | `CCF_ephys_helper/fn_get_TDT_tank_ID_and_FQN_CCF.m`                               | Dir under `TDT/` containing `session_ID(3:8)` (YYMMDD) and `SCP_`, not `exclude.`                                                                                 |
| MUA/LFP              | `Ephys/analysis_code/MUA_helper/fn_prepare_and_export_PETH_from_broadband_data.m` | Full-trace filter/resample, then cut windows. **Now errors on non-finite input** (`~isfinite`). Idx = `round(tdt_s * sr)`                                         |
| Matcher (production) | `fn_match_pythonCCF_and_TDT_reference_events_CCF_02.m`                            | Inner join on **datetime + trial**. Optional `run_idx == min(run_idx)` first (no-op if column absent). TDT datetime via `fn_tdt_dag_payload` (`ini-(22-W)`).      |
| Matcher (legacy)     | `fn_match_pythonCCF_and_TDT_reference_events_CCF.m`                               | Trial-number `setdiff` only. **No production callers.** Keep as reference. Ephys twin: `TDThelper/fn_match_pythonCCF_and_TDT_reference_events.m` (also unwired).  |
| Parse TBC            | `fn_parse_CCF_data.m` ~L516 / ~L570                                               | Calls `_02`. If tank exists, `TDTbin2mat` + match DO. Skips recalc if TBC mat exists (`= 1`); `= 2` forces. Merged+tank: walks sources **and** merged sessiondir. |
| Matcher compare      | `run_compare_CCF_TDT_matchers.m`                                                  | v01 vs `_02` then TBC. Unmerged `20260319T112338`: 378 events, Δts=0, identical scale/offset. Merged NNNNNNM was skipped until attach; re-run after always-on tank exists. |
| Attach (written)     | `CCF_merge_runs/fn_attach_TDT_data_to_merged_CCF_session.m`                       | Gap-fill ULTRASort products onto tbc_1 in `.sessiondir/TDT/...-000000`. Default `{}` = headers + segment table + tbc_1. Batch: `run_attach_TDT_data_to_merged_CCF_sessions`. Smoke: `run_test_fn_attach_TDT_data_to_merged_CCF_session`. |
| Stored path helper   | `AuxiliaryFunctions/Matlab/fn_load_stored_pathname.m`                             | **Done.** Classify unix/windows/relative/UNC; rewrite `SCP_DATA`-rooted abs onto this host; native `filesep`. Lives **outside** this repo. Test: `run_test_fn_load_stored_pathname` (Windows 2026-08-18: 18 pass / 0 fail / 1 skip). |


Sibling dirs:

```
.../260319/20260319TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir/   % CCF merge output
.../260319/20260319TNNNNNNM.A_Elmo.B_MIXED.SCP_01.mergedir/     % ULTRASort concat
```

Discover `.mergedir` by swapping the extension.

---

## Locked decisions

### 1. Gap fill — configurable, default `'zero'`

`fn_prepare_and_export_PETH_from_broadband_data` **errors** if any input sample is non-finite (guard after `double()`). MUA still filters the **entire** vector (`lowpass` after square, then `resample`) before trial cuts, so `'nan'` fill will abort MUA as written.


| Value                                             | What                                            | When                                                                                                                   |
| ------------------------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `'zero'` (default; aliases `'null'`, `'nulling'`) | Fill gaps with 0                                | Default for **all** tokens in testing. SEV/`merged_TANKdirs` is ~symmetric around 0, so this matches `'mean'` without a second pass over the concat. HP `datafilt*` is ~0-mean. Whole-file `std` slightly down (clipping a bit tighter). |
| `'mean'`                                          | Per-channel mean of **real segments only**      | Keep for a channel with real DC. More expensive (`mean` of the full concat). 0-fill on a DC-offset trace = step at every boundary. |
| `'gaussian'`                                      | i.i.d. `N(μ, σ)` per channel from real segments | MAD/std ~unchanged. False threshold crossings if anyone re-detects.                                                    |
| `'nan'`                                           | `NaN`                                           | Honest missingness. **PETH will error** until it grows a replace/skip pass (open item). Do not write NaN into `int16`. |


Implementation:

- μ/σ **per channel**, real samples only, after all runs known, before writing gaps.
- `int16`: `'zero'`/`'mean'` then `int16()`; `'gaussian'` then `round` + clip to `intmin/intmax('int16')`.
- `'nan'` → write `single`/`double`.
- Trial windows that overlap a gap pick up fill; exclude collections within `pre_duration_ms` of a run boundary (QC / later PETH).

### 2. Request list — configurable, default **empty**

```matlab
attach_request_list = {'merged_TANKdirs', 'datafilt', 'datafilt2', 'dataspikes'};
```

Any subset. **Default if empty / omitted: `{}`** — still do the always-on tank metadata (headers, tbc_1, segment table, STAGE). That is the cheap pilot / GB-estimate run.

Always, independent of the list:

- create `TDT/<synthetic_TANKDIR>/`
- copy/rename first-run TDT header files
- copy ULTRASort sidecars from `.mergedir` (xlsx **as-is** so ephys `dir([stem, session_id, '.xlsx'])` hits; `*.svg`/`*.tif`/`*.jpg`; skip dest if present). `STAGE_ultrasort_sidecars`. Error if `dataspikes` requested and no non-template xlsx.
- copy `merge_TDT_TANK_dir_list.txt` + `TDT_TANKdir_merge_struct.mat` into the tank (so `fn_read_sampling_information_from_TDT_SEV_file` can dive into the first source SEV when no local SEV exists)
- write `timebase_conversion_BEHAVIOUR_EPHYS.mat` via `timebase_conversion/` helpers from run-1 event pairs (same math as tbc_1; QC PDF lands in the synthetic tank). Copying the mat is equivalent if the helper re-save is skipped.
- write `tdt_ccf_segment_table.mat`
- STAGE markers
- extend `merge_manifest.json` with TDT paths


| Request token       | Source (`.mergedir`, gapless)                            | Dest (gapped)                                                                                                                     |
| ------------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `'merged_TANKdirs'` | `merged_TANKdirs_ch*.mat` (`cur_channel_data`)           | `merged_TANKdirs_chNNN.scaledSEV.mat` — `cur_channel_data` only. PETH `.mat` branch loads `data` if present, else `cur_channel_data`. |
| `'datafilt'`        | `datafilt_ch*.mat` (`data`, `par`)                       | same names; keep `par`                                                                                                            |
| `'datafilt2'`       | `datafilt2_ch*.mat` (`data`, `par`)                      | same names; keep `par`                                                                                                            |
| `'dataspikes'`      | `dataspikes_ch*_negthr.mat`, `dataspikes_ch*_posthr.mat` | same names; remap times; add `ccf_timestamp_s`, `src_run_idx`                                                                     |


### 3. Storage vs ULTRASort

Analysis tank **duplicates** continuous data. Extra ≈ gap duration × n_ch × bytes/sample × n_requested types.

Ballpark int16, 160 ch, 24.414 kHz: **~28 GB per extra wall-clock hour per file type**.

Accepted. ULTRASort stays gapless. Hardlinks **out**.

**Save strategy:** try default `save` first (v7 compression often fits). `try/catch` `MATLAB:save:sizeTooBigForMATFile` (and friends) → retry `save(..., '-v7.3')`. One channel at a time. Same pattern as jsonl cache in `fn_parse_CCF_data`.

### 4. Pilot

First real-data trial of the **new function** on `20260319TNNNNNNM.A_Elmo.B_MIXED.SCP_01`, not a science pilot.

1. Always-on path only (`attach_request_list = {}`): print per-run CCF spans, tbc_1 indices, gap durations, predicted `N` and GB.
2. One channel `datafilt2` + that channel’s dataspikes + headers + TBC.
3. Then 160 ch / chosen request list.

### 5. Windows / Linux pathnames — MUST (do not skip)

This code runs on Windows *and* Linux against the same session tree. Agents **must** honor this. Do not invent drive letters, unix mounts, or mixed-separator strings. Do **not** reimplement translation.

**Constructing paths** (new FQNs you build):

```matlab
[SESSIONLOGS_dir, cur_SCP_DATA_BaseDir] = fn_get_SESSIONLOGS_dir_for_host();
% then only fullfile(SESSIONLOGS_dir, ...) or fullfile(cur_SCP_DATA_BaseDir, ...)
```

- `fullfile()` for every join. `filesep` only if concatenation is unavoidable.
- Defaults / pilots: `fullfile(SESSIONLOGS_dir, '2026', '260319', '….sessiondir')` — never `'Y:\SCP_DATA\…'` or `'/Volumes/taskcontroller$/…'`.
- `fn_write_merged_CCF_session` writes `.sessionID` with forward slashes (`strrep(..., '\', '/')`). Readers still go through the helper (`Y:/SCP_DATA/...` is windows abs, drive letter wins).

**Loading stored pathnames** (from `merge_manifest.json`, `merge_*_list.txt`, `TDT_TANKdir_merge_struct.mat`, `tdt_ccf_segment_table.mat`, copied TBC mats, `.sessionID`, anything with a FQN field):

```matlab
[pathname_FQN, path_kind_string] = fn_load_stored_pathname(stored_pathname);
% production: omit 2nd arg (helper calls fn_get_SESSIONLOGS_dir_for_host on SCP_DATA rewrite)
% tests only: fn_load_stored_pathname(stored_pathname, fake_SCP_DATA_BaseDir)
if ~isfile(pathname_FQN) && ~isfolder(pathname_FQN)
	error([mfilename, ': translated pathname missing: ', pathname_FQN, ' (stored: ', stored_pathname, ')']);
end
```

Helper location (not in this repo): `SCP_CODE/AuxiliaryFunctions/Matlab/fn_load_stored_pathname.m`. If `exist(..., 'file') ~= 2`, `addpath` that directory (same place as `fn_get_SESSIONLOGS_dir_for_host` in AuxiliaryFunctions). Do **not** copy the `.m` into `CCF_analysis_matlab`.

What the helper already does (do not duplicate):

| Stored start | Kind | Action |
|---|---|---|
| `\\` | UNC | **error** (unsupported) |
| `//` on Windows | UNC | **error** |
| `/` | unix absolute | `SCP_DATA` rewrite if token present; else same-OS filesep-normalize, cross-OS **error** |
| `[A-Za-z]:` | windows absolute | same (`Y:/...` is windows, not unix) |
| leading `\` (not UNC) | windows current-drive abs | WARN + `SCP_DATA` rewrite if token present |
| else | relative | replace foreign sep with `filesep`; do **not** prepend `SESSIONLOGS_dir` |

`SCP_DATA` rewrite: split on `\` and `/`, take parts **after** the first exact `SCP_DATA` token, `fullfile(cur_SCP_DATA_BaseDir, tail{:})`. WARNs when the string changes. Cellstr in → cellstr out.

After translate, **attach** must `isfile`/`isfolder` and abort if missing. The helper does not exist-check (paths may be written later).

**Tests:** `run_test_fn_load_stored_pathname` in the same AuxiliaryFunctions folder. Fake `tempdir/SCP_DATA` (no share). Windows 2026-08-18: **18 pass / 0 fail / 1 skip** (unix-only case). **Run the same script on Linux** before trusting attach on a linux box.

Do **not**: hardcode host roots; concatenate with `'/'` or `'\'`; inline `strrep` instead of the helper; assume merge-list paths are already native.

---

## A) Synthetic TANKDIR name

```
.../TDT/SCP_DAG_v27_PZ04-260319-112316
→ .../<merged.sessiondir>/TDT/SCP_DAG_v27_PZ04-260319-000000
```

Keep prefix through the date token; **zero the last `-\d{6}$` time token**.

`fn_get_TDT_tank_ID_and_FQN_CCF`: merged session_id `20260319TNNNNNNM...` → `session_ID(3:8) = 260319`. Matches. Prefer `fn_parse_session_id.YYMMDD_string` if touching the locator.

Abort if source tanks do not share prefix+date.

---

## B) Gap-fill placement (continuous files)

TDT time of sample `i` (MATLAB 1-based) = `(i-1)/sr` if tank t0 = 0. Verify t0 once from SEV/header; if t0 ≠ 0, add it.

Reference clock is **run 1’s TBC** (`tbc_1`).

```
tbc_1 = first merge-list session’s timebase_conversion_BEHAVIOUR_EPHYS.mat
        convert() = fn_convert_time_between_named_timebases_CCF

for each run k (merge-list order, must be chronological):
    n_k             from merge_struct.samples_per_TANK(k)
    t_start_ccf(k)  = convert(0,             TDT, CCF, tbc_k)
    t_end_ccf(k)    = convert((n_k-1)/sr,    TDT, CCF, tbc_k)
    t_start_tdt1(k) = convert(t_start_ccf(k), CCF, TDT, tbc_1)
    t_end_tdt1(k)   = convert(t_end_ccf(k),   CCF, TDT, tbc_1)
    i0(k) = max(1, round(t_start_tdt1(k) * sr))   % MATLAB indices start at 1
    i1(k) = i0(k) + n_k - 1                       % 1:1 copy of n_k samples

N   = max(i1)
out = allocate(N) with gap_fill_mode
for each run k:
    ABORT on overlap
    ABORT if k > 1 and round(t_start_tdt1(k)*sr) < 1   % later runs must sit after run 1
    out(i0(k):i1(k)) = run_k_samples
```

Do **not** round TDT seconds to a fixed number of decimals (0.001 s ≈ 24 samples). `round(tdt * sr)` is the index rounding.

If `round(t_start_tdt1(1) * sr)` is 0 (typical tank t0), **clamp to 1**. One-sample offset (~41 µs at 24 kHz) is acceptable; PETH already skips `start_idx < 1`. Do not add a global `+1` to all runs (that would shift PETH by one sample everywhere).

**Source of samples:** split `.mergedir` concat using `cumsum(samples_per_TANK)`. Do not re-read SEVs.

**Clock stability (locked):** TDT `sr` is stable enough that each run is a 1:1 block: place at `i0(k)`, write the next `n_k = length(session-segment)` samples. Do not resample or place per-sample. Convert **first** (and last only for QC). Intra-run skips/dupes if `scale_k ≠ scale_1` are ignored. Gaps are CCF-sized **on the tbc_1 axis**. Report `|i1(k) - round(t_end_tdt1(k)*sr)|` per run (ppm residual).

Same `[i0,i1]` for every requested continuous type.

---

## C) Timestamps — tbc_1 axis, unix via per-run TBC

```
ccf_s       = convert(local_tdt_k, TDT, CCF, tbc_k)   % unix epoch
merged_tdt  = convert(ccf_s,       CCF, TDT, tbc_1)
idx         = round(merged_tdt * sr)
```

Run 1 is a near-exact inverse → original indices. Later runs sit where an extrapolated run-1 TDT clock would put that unix time.

**Merged TBC:** re-save tbc_1 with `fn_translate_between_named_timebases_CCF` / `fn_create_timing_conversion_struct_CCF` from the stored run-1 `ParaState`_* lists (QC PDF in the synthetic tank). Do **not** write `scale=1, offset=-t0_ccf`.

Existing PETH/parse conversion math stays unchanged.

**Do not** store a dense per-sample CCF vector. With tbc_k / tbc_1, any timestamp or index is `convert` + `round(tdt * sr)` on demand.

`tdt_ccf_segment_table.mat`: per-run `i0,i1,n_k,t_start_ccf,t_end_ccf,t_start_tdt1,t_end_tdt1`, source tank FQN, tbc path, `gap_fill_mode`, `sr`, `N`.

---

## Dataspikes remap

Keep waveforms / `features` / `cluster_class(:,1)` / `tree` / `par`. Convert **every** spike:

```
k          = run from merge_struct start_ts_ms / samples_per_TANK
local_tdt  = (old_index_ms - start_ts_ms(k)) / 1000
ccf_s      = convert(local_tdt, TDT, CCF, tbc_k)
merged_tdt = convert(ccf_s,     CCF, TDT, tbc_1)
index      = merged_tdt * 1000              % OVERWRITE — ms on tbc_1 clock
cluster_class(:,2) = index
ccf_timestamp_s    = ccf_s
src_run_idx        = int32(k-1)
```

`round(index/1000 * sr)` = PETH idx. Abort if a source run is missing TBC.

Known fields: `index`, `spikes`, `features`, `feature_names`, `tree`, `classtemp`, `par`, `cluster_class`. Error on unknown fields.

Copy from `.mergedir` (global clusters), not resplit source tanks.

---

## First-run TDT header files (always)

Copy from the **first merge-list tank**. Discover the header stem via `*.tsq` (same as `TDTbin2mat`) — it is **not** always equal to the tank folder name. Synapse files look like:

`Elmo-260319_SCP_DAG_v27_PZ04-260319-112316.tsq`

Rename by swapping the tank-id substring → synthetic TANKDIR:

`Elmo-260319_SCP_DAG_v27_PZ04-260319-112316.tsq` → `Elmo-260319_SCP_DAG_v27_PZ04-260319-000000.tsq`

Copy: `.Tbk`, `.Tdx`, `.tev`, `.tin`, `.tnt`, `.tsq`. Abort if `.tsq` or `.tev` missing. Do not write `STAGE_headers.finished` until both exist. If that marker exists but dest has no `.tsq`, redo.

Also copy if present:

- `*.TDT_RZ2_streams.mat` — dest name is `[synthetic_TANKDIR, '.TDT_RZ2_streams.mat']` (`parse` loads `[TDT_tank_ID, '.TDT_RZ2_streams.mat']`). Contents unchanged.
- `Notes.txt`, `StoresListing.txt`, `bad_channel_list.txt`

**Do not copy SEVs. Do not merge `.tev` binaries** — format is poorly documented; copying run 1 is enough because the merged continuous data live on the tbc_1 axis.

**Matcher (done — do not reimplement):**  
`fn_match_pythonCCF_and_TDT_reference_events_CCF_02` inner-joins on reconstructed datetime + trial. If `run_idx` exists, keep `run_idx == min(run_idx)` first (unmerged: column absent → no-op). TDT DAG datetime bytes use the same even offset from INI=22 as CCF `word_index` (`fn_tdt_dag_payload`; trial 16/18 still `-6`/`-4`). Production callers:

- `fn_parse_CCF_data.m` ~L570
- `Ephys/analysis_code/SCP_ephys_base_analysis_CCF.m` ~L574

Unmerged T112338: bit-identical to v01 (378 events, same TBC). Merged live check is still pending (no synthetic tank yet): merged `DO_messages` + copied run-1 `.tev` should keep run 1 and recover tbc_1. Do **not** match on “earliest datetime group” as a string prefix — that would collapse to one HHMMSS second; the key is full datetime+trial, plus `run_idx` when present.

Attach still writes/copies tbc_1 so MUA works even if parse later skips recalc (`create_timebase_conversion_between_CCF_and_EPHYS = 1` and mat exists). Parse on a filled merged tank **should still run** TBC at least once (QC PDF + sanity vs copied tbc_1), not skip the merged tank just because source TBCs exist. Force with `= 2` if the mat was copied without a QC PDF.

---

## Parse / MUA follow-ups (not inside attach, but required for “treat as a normal tank”)

1. **`fn_parse_CCF_data`:** matcher is `_02` already. If merged session **and** synthetic tank present, run TBC on that tank (copied tev + merged DO). Keep walking source sessions for missing source TBCs. Do not skip the merged tank when the synthetic TBC mat is missing; if attach already wrote tbc_1, force `= 2` once to regenerate the QC PDF against merged DO.
2. **`fn_read_sampling_information_from_TDT_SEV_file`:** already dives into first source tank if `merge_TDT_TANK_dir_list.txt` + `TDT_TANKdir_merge_struct.mat` exist. Copy those two into the synthetic tank. No SEVs. Translate any FQNs inside merge_struct / the list file with `fn_load_stored_pathname` before diving.
3. **MUA/LFP wildcards:** `info_wild_card_string = '*_SCP_DAG_*_RSn*_ch*.sev'` finds nothing in the synthetic tank. Add a **fallback** when the first wildcard is empty, e.g. `merged_TANKdirs_ch*.scaledSEV.mat` then `datafilt2_ch*.mat` / `datafilt_ch*.mat`, so the same `SCP_ephys_base_analysis_CCF` path works for sub-sessions and merged tanks. PETH `.mat` branch: `data` if present, else `cur_channel_data`.

---

## New function (written)

`CCF_merge_runs/fn_attach_TDT_data_to_merged_CCF_session.m`

```matlab
[synthetic_tank_FQN, tdt_ccf_segment_table] = fn_attach_TDT_data_to_merged_CCF_session( ...
	merged_sessiondir_FQN, attach_request_list, gap_fill_mode)
```

- `merged_sessiondir_FQN`: `.sessiondir`, sibling `.mergedir`, or a merge-list `.txt` whose parent is one of those. Default: 260319 NNNNNNM.
- `attach_request_list`: default `{}` (always-on metadata only).
- `gap_fill_mode`: default `'zero'` (aliases `'null'`, `'nulling'`).

Discover `.mergedir` sibling. Require `merge_manifest.json`, `.mergedir/TDT_TANKdir_merge_struct.mat`, per-source TBC mats, and (if a request token is set) the matching concat files. Stored FQNs from `merge_struct.TDT_TANKdir_merge_list` go through `fn_load_stored_pathname` then `isfolder`. Copy merge_struct/list **as stored** (do not bake this-host paths).

STAGE markers in the synthetic tank (`STAGE_<step>.finished`), ULTRASort style:

1. `headers` — dir + renamed tsq/tev/… + merge_struct + tank list copy
2. `segment_table` — tbc_1 `i0/i1`, CCF spans, `N` (no channel I/O)
3. `tbc` — re-save tbc_1 via `fn_translate_between_named_timebases_CCF` (same drop-ends as parse: `2:end-1` if n>10)
4. per token: `merged_TANKdirs` / `datafilt` / `datafilt2` / `dataspikes` (per-channel skip if dest exists; STAGE written after the token finishes)
5. `qc` — extend `merge_manifest.json` with `tdt_attach`

Do **not** call from `fn_merge_same_session_CCF_sessiondirs` by default.

**Batch wrapper:** `CCF_merge_runs/run_attach_TDT_data_to_merged_CCF_sessions.m`  
Default: 260319, `{}`. `run_attach_TDT_data_to_merged_CCF_sessions('all')` walks the TDT-merge catalog. Continues after per-session errors.

**Always-on smoke:** `CCF_merge_runs/run_test_fn_attach_TDT_data_to_merged_CCF_session.m`  
`{}` on 260319. Asserts tank, STAGE markers, segment table, tbc mat+PDF, renamed `.tsq/.tev`. No 160-ch I/O.

```
parse each source session                 → TBC mats
fn_merge_same_session_CCF_sessiondirs     → .sessiondir
fn_merge_TDT_TANKdirs_4_ULTRASort         → .mergedir gapless
ULTRASort preprocess + sort
fn_resplit_...                            → source tanks (unchanged)
fn_attach_TDT_data_to_merged_CCF_session  → .sessiondir/TDT/...-000000
parse merged session                      → TBC on synthetic tank (`_02` already wired; force recalc if attach copied tbc_1 without QC PDF)
```

---

## QC

- No block overlap; `i0` strictly increasing.
- `sum(n_k) + gap_samples = N` (gap_samples from tbc_1 index holes).
- First/last spike per run lands in `[i0,i1]`.
- `triallog` CCF event → `convert(..., CCF, TDT, tbc_1)` → `round(tdt*sr)` is intra-block for in-run events.
- Within-run implied `dt ≈ 1/sr`; at boundaries ≫ `1/sr`.
- Residual `|i1(k) - round(t_end_tdt1(k)*sr)|` per run.
- Gap samples match `gap_fill_mode`.
- `fn_get_TDT_tank_ID_and_FQN_CCF` returns the synthetic tank.
- Stored FQNs from manifest/merge_struct survive `fn_load_stored_pathname` (`isfile`/`isfolder`).
- `whos('-file', datafilt2_ch001)` → `length(data)==N`; scaledSEV files have `cur_channel_data` only (`length==N`).

---

## MATLAB style (this repo)

`fn_` prefix, `snake_case`, `_FQN` / `_list` / `_struct` / `_idx` / `_ldx` / `_s`, `fullfile()`, tabs, tic/toc, `dbstop if error`, `disp([mfilename, ': ...'])`. Propose diffs; wait for approval before implementing.

Helpers at the bottom of the attach function file. Use `fn_convert_time_between_named_timebases_CCF` — do not reimplement scale/offset.

Pathnames: **Locked decision 5**. Construct with `fullfile` + `fn_get_SESSIONLOGS_dir_for_host`. Stored FQNs: `fn_load_stored_pathname` then exist-check. Never inline.

---

## Open items (do not block attach metadata / gap-fill)

- Run `run_test_fn_load_stored_pathname` on **Linux** (Windows already 18/18).
- First parse TBC on merged DO + run-1 tev after attach headers exist (`_02` untested on that pair; unmerged already matches v01).
- Parse: actually run TBC on the synthetic tank when present (force `= 2` if attach copied tbc_1).
- PETH: optional NaN replace/skip instead of hard error → then `'nan'` fill is usable for MUA.
- MUA/LFP wildcard fallback when no SEV in tank.
- LFP `input_wild_card_string` → `merged_TANKdirs_ch*.scaledSEV.mat`.
- `fn_get_TDT_tank_ID_and_FQN_CCF`: use `fn_parse_session_id.YYMMDD_string`.

---

## Implementation order

**Already done (do not redo):**

- Matcher `_02` in parse + `SCP_ephys_base_analysis_CCF`. Unmerged T112338 bit-identical to v01.
- `fn_load_stored_pathname` + `run_test_fn_load_stored_pathname` (Windows 18/18). Linux score still open.
- `fn_attach_TDT_data_to_merged_CCF_session.m` (always-on + all four tokens; `-v7.3` fallback; STAGE; manifest `tdt_attach`).
- `run_test_fn_attach_TDT_data_to_merged_CCF_session.m` (always-on smoke, 260319).
- `run_attach_TDT_data_to_merged_CCF_sessions.m` (batch; default 260319/`{}`; `'all'` = catalog).

**Next:**

1. Run `run_test_fn_attach_TDT_data_to_merged_CCF_session` on `20260319TNNNNNNM` (always-on `{}`). Confirm printed CCF spans / `i0/i1` / gap / GB. Then parse that tank with `_02` (merged DO vs copied run-1 tev) and confirm TBC ≈ tbc_1.
2. One `datafilt2` channel + that channel’s dataspikes remap. Spot-check idx vs CCF events through tbc_1.
3. Full chosen request list via `run_attach_TDT_data_to_merged_CCF_sessions(sessiondir, {'datafilt2','dataspikes'}, 'zero')`.
4. Parse TBC on merged tank (force `= 2` if needed) + MUA/LFP wildcard fallback (can ship after attach works with copied tbc_1).
5. Optional SM wrapper. Do **not** hook onto the 2 h behavioral merge.

