% MAIN Single-run MSTE demonstrations. Change the example/settings below.
% 'standard': estimation from a broad prior
% 'ablation': full versus merge/removal disabled, same observations and prior
% 'recovery': initial two-source belief representing three true sources
projectDir = fileparts(mfilename('fullpath'));
addpath(projectDir,fullfile(projectDir,'Functions'));
cfg = mste_config('standard');


cfg.plot.live = true;        % false disables animation
cfg.plot.updateEvery = 2;    % display every update; try 5 for less overhead
cfg.plot.pauseSeconds = 0.01;% set to 0 for no deliberate pause

% Optional overrides (or edit mste_config.m):
% cfg.sourceConfig = 3;
% cfg.Np = 10000;
% cfg.wind.directionDeg = 90;
% cfg.transition.mergeFrac = 0.075;
% cfg.sourceMode = 'custom';
% cfg.customSources = [8 6 10; 17 29 37; 33 33 17]; % [Q; x; y]

result = run_mste_demo(cfg);
