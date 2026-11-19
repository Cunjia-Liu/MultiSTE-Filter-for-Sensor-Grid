# Static demonstration update

Based on public repository commit `46382779e824eeecadc0f8e23ff6ab3962f82f58`
and the final working functions developed for the paper revision.

## Scientific implementation

- `Plume_model.m`: use the newer model with the final-source Bessel cutoff
  disabled. Source superposition is no longer zeroed according to the last
  source in the list. Formula and other plume parameters are retained.
- `ClusterTransitionUpdate2.m`: retain all three matching coordinates
  `[x,y,5*Q]`; apply the same particle permutation in the matching cost and in
  the returned arrays. This incorporates the corrected extraction procedure.
  The particle tensor is constructed once, and an identical selected
  permutation is applied even when all particles happen to choose it.
- `EstimateCompute.m`: preserve weighted source-existence extraction, with
  threshold 0.5 by default. Expose that threshold as an optional argument and
  handle empty/zero-mass groups without dividing by zero. Additional output
  supplies aligned particles for plotting; filter particles are not reordered.
- `mergeCloseSourcesInParticles.m`: use the recovery-study correction that
  excludes inactive slots when searching for the closest active pair. Retain
  the original merge arithmetic and low-rate removal rule.
- `resample_PF.m`: use the working implementation with covariance calculations
  restricted to active slots, rather than the older public implementation.
  The residual resampling procedure is retained.
- `MultiSourceSTE_GOSPA.m`: preserve both existing metrics and add the working
  empty-estimate cardinality-penalty case.
- `ParticleTransition.m`: use the full/ablated transition switch from the
  working ablation code. Birth/death probabilities and the two merge thresholds
  are configurable with their existing defaults. The ablation retains random
  birth/death; death removes a uniformly selected active source.
- `LikelihoodUpdate.m`: keep the working likelihood and weight floor; expose
  its relative-noise coefficient (default 0.30) through the configuration.

## Demonstration organisation

- `main.m`, `mste_config.m` and `run_mste_demo.m` supply three single-trial
  examples. The old `MultiSTE_StaticSensorNetwork` command forwards to `main`.
- `source_configurations.m` contains the five four-source presets, checked
  against Table 1 and the saved working settings. Users can select a subset
  or supply their own source matrix and sensor positions.
- Recovery uses Q=[8,6,10], positions (17,33), (29,33), (37,17), and a prescribed
  two-source merged prior. Default recovery budget: 10,000 particles.
- There is one explicit number of observation batches, replacing ambiguous
  stopping settings in the public script. Sampling starts at t=0.
- Static setup, filter inference and estimate/plot extraction are separate.
  No planner, PHD estimator, GMM fit or Monte Carlo runner is added.
- Initial/final distributions and P(M=true count)/joint-GOSPA curves use the
  saved data. PNG and FIG exports avoid the prior PDF export slowdown.
- Measurement noise and extraction no longer consume filter random numbers.
  The ablation pair shares the initial prior and identical saved readings.
  This changes the random sequence relative to old scripts, not the model;
  the examples are demonstrations, not bitwise replays of paper MC runs.
- Inference and extraction times are stored separately. The output also
  preserves `tvec`, `ste_esterrorvec` and `stePose_esterrorvec` within each run.
- Existing legacy plotting helpers are retained for compatibility; the new
  demos use `plot_mste_results.m` for final summary figures.

## Optional animation and attribution update

- `cfg.plot.live` enables live filtering animation using the original
  `mste_figplot_initial` and `mste_figplot_set` helpers. The default is off.
  Refresh frequency and an optional viewing pause are configurable.
- `mste_live_plot.m` adapts the existing extracted posterior for rendering,
  without repeating clustering or changing the filter random state. Closing
  the window lets inference continue without further rendering for that trial.
- Stale source artists are cleared when no estimate passes the existence
  threshold. Display limits support custom domains and release rates.
- Existing configuration files remain usable: missing animation options receive
  defaults in `run_mste_demo.m`. The incremental animation ZIP leaves `main.m`
  and `mste_config.m` untouched so local settings are preserved.
- No transition, likelihood, resampling, extraction or GOSPA calculation is
  changed by this animation update. Rendering is outside the recorded timers.
- `AUTHORS.md` records original software authorship and AI-assisted preparation.
  `CITATION.cff` distinguishes the two confirmed software authors from the four
  authors of the associated paper.

## Validation status

The initial 24-file package passed MISS_HIT syntax/lint checks. The five presets were
compared exactly against the saved working MATLAB settings. Executable lines of
the plume, resampler, both merge helpers and GOSPA function were compared against
their working reference versions. The corrected matching formula was also
checked independently across all six three-source permutations.

The maintainer subsequently confirmed that the demonstration package works in
MATLAB. All 25 MATLAB files, including the animation update, passed MISS_HIT
syntax/lint checks. The new animation requires a separate graphics check in MATLAB;
the preparation environment has no MATLAB runtime. The optional
`check_mste_demo` does not run Monte Carlo experiments or exercise live graphics.
