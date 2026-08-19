# HOWTO: merge interrupted CCF + TDT runs into one analysis session

Audience: humans doing the post-recording merge, and agents continuing this pipeline.  
Status: this is the **operator procedure**. Design internals for TDT attach live in [`PLAN_attach_TDT_to_merged_CCF_sessiondir.md`](PLAN_attach_TDT_to_merged_CCF_sessiondir.md) — do not invent a third clock or gap-fill the ULTRASort `.mergedir`.

After this procedure, `SCP_ephys_session_wrapper_20260817_CCF` (and variants) should treat the merged `.sessiondir` like a single bona fide SCP_01 session.

---

## What this solves

A recording day often produces several **runs** (EventIDE restarts, partner swaps, tank splits). Each run is:

- one CCF `.sessiondir` (behavior, gaze, DO messages)
- one TDT tank under that sessiondir’s `TDT/` folder (SEV + header files)

You cannot just concatenate wall-clock time. Two products are required:

| Tree | Suffix | Clock | Role |
|------|--------|-------|------|
| ULTRASort concat | `.mergedir` | **gapless** neural samples | filter / detect / cluster as if one continuous recording |
| CCF analysis session | `.sessiondir` | **real CCF/unix time**, TDT copies **gap-filled onto run-1 TDT clock (`tbc_1`)** | parse, PETH, MUA, wrapper |

They are **siblings** in the same `SESSIONLOGS/$YEAR/$YYMMDD/` folder, same stem, different suffix.

```
SESSIONLOGS/2026/260206/
  20260206T112316.A_Elmo.B_Curius.SCP_01.sessiondir/     # source run 1
  20260206T140102.A_Elmo.B_Flaffus.SCP_01.sessiondir/    # source run 2
  20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01.mergedir/       # ULTRASort (gapless)
  20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir/     # analysis (gapped TDT)
```

Do **not** nest one inside the other. Do **not** gap-fill `.mergedir`. Do **not** re-sort on the gapped analysis copies.

---

## Naming the merged stem

Take the **first run’s session ID**, then:

1. Replace the `THHMMSS` time numerals with `TNNNNNN`.
2. Append `M` (merged). Optional `M2` if you re-merge the same day.
3. Partner (`B_…`): keep the true name if **all** runs are against the same partner; otherwise `B_MIXED`.
4. Keep `A_…` and `.SCP_01`.

Examples:

```
20260206T112316.A_Elmo.B_Curius.SCP_01     →  20260206TNNNNNNM.A_Elmo.B_Curius.SCP_01
20260206T112316.A_Elmo.B_Curius.SCP_01     →  20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01   (if partners differ)
```

`fn_parse_session_id` treats a trailing `M` on the datetime token as `merged_session = 1`. Downstream tank locator uses `session_ID(3:8)` = `YYMMDD` (`260206`).

---

## Code map (do not reinvent)

| Step | Function | Repo path |
|------|----------|-----------|
| CCF behavioral merge | `fn_merge_same_session_CCF_sessiondirs` | `CCF_analysis_matlab/CCF_merge_runs/` |
| TDT SEV concat | `fn_merge_TDT_TANKdirs_4_ULTRASort` | `Ephys/ULTRASort_Matlab/helper_functions/` |
| Filter / detect / cluster | `fn_ULTRASort_preprocess_TDT_SCP01_v03` | `Ephys/ULTRASort_Matlab/` |
| Optional: slice concat back to source tanks | `fn_resplit_merged_TDT_TANKdirs_AFTR_ULTRASort` | `Ephys/ULTRASort_Matlab/helper_functions/` |
| Attach sorted ephys to merged CCF | `fn_attach_TDT_data_to_merged_CCF_session` | `CCF_analysis_matlab/CCF_merge_runs/` |
| Batch attach | `run_attach_TDT_data_to_merged_CCF_sessions` | same |
| Parse / TBC | `fn_parse_CCF_data` | `CCF_analysis_matlab/` |
| Science wrapper | `SCP_ephys_session_wrapper_20260817_CCF` | `Ephys/analysis_code/` |

