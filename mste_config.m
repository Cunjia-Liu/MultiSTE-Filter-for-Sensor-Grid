function cfg = mste_config(example)
%MSTE_CONFIG Settings for one demonstration. Edit here or override returned cfg.
% Example: cfg=mste_config('standard'); cfg.sourceConfig=2; run_mste_demo(cfg);
if nargin < 1, example = 'standard'; end
cfg.example = validatestring(example,{'standard','ablation','recovery'});
cfg.seed = 1001;
cfg.Np = 10000;             % particles; try 10000 for a faster demonstration
cfg.Mmax = 4;               % maximum inferred source count, NOT true count
cfg.nUpdates = 41;          % observations at 0:5:200 s; prior is stored separately
cfg.samplingInterval = 5;   % seconds between observation batches
cfg.xlimits = [0 50];       % metres
cfg.ylimits = [0 50];

% Source setup: rows [Q; x; y], one column per true source.
cfg.sourceMode = 'preset'; % 'preset', 'custom', or dedicated 'recovery' case
cfg.sourceConfig = 1;       % choose one of five source_configurations
cfg.nTrueSources = 3;       % first 1, 2, 3 or 4 columns of the selected preset
cfg.customSources = [8 6 10; 17 29 37; 33 33 17];

% Static grid. An N-by-2 customPositions matrix overrides the grid.
cfg.sensors.gridSize = [6 6]; % [number along x, number along y]
cfg.sensors.margin = 0;      % metres inside each domain boundary
cfg.sensors.customPositions = [];

% Transport and sensing. Wind direction is downwind from +x.
cfg.wind.speed = 4;          % m/s
cfg.wind.directionDeg = -90; % use +90 for the other direction
cfg.plume.diffusivity = 1.2;
cfg.plume.lifetime = 5;
cfg.sensor.detectionThreshold = 5e-4;
cfg.sensor.detectionProbability = 0.95;
cfg.sensor.noiseFraction = 0.2; % also used in likelihood

% Transition thresholds are fractions of the DOMAIN DIAGONAL.
cfg.transition.enableMergeRemoval = true;
cfg.transition.birthProbability = 0.10;
cfg.transition.deathProbability = 0.08;
cfg.transition.mergeFrac = 0.10;
cfg.transition.deathMergeFrac = 0.15;
cfg.transition.minReleaseRate = 0.75;
cfg.transition.sigma = struct('x',1,'y',0.5,'Q',0.3);
cfg.existenceThreshold = 0.5; % retain sources with weighted existence > this

% Controlled merged-belief prior for the recovery example.
cfg.recovery.mergePair = [1 2];
cfg.recovery.initialStd = [0.75 0.75 0.5]; % [x,y,Q], truncated Gaussian
if strcmp(cfg.example,'recovery')
    cfg.sourceMode = 'recovery';
    cfg.Np = 10000;
    cfg.nUpdates = 50;
end

cfg.makePlots = true;
cfg.plot.maxParticles = 1500; % display only; inference uses all Np
cfg.plot.qLimits = [];       % [] sets common initial/final plot limits
cfg.saveResults = true;
cfg.outputRoot = fullfile(fileparts(mfilename('fullpath')),'Results');
% Exports: PNG and editable FIG. No automatic PDF export.
end
