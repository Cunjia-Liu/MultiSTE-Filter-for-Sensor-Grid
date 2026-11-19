function result = run_mste_demo(cfg)
%RUN_MSTE_DEMO Run one standard/recovery trial or one matched ablation pair.
% No Monte Carlo loop, planner, PHD estimator or GMM fitting is required.
root = fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'Functions'));
if nargin<1, cfg=mste_config('standard'); end
% Older configuration files remain usable with this optional display update.
plotDefaults = struct('live',false,'updateEvery',1,'pauseSeconds',0.05);
plotFields = fieldnames(plotDefaults);
for j=1:numel(plotFields)
    if ~isfield(cfg.plot,plotFields{j})
        cfg.plot.(plotFields{j}) = plotDefaults.(plotFields{j});
    end
end
validateattributes(cfg.plot.live,{'logical','numeric'},{'scalar','binary'});
validateattributes(cfg.plot.updateEvery,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(cfg.plot.pauseSeconds,{'numeric'},{'scalar','nonnegative','finite'});
cfg.example = validatestring(cfg.example,{'standard','ablation','recovery'});
assert(exist('kmeans','file')==2 && exist('gamrnd','file')==2, ...
    'Statistics and Machine Learning Toolbox is required (kmeans, gamrnd).');
previousRng = rng;
restoreRng = onCleanup(@() rng(previousRng)); %#ok<NASGU>
scene = mste_scene(cfg);
if strcmp(cfg.example,'ablation')
    flags = [true,false];
    labels = {'Full MSTE','MSTE without physics-informed merge/removal'};
else
    flags = logical(cfg.transition.enableMergeRemoval);
    if flags, labels={'Full MSTE'}; else, labels={'MSTE without physics-informed merge/removal'}; end
end
result = struct('cfg',cfg,'truth',scene.truth,'sources',scene.sources, ...
    'sensorPositions',scene.positions,'measurements',scene.measurements, ...
    'observationTimes',scene.times,'runs',{{}},'outputFolder','');
for r=1:numel(flags)
    trialCfg = cfg;
    trialCfg.transition.enableMergeRemoval = flags(r);
    model = scene.model; model.enableMergeRemoval = flags(r);
    rng(cfg.seed,'twister'); % identical initial particles for the ablation pair
    [theta,weights,priorCentres] = mste_initialise(cfg,scene);
    initial = mste_snapshot(theta,weights,cfg,0);
    initial.priorCentres = priorCentres;
    if ~isempty(priorCentres)
        initial.estimate.mean = priorCentres; % prescribed recovery-prior centres
    end
    runData = struct('label',labels{r},'cfg',trialCfg,'initial',initial);
    runData.update = 0:cfg.nUpdates;
    runData.cardinalityProbability = zeros(cfg.nUpdates+1,cfg.Mmax+1);
    runData.cardinalityProbability(1,:) = accumarray(sum(theta.mask~=0,2)+1, ...
        weights,[cfg.Mmax+1,1],@sum,0).';
    runData.estimates = cell(cfg.nUpdates+1,1);
    runData.estimates{1} = initial.estimate.mean;
    priorError = MultiSourceSTE_GOSPA(initial.estimate.mean,scene.truth);
    runData.jointGOSPA = [priorError.EstError;zeros(cfg.nUpdates,1)];
    runData.positionGOSPA = [priorError.EstPoseError;zeros(cfg.nUpdates,1)];
    runData.inferenceSeconds = zeros(cfg.nUpdates,1);
    runData.extractionSeconds = zeros(cfg.nUpdates,1);
    fprintf('\n%s: %d particles, %d sensors, %d true sources, Mmax=%d\n', ...
        labels{r},cfg.Np,size(scene.positions,1),numel(scene.truth.Q),cfg.Mmax);
    liveState = [];
    if cfg.plot.live
        liveState = mste_live_plot(initial,scene,cfg,liveState,labels{r},0);
    end
    for k=1:cfg.nUpdates
        [theta,weights,info] = PFupdateSimple(theta,weights,scene.measurements(:,k), ...
            scene.positions,cfg.Np,cfg.sensor.detectionThreshold,model, ...
            cfg.sensor.detectionProbability,cfg.transition.sigma,scene.domain);
        tExtract = tic;
        snapshot = mste_snapshot(theta,weights,cfg,k);
        runData.extractionSeconds(k) = toc(tExtract);
        errorValue = MultiSourceSTE_GOSPA(snapshot.estimate.mean,scene.truth);
        runData.cardinalityProbability(k+1,:) = info.cardinalityProbability;
        runData.estimates{k+1} = snapshot.estimate.mean;
        runData.jointGOSPA(k+1) = errorValue.EstError;
        runData.positionGOSPA(k+1) = errorValue.EstPoseError;
        runData.inferenceSeconds(k) = info.inferenceSeconds;
        if k==1 || mod(k,5)==0 || k==cfg.nUpdates
            fprintf('  Update %d/%d, t=%g s: GOSPA %.3f, P(M=%d)=%.3f\n', ...
                k,cfg.nUpdates,scene.times(k),errorValue.EstError,numel(scene.truth.Q), ...
                info.cardinalityProbability(numel(scene.truth.Q)+1));
        end
        if cfg.plot.live && (k==1 || mod(k,cfg.plot.updateEvery)==0 || k==cfg.nUpdates)
            liveState = mste_live_plot(snapshot,scene,cfg,liveState,labels{r},scene.times(k));
        end
    end
    runData.final = snapshot;
    runData.finalParticles = theta;
    runData.finalWeights = weights;
    % Familiar fields, containing post-observation values only.
    runData.tvec = scene.times;
    runData.ste_esterrorvec = runData.jointGOSPA(2:end).';
    runData.stePose_esterrorvec = runData.positionGOSPA(2:end).';
    result.runs{r} = runData;
    fprintf('Mean inference %.4f s per batch of %d readings.\n', ...
        mean(runData.inferenceSeconds),size(scene.positions,1));
end
if cfg.saveResults
    if ~isfolder(cfg.outputRoot), mkdir(cfg.outputRoot); end
    result.outputFolder = [tempname(cfg.outputRoot) '_' cfg.example];
    mkdir(result.outputFolder);
    save(fullfile(result.outputFolder,'demo_result.mat'),'result','-v7.3');
    fprintf('Saved results: %s\n',result.outputFolder);
end
if cfg.makePlots, plot_mste_results(result); end
end