Data root: `fn_get_SESSIONLOGS_dir_for_host()` → typically `…/SCP_DATA/SCP-CTRL-01/SESSIONLOGS/`. Never hardcode `Y:\`. Stored FQNs go through `fn_load_stored_pathname` before `isfile` / `copyfile`.

---

## Prerequisites (before attach will succeed)

- All source `.sessiondir` folders copied (step 1).
- Each source tank still has `*_RSn*_ch*.sev` (same RSn store, same channel set, same `sr`).
- `enums.py` identical across CCF runs (CCF merge aborts otherwise).
- **Per-run TBC mats** in each source tank:  
  `<source.sessiondir>/TDT/<tank>/timebase_conversion_BEHAVIOUR_EPHYS.mat`  
  Created by parsing each source session once (`fn_parse_CCF_data` with `DO_messages.jsonl` + tank). Can run any time after step 1; **must exist before step 6**.
- MATLAB path includes `CCF_analysis_matlab`, `Ephys/ULTRASort_Matlab`, and `AuxiliaryFunctions/Matlab`.

Runtime: CCF merge of a large day is ~2 h. TDT concat + ULTRASort is hours to **days**. Run on a stable share.

---

## Step 1 — Copy runs into SESSIONLOGS

Manually copy each run’s `.sessiondir` (including `TDT/<tank>/`) into:

```
SESSIONLOGS/$YEAR/$YYMMDD/
```

`$YEAR` is four-digit (`2026`). `$YYMMDD` is the session date folder (`260206`). Keep original session IDs. Do not rename source runs.

Typical tank path inside a run:

```
<run>.sessiondir/TDT/SCP_DAG_v27_PZ04-260206-112316/
```

Tank folders contain `SCP_` and the `YYMMDD` date token. Do not leave tanks named `exclude.*`.

---

## Step 2.A — Create `.mergedir` + TDT merge list

Create the empty sibling:

```
SESSIONLOGS/2026/260206/20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01.mergedir/
```

Populate `merge_TDT_TANK_dir_list.txt` **inside that folder**. One **TDT tank directory** per line, **chronological**, no blank lines (TDT merge uses `readlines` unfiltered). Paths may be Windows or POSIX; attach will translate via `fn_load_stored_pathname`.

```
Y:\SCP_DATA\SCP-CTRL-01\SESSIONLOGS\2026\260206\20260206T112316.A_Elmo.B_Curius.SCP_01.sessiondir\TDT\SCP_DAG_v27_PZ04-260206-112316
Y:\SCP_DATA\SCP-CTRL-01\SESSIONLOGS\2026\260206\20260206T140102.A_Elmo.B_Flaffus.SCP_01.sessiondir\TDT\SCP_DAG_v27_PZ04-260206-140051
```

A helper to generate this list does not exist yet. Channel IDs and sampling rate must match across tanks; otherwise `fn_merge_TDT_TANKdirs_4_ULTRASort` errors and you fix the list by hand.

---

## Step 2.B — Create `.sessiondir` + CCF behavioral merge

Create the sibling sessiondir (same stem, `.sessiondir` suffix):

```
SESSIONLOGS/2026/260206/20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir/
```

Put a merge-list file **inside this sessiondir**. Output of `fn_merge_same_session_CCF_sessiondirs` is the **parent of that list file**.

Two valid list styles:

1. **Reuse the TDT list** (current catalog default): copy `merge_TDT_TANK_dir_list.txt` into the `.sessiondir`. CCF merge detects `merge_TDT_TANK_dir_list` and strips each line to the enclosing `.sessiondir`.
2. **`merge_CCF_sessiondir_list.txt`**: one source `.sessiondir` path per line, same order as the TDT list.

Then:

```matlab
[SESSIONLOGS_dir, ~] = fn_get_SESSIONLOGS_dir_for_host();
merge_list_FQN = fullfile(SESSIONLOGS_dir, '2026', '260206', ...
	'20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir', ...
	'merge_TDT_TANK_dir_list.txt');   % or merge_CCF_sessiondir_list.txt
merged_sessiondir_FQN_list = fn_merge_same_session_CCF_sessiondirs({merge_list_FQN});
```

What the CCF merge actually does:

1. `fn_load_CCF_raw_files` per run
2. Abort if `enums.py` differs
3. `fn_build_global_target_map` + `fn_remap_record2D_targets`
4. Offset `n_finished_collections`; carry cumulative scores; add `run_idx` (0-based)
5. Merge AI (`NaN` gaps) / DI (`0` gaps) so global linear timestamps stay valid
6. Stream-merge JSONL: offset `collection_number`, append `run_idx`, keep `type`
7. Offset `movement_to_target.csv` `cycle` and `*_frame` columns
8. Write `merge_manifest.json`, `merged_conf.jsonl`, first-run `conf.json`, merged `record2D.h5`, streams

Do **not** hook TDT attach onto this call. It is a multi-hour JSONL/h5 job.

Sanity after merge: `merge_manifest.json` exists; `record2D.h5` has `run_idx`; `DO_messages.jsonl` has `run_idx`.

Optional (can overlap with 2.B / 3): parse **each source** session so TBC mats exist for attach.

```matlab
[triallog_table, ~, record2D_struct] = fn_parse_CCF_data(source_sessiondir_FQN, GAZE_OPTS_struct);
```

---

## Step 3 — Concatenate TDT SEVs (gapless)

```matlab
tdt_merge_list_FQN = fullfile(SESSIONLOGS_dir, '2026', '260206', ...
	'20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01.mergedir', ...
	'merge_TDT_TANK_dir_list.txt');
