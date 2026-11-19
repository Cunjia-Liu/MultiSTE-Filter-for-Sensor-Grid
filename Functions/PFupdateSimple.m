function [updated_particles,updated_weights,info] = PFupdateSimple(particlesMinus,weightsMinus,measurement,pos,Np,D_threshold,ts,PDetect,TransitionSigma,Domain,clusterstatus)
%PFUPDATESIMPLE One inference update from measurements at arbitrary positions.
% Positions are Nsensor-by-2 and measurement is Nsensor-by-1. No planner or
% truth positions are used here. ts supplies only plume/transition parameters.
% Optional info reports inference time and cardinality BEFORE resampling.
if nargin < 11, clusterstatus = 0; end
tInference = tic;
[particles,~,~] = ParticleTransition(particlesMinus,weightsMinus, ...
    TransitionSigma,Domain,clusterstatus,ts);
[weights,~] = LikelihoodUpdate(particles,weightsMinus,pos,measurement, ...
    D_threshold,ts,PDetect);
Mmax = size(particles.x,2);
info.cardinalityProbability = accumarray(sum(particles.mask~=0,2)+1, ...
    weights,[Mmax+1,1],@sum,0).';
info.effectiveSampleSize = 1/sum(weights.^2);
info.resampled = info.effectiveSampleSize < 0.6*Np;
if info.resampled
    [particles,weights,~,~] = resample_PF(particles,weights,Np,2);
    particles.Q = particles.Q .* (particles.mask~=0);
end
updated_particles = particles;
updated_weights = weights;
info.inferenceSeconds = toc(tInference);
end
