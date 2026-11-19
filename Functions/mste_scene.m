function scene = mste_scene(cfg)
%MSTE_SCENE Validate a demonstration and generate its fixed observations.
% Observation noise uses a separate stream, so both ablation variants receive
% exactly the same readings regardless of filter random-number consumption.
validateattributes(cfg.Np,{'numeric'},{'scalar','integer','>=',cfg.Mmax,'finite'});
validateattributes(cfg.Mmax,{'numeric'},{'scalar','integer','>=',1,'<=',6});
validateattributes(cfg.seed,{'numeric'},{'scalar','integer','>=',0,'<=',2^32-1000000});
validateattributes(cfg.nUpdates,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(cfg.samplingInterval,{'numeric'},{'scalar','positive','finite'});
validateattributes(cfg.xlimits,{'numeric'},{'vector','numel',2,'finite','increasing'});
validateattributes(cfg.ylimits,{'numeric'},{'vector','numel',2,'finite','increasing'});
assert(diff(cfg.xlimits)>0 && diff(cfg.ylimits)>0,'Domain limits must increase.');
validateattributes(cfg.wind.speed,{'numeric'},{'scalar','nonnegative','finite'});
validateattributes(cfg.wind.directionDeg,{'numeric'},{'scalar','finite'});
validateattributes(cfg.plume.diffusivity,{'numeric'},{'scalar','positive','finite'});
validateattributes(cfg.plume.lifetime,{'numeric'},{'scalar','positive','finite'});
validateattributes(cfg.sensor.detectionThreshold,{'numeric'},{'scalar','positive','finite'});
validateattributes(cfg.sensor.detectionProbability,{'numeric'},{'scalar','>=',0,'<=',1});
validateattributes(cfg.sensor.noiseFraction,{'numeric'},{'scalar','nonnegative','finite'});
validateattributes(cfg.existenceThreshold,{'numeric'},{'scalar','>=',0,'<',1});
validateattributes(cfg.transition.birthProbability,{'numeric'},{'scalar','>=',0,'<=',1});
validateattributes(cfg.transition.deathProbability,{'numeric'},{'scalar','>=',0,'<=',1});
assert(cfg.transition.birthProbability+cfg.transition.deathProbability<=1, ...
    'Birth and death probabilities must sum to at most one.');
validateattributes(cfg.transition.mergeFrac,{'numeric'},{'scalar','>=',0,'<=',1});
validateattributes(cfg.transition.deathMergeFrac,{'numeric'},{'scalar','>=',0,'<=',1});
validateattributes(cfg.transition.minReleaseRate,{'numeric'},{'scalar','nonnegative','finite'});
validateattributes([cfg.transition.sigma.x cfg.transition.sigma.y cfg.transition.sigma.Q], ...
    {'numeric'},{'vector','numel',3,'positive','finite'});
validateattributes(cfg.plot.maxParticles,{'numeric'},{'scalar','integer','positive'});
if ~isempty(cfg.plot.qLimits)
    validateattributes(cfg.plot.qLimits,{'numeric'},{'vector','numel',2,'finite','increasing'});
    assert(diff(cfg.plot.qLimits)>0,'Release-rate plot limits must increase.');
end

switch lower(cfg.sourceMode)
    case 'preset'
        S = source_configurations(cfg.sourceConfig,cfg.nTrueSources);
    case 'custom'
        S = cfg.customSources;
    case 'recovery'
        S = [8 6 10; 17 29 37; 33 33 17];
    otherwise
        error('MSTE:SourceMode','Choose sourceMode preset, custom or recovery.');
end
validateattributes(S,{'numeric'},{'2d','nrows',3,'nonempty','real','finite'});
assert(all(S(1,:)>0),'True release rates must be positive.');
assert(size(S,2)<=cfg.Mmax,'Mmax must cover the number of true sources.');
xlim = cfg.xlimits; ylim = cfg.ylimits;
assert(all(S(2,:)>=xlim(1) & S(2,:)<=xlim(2)) && ...
    all(S(3,:)>=ylim(1) & S(3,:)<=ylim(2)), 'True sources must lie in the domain.');
if strcmp(cfg.example,'recovery')
    assert(size(S,2)==3,'The recovery example requires three true sources.');
    pair = cfg.recovery.mergePair;
    assert(numel(pair)==2 && numel(unique(pair))==2 && all(ismember(pair,1:3)), ...
        'recovery.mergePair must contain two different source indices.');
    validateattributes(cfg.recovery.initialStd,{'numeric'}, ...
        {'row','numel',3,'positive','finite'});
end
scene.sources = S;
scene.truth = struct('Q',S(1,:),'x',S(2,:),'y',S(3,:));
scene.domain = polyshape([xlim(1) xlim(2) xlim(2) xlim(1)], ...
    [ylim(1) ylim(1) ylim(2) ylim(2)]);

if isempty(cfg.sensors.customPositions)
    validateattributes(cfg.sensors.gridSize,{'numeric'},{'vector','numel',2,'integer','>=',2});
    margin = cfg.sensors.margin;
    validateattributes(margin,{'numeric'},{'scalar','nonnegative','finite'});
    assert(2*margin<min([diff(xlim),diff(ylim)]),'Sensor margin is too large.');
    [X,Y] = meshgrid(linspace(xlim(1)+margin,xlim(2)-margin,cfg.sensors.gridSize(1)), ...
        linspace(ylim(1)+margin,ylim(2)-margin,cfg.sensors.gridSize(2)));
    scene.positions = [X(:),Y(:)];
else
    scene.positions = cfg.sensors.customPositions;
    validateattributes(scene.positions,{'numeric'},{'2d','ncols',2,'nonempty','real','finite'});
    assert(all(scene.positions(:,1)>=xlim(1) & scene.positions(:,1)<=xlim(2)) && ...
        all(scene.positions(:,2)>=ylim(1) & scene.positions(:,2)<=ylim(2)), ...
        'Sensor positions must lie in the domain.');
end

% This parameter struct contains NO true source locations or release rates.
model = struct('u',cfg.wind.speed,'phi',deg2rad(cfg.wind.directionDeg), ...
    'ci',cfg.plume.diffusivity,'cii',cfg.plume.lifetime, ...
    'noiseFraction',cfg.sensor.noiseFraction);
names = {'enableMergeRemoval','birthProbability','deathProbability', ...
    'mergeFrac','deathMergeFrac','minReleaseRate'};
for i=1:numel(names), model.(names{i}) = cfg.transition.(names{i}); end
scene.model = model;
scene.times = (0:cfg.nUpdates-1)*cfg.samplingInterval;
scene.meanConcentration = Plume_model(scene.truth,scene.positions,model);
assert(all(isfinite(scene.meanConcentration)),'Plume predictions must be finite.');
stream = RandStream('mt19937ar','Seed',cfg.seed+1);
N = size(scene.positions,1);
scene.measurements = zeros(N,cfg.nUpdates);
for k=1:cfg.nUpdates
    z = scene.meanConcentration .* (1+cfg.sensor.noiseFraction*randn(stream,N,1));
    z(z<cfg.sensor.detectionThreshold) = 0;
    z(rand(stream,N,1)<=1-cfg.sensor.detectionProbability) = 0;
    scene.measurements(:,k) = z;
end
end
