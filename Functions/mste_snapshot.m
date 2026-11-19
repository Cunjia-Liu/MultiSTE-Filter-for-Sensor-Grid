function snapshot = mste_snapshot(theta,weights,cfg,k)
%MSTE_SNAPSHOT Extraction and display grouping without changing filter RNG.
previousRng = rng;
restoreRng = onCleanup(@() rng(previousRng)); %#ok<NASGU>
rng(mod(cfg.seed+100000+k,2^32),'twister');
[estimate,confidence,~,existence,~,~,aligned] = ...
    EstimateCompute(theta,weights,cfg.existenceThreshold);
snapshot = struct('particles',aligned,'weights',weights,'estimate',estimate, ...
    'confidence',confidence,'existence',existence/100,'update',k);
end