fn_merge_TDT_TANKdirs_4_ULTRASort(tdt_merge_list_FQN);
```

If called with no args, the function’s hardcoded default list is used — **edit that or pass the FQN**.

Writes into the `.mergedir`:

- `TDT_TANKdir_merge_struct.mat` — per-tank `sr`, `samples_per_TANK`, channel names, source FQNs
- `merged_TANKdirs_chNNN.mat` — concatenated `cur_channel_data` (**no wall-clock gap**)
- `STAGE_fn_merge_TDT_TANKdirs_4_ULTRASort.finished`

Scaling notes (already in the merger): `single` SEV → µV with `1e6/4`; `int16` → `1/4`. ULTRASort later pretends Blackrock `BinSize` and multiplies back.

**Auto-preprocess:** `perform_ULTRASort_preprocessing = 1` currently calls `fn_ULTRASort_preprocess_TDT_SCP01_v03({mergedir})` at the end. If you need to edit array count / bad channels **before** filtering, set that flag to `0` and run step 4 yourself.

---

## Step 4 — ULTRASort preprocess / detect / cluster

```matlab
% from C:\SCP_CODE\Ephys\ULTRASort_Matlab
% adjust handles.par.numArray first (Elmo from 20260206: 4 arrays × 32 ch)
fn_ULTRASort_preprocess_TDT_SCP01_v03({mergedir_FQN});
% force a stage:
% fn_ULTRASort_preprocess_TDT_SCP01_v03({mergedir_FQN}, {'redo_SpikeSorting'});
```

Edit **before** running:

- `handles.par.numArray` — 4 (Elmo ≥ 20260206) vs 5 (160 ch)
- `bad_channel_list.txt` in the mergedir if known
- `redo_*` / `redo_request_list`: `redo_Filtering`, `redo_Denoising`, `redo_SpikeDetection`, `redo_SpikeSorting`, `redo_ALL`

Detection: merge list + `TDT_TANKdir_merge_struct.mat` present → `handles.par.sys = 'mergedTD'` and `handles.rawname = 'merged_TANKdirs_ch*.mat'`.

Stages (skip if `STAGE_<name>.finished` exists):

| Stage | Output |
|-------|--------|
| `SpikeFilterChan1` | `datafilt_ch*.mat` |
| `SpikeDenoiseChan1` | `datafilt2_ch*.mat` |
| `SpikeDetection1` | `dataspikes_ch*_negthr.mat`, `dataspikes_ch*_posthr.mat` (`index` = ms from concat t=0) |
| `SpikeFeaturesClustering1` | cluster IDs in those dataspikes files |

Also copies  
`unit_merge_and_reject_sheet.v01.20210309.160ch.neg.pos.<merged_session_id>.xlsx`  
from the SESSIONLOGS template (skips if already present).

---

## Step 5 — Manual sort + unit identity xlsx

Human-only. In the ULTRASort GUI, merge/reject clusters on the **gapless** `.mergedir` files. Fill the xlsx so cluster IDs in `dataspikes_*` map to unit identities.

Ephys code looks up:

```
unit_merge_and_reject_sheet.v01.20210309.160ch.neg.pos.<session_id>.xlsx
```

`<session_id>` must be the merged stem (`20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01`). Exclude `*template*.xlsx`. Attach with `'dataspikes'` **errors** if no non-template xlsx is in the mergedir.

Optional: `fn_resplit_merged_TDT_TANKdirs_AFTR_ULTRASort(tdt_merge_list_FQN)` slices `datafilt*` / `dataspikes*` back onto **source** tanks (subtracts segment offset from `index` / `cluster_class(:,2)`) and copies STAGE markers + a renamed xlsx. **Not required** for the merged-session wrapper path. Attach reads global clusters from `.mergedir`, not from resplit tanks.

---

## Step 6 — Attach sorted ephys to the merged CCF session

```matlab
merged_sessiondir_FQN = fullfile(SESSIONLOGS_dir, '2026', '260206', ...
	'20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir');

