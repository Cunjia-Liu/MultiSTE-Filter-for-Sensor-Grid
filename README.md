# MultiSTE filter for a static sensor network

MATLAB demonstrations of a joint-state particle filter for estimating the
**number, positions and release rates of multiple gas sources** from superposed
concentration measurements. The joint source-state representation supports
physics-informed merging/removal alongside source birth and death.

The filter is associated with:

**Mr.MSTE: Multi-robot Multi-Source Term Estimation with Wind-Aware Coverage Control**
Rohit V. Nanavati, Timothy J. Glover, Matthew J. Coombes and Cunjia Liu.
[Paper / preprint](https://arxiv.org/abs/2512.17001)

This release demonstrates the working principles of the filter through three
single-trial examples. It includes five predefined source configurations and
editable settings. Monte Carlo batch runners, the PHD baseline and robot planning
are outside the scope of this release. Its plots are **single-trial results**,
not the averaged results reported in the paper.

## Requirements

- MATLAB with **Statistics and Machine Learning Toolbox** (`gamrnd`, `kmeans`,
  `mvnpdf`, `cholcov`, `prctile`).
- The code targets MATLAB R2024b, the version used for the research runs.
  The maintainer has confirmed that the reorganised demonstrations run in MATLAB.
  The optional live-animation update still needs a MATLAB graphics check.
- No Parallel Computing, Mapping or Robotics toolbox is needed by the new demos.

## Quick start

Open the repository folder in MATLAB, then run:

```matlab
main
```

`main.m` selects the example and calls the configuration and runner. It leaves
`cfg` and `result` in the workspace. The previous command
`MultiSTE_StaticSensorNetwork` still works and forwards to `main`.

To select an example directly:

```matlab
cfg = mste_config('standard');   % broad prior
result = run_mste_demo(cfg);

cfg = mste_config('ablation');   % full and merge/removal-disabled filter
result = run_mste_demo(cfg);

cfg = mste_config('recovery');   % concentrated merged two-source belief
result = run_mste_demo(cfg);
```

The standard and ablation defaults use 25,000 particles and 41 observation
batches at 0, 5, ..., 200 s. The recovery default uses 10,000 particles and
50 batches at 0, 5, ..., 245 s. Reduce `cfg.Np`, for example to 10,000, for a
quicker standard demonstration. Changing the particle budget changes the trial;
this package does not assert equivalence between different budgets.

## Configuration

Edit `mste_config.m`, or override its returned struct **before** calling
`run_mste_demo`. Running `main` again recreates `cfg` from the settings in that
script, so overrides entered at the command prompt should be followed by
`run_mste_demo(cfg)` directly.

| Setting | Meaning |
|---|---|
| `cfg.sourceConfig` | One of the five presets, numbered 1 to 5 |
| `cfg.nTrueSources` | First 1 to 4 sources from that preset |
| `cfg.Mmax` | Maximum number represented by each joint particle |
| `cfg.Np` | Number of joint particles |
| `cfg.wind.directionDeg` | Downwind direction from +x, e.g. -90 or +90 degrees |
| `cfg.sensors.gridSize` | Sensor counts along x and y; default `[6 6]` |
| `cfg.nUpdates` | Number of observation batches, including the batch at t=0 |
| `cfg.samplingInterval` | Time between batches, default 5 s |
| `cfg.transition.mergeFrac` | Deterministic merge threshold / domain diagonal |
| `cfg.transition.deathMergeFrac` | Separate close-pair threshold inside a death event |
| `cfg.existenceThreshold` | Weighted source-existence threshold for extraction |
| `cfg.seed` | Random seed controlling this demonstration |
| `cfg.makePlots`, `cfg.saveResults` | Enable final summary plots and result saving |
| `cfg.plot.live` | Animate filtering; default `false` |
| `cfg.plot.updateEvery` | Render every N updates; default 1 |
| `cfg.plot.pauseSeconds` | Additional viewing pause per frame; default 0.05 s |

For 300 s of data at a 5 s interval, set `cfg.nUpdates=61`. The first measurement
is at t=0. The unobserved initial prior is stored separately, at update k=0.

```matlab
cfg = mste_config('standard');
cfg.sourceConfig = 4;
cfg.nTrueSources = 4;
cfg.Mmax = 5;
cfg.Np = 10000;
cfg.wind.directionDeg = 90;
cfg.nUpdates = 61;
result = run_mste_demo(cfg);
```

The five presets match Table 1 of the paper. Each source matrix has rows
`[Q; x; y]`, with Q in g/s and positions in metres. The first `nTrueSources`
columns are used. A custom matrix determines its own true source count:

```matlab
cfg = mste_config('standard');
cfg.sourceMode = 'custom';
cfg.customSources = [8 6 10; 17 29 37; 33 33 17]; % rows [Q; x; y]
cfg.Mmax = 4;
result = run_mste_demo(cfg);
```

Custom sensor positions are N-by-2, one `[x y]` row per sensor:

```matlab
cfg.sensors.customPositions = [5 10; 20 10; 35 10; 45 10];
```

Sources and sensors must lie within `xlimits` and `ylimits`. Changing domain
limits does not automatically rescale the source presets. The demonstration
limits `Mmax` to 6 because the retained extraction routine explicitly enumerates
source-slot permutations; its cost increases factorially with `Mmax`.

## What the examples demonstrate

### Standard estimation

Locations have a broad uniform prior, release rates have a Gamma(2,5) prior,
and particle source counts are uniform on 1,...,Mmax. The filter receives
concentration readings from the fixed sensor network and updates the joint
posterior. True source locations, rates and count are used only by the simulator,
evaluation and figures, not passed into the filter.

### Ablation

Runs the full filter and the same filter with the physics-informed merge/removal
rules disabled. Both receive **identical initial particles and measurements**.
Birth/death event probabilities, plume likelihood, process noise, resampling and
extraction are shared. In the disabled variant, a death event removes a uniformly
selected active source; deterministic merging and low-rate removal are bypassed.
The other physical information, including the plume model, remains present.

This is one stochastic comparison, not a guarantee that one method will have
lower error in every individual trial. No mean, confidence band or MC claim is
attached to the resulting curves.

### Recovery from a merged belief

Uses three true sources at `(17,33)`, `(29,33)`, `(37,17)` m with release rates
8, 6 and 10 g/s. The first two are separated by 12 m. Every initial particle has
only two active sources: one around the release-rate-weighted centroid
`(22.1429,33)` with combined rate 14 g/s, and the remaining source around
`(37,17)` with rate 10 g/s. Initial standard deviations in `[x,y,Q]` are
`[0.75,0.75,0.5]`, with samples restricted to the domain and positive Q.

This deliberately prescribed prior tests whether birth and subsequent updates
can recover from a concentrated merged hypothesis. It does not simulate a
preceding online merge event. Recovery is stochastic and is not guaranteed for
every parameter choice or seed.

The default merge threshold is 10% of the 50-by-50 m domain diagonal, or 7.07 m.
Change `cfg.transition.mergeFrac` to 0.075, 0.125 or 0.15 to explore sensitivity
in additional single runs. The separate death-event threshold remains 0.15 unless
explicitly changed. The recovery source layout is separate from the five presets;
select `sourceMode='custom'` to supply a different three-source recovery layout.

## Outputs and plots

### Optional live animation

The original plotting functions can display the evolving source-position clouds,
release-rate histograms and extracted estimates during filtering:

```matlab
cfg = mste_config('standard');   % also works with 'ablation' or 'recovery'
cfg.plot.live = true;
cfg.plot.updateEvery = 1;        % use 2 or 5 to reduce rendering overhead
cfg.plot.pauseSeconds = 0.05;    % set to 0 to remove the deliberate pause
result = run_mste_demo(cfg);
```

Alternatively, add these overrides in `main.m`, after creating `cfg` and before
calling the runner. Animation is off by default and increases total elapsed time.
It is independent of `cfg.makePlots`, which controls the final summary figures.
Closing a live window disables animation for the remainder of that trial;
filtering continues. Ablation creates a separate window for each variant.

The live display uses the existing `mste_figplot_initial` and `mste_figplot_set`
helpers. It displays sources that pass the configured existence threshold,
with at most `cfg.plot.maxParticles` plotted points per source. Colours identify
the current extraction groups and may change between updates. Rendering uses
the already-extracted posterior, preserves the filter random state, and is
excluded from the recorded inference and extraction timings. It does not save
a video or full particle history.

### Saved results

Each invocation saves in a new folder under `Results/`, containing:

- `demo_result.mat`: resolved configuration, true sources, exact sensor readings,
  observation times, initial/final distributions, extracted estimates, metrics
  and per-update inference/extraction timings.
- An initial-distribution figure and one final-distribution figure per variant,
  with matching release-rate histogram and spatial plot widths.
- A two-panel plot of posterior probability of the true source count and
  joint-state GOSPA. Exports are PNG and editable FIG, with no automatic PDF.

Only initial and final particle populations are retained; full particle history
is unnecessary for these demonstrations. The distribution plots use weighted
conditional rate histograms and a bounded, deterministic weighted particle
display. Colours identify local extraction groups, not persistent source IDs.

Replot without rerunning inference:

```matlab
plot_mste_results(result)
% Or choose a previously saved demo_result.mat:
plot_mste_results
```

Joint-state GOSPA uses the existing unscaled `[x,y,Q]` convention, p=2,
alpha=2 and cutoff 50; it is not labelled in metres. Position-only GOSPA is
also stored, with cutoff 20. `P(M=m)` is computed from all particle weights
before resampling; it is not a recovery success rate. Source extraction aligns
the slots and retains sources whose weighted existence exceeds 0.5 by default,
then computes their conditional means. It does not select the MAP source count.

`result.runs{r}.ste_esterrorvec`, `stePose_esterrorvec` and `tvec` retain familiar
post-observation output names. The newer `jointGOSPA`, `positionGOSPA` and
`cardinalityProbability` arrays additionally include the prior in their first row.
For recovery, prior GOSPA uses the prescribed prior centres.

Inference timings include transition, likelihood and resampling, and exclude
estimate extraction, metric evaluation, plotting and saving. Extraction timing
is recorded separately. These are elapsed times on the machine running the demo.

## Filter interface and later mobile sensing

`PFupdateSimple` takes a particle population, weights, a vector of measurements
and their N-by-2 sensing positions. Its parameter struct contains plume and
transition settings, with no true source coordinates or rates. It returns the
updated particle population and weights; optional diagnostic output includes
cardinality probabilities and inference time.

The static grid is constructed in `mste_scene`, outside the filter. A later
mobile planner can use the posterior to choose new sensor positions and call
the same filter again. Coverage-density construction and control would remain
separate from inference. No GMM is fitted by this release.

Observation noise has its own random stream. Extraction temporarily uses a
separate seeded RNG state and restores the filter state afterward. Plotting
consumes no random numbers. Seeded runs are repeatable in the same MATLAB
environment, but are not expected to be bit-for-bit identical to old research
scripts that interleaved planner/GMM and extraction random draws.

## Working from MATLAB and GitHub

In MATLAB R2023b or later, start in the parent folder where you want the checkout:

```matlab
repo = gitclone("https://github.com/Cunjia-Liu/MultiSTE-Filter-for-Sensor-Grid.git");
cd(repo.WorkingFolder)
```

Alternatively use the Current Folder / Files panel's Source Control menu to
clone the repository (the menu wording varies by MATLAB version).

If applying the accompanying update ZIP to an existing checkout, unzip its
contents directly into `repo.WorkingFolder`, replacing the listed source files.
The ZIP contains no `.git` folder and preserves your checkout's Git history.
Then run `check_mste_demo`, followed by the three examples. Review the changes
in MATLAB Source Control or GitHub Desktop, commit them locally, then push to
GitHub when satisfied. A normal save in MATLAB does not publish anything.

See [MathWorks gitclone documentation](https://www.mathworks.com/help/matlab/ref/gitclone.html)
and [Git collaboration in MATLAB](https://www.mathworks.com/help/matlab/matlab_prog/collaborate-using-git-in-matlab.html).

## Implementation notes

See `CHANGES.md` for the source corrections and packaging changes. The optional
`check_mste_demo` covers plume superposition, permutation alignment, merging with
inactive slots, empty-estimate GOSPA and small runs through all three entry paths.
It is provided for execution in MATLAB; the preparation environment has no
MATLAB runtime. No newly generated simulation results are bundled.

If you use the filter, please cite the associated paper. `CITATION.cff` provides
the author list and preprint link. The original `brewermap.m` attribution and
licence header are retained.

## Credits

Original software: **Rohit V. Nanavati and Cunjia Liu**. Maintainer: **Cunjia Liu**.
Updates to the demonstrations, debugging, plotting and documentation were
prepared with assistance from OpenAI ChatGPT/Codex. Human contributors retain
responsibility for scientific decisions, code review and validation.

See [AUTHORS.md](AUTHORS.md) for attribution and contribution-history guidance.
The associated paper's four-author citation is retained in `CITATION.cff`.
