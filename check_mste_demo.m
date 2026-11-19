function check_mste_demo
%CHECK_MSTE_DEMO Small correctness checks; no Monte Carlo simulation.
% Run in MATLAB with Statistics and Machine Learning Toolbox installed.
root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'Functions'));
oldRng=rng; restore=onCleanup(@() rng(oldRng)); %#ok<NASGU>
rng(7,'twister');

% The plume must add contributions independently of source order. A distant
% final source must not zero the contribution of a nearer source.
model=struct('u',0,'phi',0,'ci',1.2,'cii',5);
s=struct('x',[1 200],'y',[1 200],'Q',[8 6]);
z=Plume_model(s,[2 2],model);
reversed=struct('x',fliplr(s.x),'y',fliplr(s.y),'Q',fliplr(s.Q));
zReverse=Plume_model(reversed,[2 2],model);
zSum=0;
for j=1:2
    one=struct('x',s.x(j),'y',s.y(j),'Q',s.Q(j));
    zSum=zSum+Plume_model(one,[2 2],model);
end
assert(z>0 && abs(z-zReverse)<1e-12 && abs(z-zSum)<1e-12, ...
    'Plume superposition/source-order check failed.');

% Exercise all permutations, including non-self-inverse three-cycles.
truth=[3 1 1; 5 20 10; 8 40 40]; % rows are [Q,x,y] here
orders=repmat(perms(1:3),2,1); N=size(orders,1);
p=struct('x',zeros(N,3),'y',zeros(N,3),'Q',zeros(N,3),'mask',ones(N,3));
for i=1:N
    p.x(i,:)=truth(orders(i,:),2).'; p.y(i,:)=truth(orders(i,:),3).';
    p.Q(i,:)=truth(orders(i,:),1).';
end
aligned=ClusterTransitionUpdate2(p);
assert(max(abs(aligned.x-aligned.x(1,:)),[],'all')<1e-12 && ...
    max(abs(aligned.Q-aligned.Q(1,:)),[],'all')<1e-12,'Permutation alignment failed.');
estimate=EstimateCompute(p,ones(N,1)/N);
assert(max(abs(sortrows(estimate.mean)-sortrows(truth(:,[2 3 1]))),[],'all')<1e-12, ...
    'Extraction must recover an identical source set from permuted particles.');

% An inactive nearest neighbour must not hide a close active pair.
domain=polyshape([0 50 50 0],[0 0 50 50]);
q=struct('x',[10 13 10.01],'y',[10 10 10],'Q',[7 6 0],'mask',[1 1 0]);
merged=mergeCloseSourcesInParticles(q,domain,0.1,0.75);
assert(sum(merged.mask)==1 && abs(sum(merged.Q.*merged.mask)-13)<1e-12, ...
    'Active-pair merging failed.');

% Disabling both events and merge/removal must preserve source count.
cfg=mste_config('standard'); scene=mste_scene(cfg);
model=scene.model; model.birthProbability=0; model.deathProbability=0;
model.enableMergeRemoval=false;
[unchanged,~,~]=ParticleTransition(q,1,cfg.transition.sigma,domain,0,model);
assert(isequal(unchanged.mask,q.mask),'Ablated transition changed source count without an event.');
g=MultiSourceSTE_GOSPA(zeros(0,3),scene.truth);
assert(isfinite(g.EstError) && abs(g.EstError-sqrt(0.5*3*50^2))<1e-12, ...
    'Empty-estimate GOSPA must be a finite cardinality penalty.');

% Check all three entry paths with small populations, including the matched
% ablation input and the exact two-source recovery prior.
examples={'standard','ablation','recovery'};
for j=1:numel(examples)
    cfg=mste_config(examples{j}); cfg.Np=120; cfg.nUpdates=2;
    cfg.makePlots=false; cfg.saveResults=false;
    result=run_mste_demo(cfg);
    for r=1:numel(result.runs)
        runData=result.runs{r};
        assert(all(isfinite(runData.jointGOSPA)));
        assert(all(abs(sum(runData.cardinalityProbability,2)-1)<1e-10));
        assert(numel(runData.tvec)==cfg.nUpdates && runData.tvec(end)==5);
    end
    if strcmp(examples{j},'ablation')
        assert(isequaln(result.runs{1}.initial,result.runs{2}.initial), ...
            'Ablation initial populations must be identical.');
    elseif strcmp(examples{j},'recovery')
        assert(abs(result.runs{1}.cardinalityProbability(1,3)-1)<1e-12);
        centres=result.runs{1}.initial.priorCentres;
        assert(abs(centres(1,1)-310/14)<1e-12 && centres(1,3)==14);
    end
end
fprintf('\nAll MSTE demonstration checks passed.\n');
end