% cheap: headers + segment table + tbc_1 + GB estimate (no 160-ch I/O)
[synthetic_tank_FQN, tdt_ccf_segment_table] = fn_attach_TDT_data_to_merged_CCF_session( ...
	merged_sessiondir_FQN, {}, 'zero');

% analysis copies for MUA / spikes (gap-filled onto tbc_1)
[synthetic_tank_FQN, tdt_ccf_segment_table] = fn_attach_TDT_data_to_merged_CCF_session( ...
	merged_sessiondir_FQN, {'datafilt2', 'dataspikes'}, 'zero');
```

Accepts `.sessiondir`, `.mergedir`, or a merge-list `.txt`. Discovers the sibling by swapping the suffix.

Requires:

- `.sessiondir/merge_manifest.json`
- `.mergedir/TDT_TANKdir_merge_struct.mat` + `merge_TDT_TANK_dir_list.txt`
- per-source `timebase_conversion_BEHAVIOUR_EPHYS.mat`
- requested concat products in `.mergedir`

Creates:

```
<merged.sessiondir>/TDT/<prefix>-<YYMMDD>-000000/
```

Example: `SCP_DAG_v27_PZ04-260206-112316` → `SCP_DAG_v27_PZ04-260206-000000`.  
`fn_get_TDT_tank_ID_and_FQN_CCF` finds it because the folder still contains `SCP_` and `YYMMDD`.

Always-on (`{}` or any request list):

- copy/rename first-run `.tsq/.tev/.Tbk/.Tdx/.tin/.tnt` (stem swap → `-000000`); abort if `.tsq` or `.tev` missing
- copy merge list + `TDT_TANKdir_merge_struct.mat` (so `fn_read_sampling_information_from_TDT_SEV_file` can dive into source SEVs)
- copy ULTRASort sidecars (xlsx **as-is**, plots, covariance mats)
- write `tdt_ccf_segment_table.mat` (`i0,i1,n_k`, CCF spans, residuals)
- re-save **tbc_1** as `timebase_conversion_BEHAVIOUR_EPHYS.mat` (not `ccf - t0`)
- extend `merge_manifest.json` with `tdt_attach`
- `STAGE_<step>.finished` markers

Request tokens (any subset):

| Token | Source (gapless `.mergedir`) | Dest (gapped synthetic tank) |
|-------|------------------------------|------------------------------|
| `'merged_TANKdirs'` | `merged_TANKdirs_ch*.mat` | `merged_TANKdirs_chNNN.scaledSEV.mat` (`cur_channel_data`) |
| `'datafilt'` | `datafilt_ch*.mat` | same names; keep `par` |
| `'datafilt2'` | `datafilt2_ch*.mat` | same names; keep `par` (MUA default) |
| `'dataspikes'` | `dataspikes_ch*_negthr/posthr.mat` | remap `index` onto tbc_1 ms; add `ccf_timestamp_s`, `src_run_idx` |

Gap fill (`'zero'` default; aliases `'null'`/`'nulling'`): `'zero'` / `'mean'` / `'gaussian'` / `'nan'`.  
`'nan'` will **abort** current PETH (`~isfinite` guard). Storage: ~**28 GB per extra wall-clock hour per file type** at 160 ch int16 24.414 kHz. Hardlinks are out. `save` tries v7, falls back to `-v7.3`.

Do **not** copy SEVs. Do **not** concatenate `.tev`. Continuous samples are split from the `.mergedir` concat via `cumsum(samples_per_TANK)`, then placed at `i0(k)` on the tbc_1 axis.

Batch / smoke:

```matlab
run_test_fn_attach_TDT_data_to_merged_CCF_session          % always-on on 260319
run_attach_TDT_data_to_merged_CCF_sessions                 % default 260319, {}
run_attach_TDT_data_to_merged_CCF_sessions('all', {'datafilt2','dataspikes'}, 'zero')
```

---

## After attach — treat as a normal session

1. Parse the merged sessiondir (matcher `_02` is already wired). If attach copied tbc_1 without a QC PDF, force recalc (`create_timebase_conversion_between_CCF_and_EPHYS = 2`) once.

```matlab
[triallog_table, ~, record2D_struct] = fn_parse_CCF_data(merged_sessiondir_FQN, GAZE_OPTS_struct);
% record2D_table.run_idx, triallog_table.src_run_idx identify source runs
```

2. Event → sample index (unchanged math):

```matlab
tdt_s = convert(ccf_s, CCF, TDT, tbc_1)   % first-run TBC == merged TBC
idx   = round(tdt_s * sr)                 % no +1
```

Exclude collections within `pre_duration_ms` of a run boundary (gap samples).

3. Point `SCP_ephys_session_wrapper_20260817_CCF` (or a variant) at the **merged** `.sessiondir`, not the `.mergedir`.

Open follow-ups (do not block the procedure): MUA wildcard fallback when the tank has no SEVs (`merged_TANKdirs_ch*.scaledSEV.mat` / `datafilt2_ch*.mat`); first live parse of merged DO vs copied run-1 `.tev`. Copied tbc_1 is enough for MUA if parse skips recalc.

---

## Operator checklist

```
[ ] 1    Copy source .sessiondir trees into SESSIONLOGS/$YEAR/$YYMMDD/
[ ] 2.A  Create <stem>.mergedir + merge_TDT_TANK_dir_list.txt (tanks, chrono, no blanks)
[ ] 2.B  Create <stem>.sessiondir + list; run fn_merge_same_session_CCF_sessiondirs
[ ] 2.x  Parse each SOURCE session → TBC mat in each source tank
[ ] 3    fn_merge_TDT_TANKdirs_4_ULTRASort → merged_TANKdirs_ch*.mat (GAPLESS)
[ ] 4    Adjust numArray / bad channels; fn_ULTRASort_preprocess_TDT_SCP01_v03
[ ] 5    Manual cluster merge/reject; fill unit_merge_and_reject_sheet xlsx
[ ] 5.o  Optional: fn_resplit_merged_TDT_TANKdirs_AFTR_ULTRASort (source tanks only)
[ ] 6    fn_attach_TDT_data_to_merged_CCF_session ({} then datafilt2/dataspikes)
[ ] 7    Parse merged session; run SCP_ephys_session_wrapper_*_CCF on the .sessiondir
```

---

## Invariants (agents: do not violate)

1. `.mergedir` stays **gapless**. Wall-clock gaps belong only in `.sessiondir/TDT/…-000000`.
2. Merged TBC **is tbc_1**. Do not invent `merged_TDT = ccf - t0`.
3. Indexing is `round(tdt_s * sr)`, MATLAB 1-based; clamp run-1 start `0 → 1`. No global `+1`.
4. Do not re-run SpikeFilter / SpikeDetection / clustering on gapped files.
5. Do not concatenate or rewrite TDT `.tev` binaries. Copy run-1 headers only.
6. Do not copy `*_RSn*_ch*.sev` into the synthetic tank.
7. Do not call attach from `fn_merge_same_session_CCF_sessiondirs` by default.
8. Construct new FQNs with `fullfile` + `fn_get_SESSIONLOGS_dir_for_host`. Translate stored FQNs with `fn_load_stored_pathname` then exist-check. No hardcoded `Y:\` / `/Volumes/…`.
9. Preserve jsonl `type` as the first field; keep first-run `conf.json` for parser compat.
10. Copy merge_struct / merge lists **as stored** (do not bake this-host paths).
11. Known dataspikes fields only: `index`, `spikes`, `features`, `feature_names`, `tree`, `classtemp`, `par`, `cluster_class`. Error on unknowns.

---

## Why two merges exist

ULTRASort (`filtfilt`, MAD thresholds, covariance / ZCA) must see a continuous neural trace. Inserting minutes of zeros between runs would create edge artifacts and fake spikes.

Analysis selects events in CCF/unix time and maps them through **one** linear TBC (`tbc_1`) so existing `round(tdt_s * sr)` PETH/MUA code stays unchanged. Later runs are placed where an extrapolated run-1 TDT clock would put that unix time; holes are filled (`'zero'` default).

Resplit exists so individual source tanks can still be opened in ULTRASort / analyzed as sub-sessions. The merged wrapper does not need it.

---

## Related files

- Attach design / locked decisions: `CCF_merge_runs/PLAN_attach_TDT_to_merged_CCF_sessiondir.md`
- CCF merge skill: `.cursor/skills/ccf-merge-runs/SKILL.md`
- Ephys sync skill: `.cursor/skills/ccf-ephys-sync/SKILL.md`
- Path helper (outside this repo): `SCP_CODE/AuxiliaryFunctions/Matlab/fn_load_stored_pathname.m`
