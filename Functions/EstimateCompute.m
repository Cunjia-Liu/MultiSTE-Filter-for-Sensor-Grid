function [confidentest,estconfidence,totalest,totalestconfidence,clustermean,confidentrelparticles,orderedparticles] = EstimateCompute(particles,weights,existenceThreshold)
%ESTIMATECOMPUTE Align slots, retain sources with existence > threshold.
% Existence is the weight of particles with that aligned slot active.
% Does not select a MAP count. Original confidence outputs use percentages.
if nargin < 3, existenceThreshold = 0.5; end
[particles,clustermean] = ClusterTransitionUpdate2(particles);
orderedparticles = particles;
n_sourcemax = size(particles.x,2);
totalest = nan(n_sourcemax,3);
totalestconfidence = zeros(n_sourcemax,1);
totalestuncertainty = nan(n_sourcemax,3);
relparticles = cell(n_sourcemax,1);
for ns = 1:n_sourcemax
    active = particles.mask(:,ns)~=0;
    w = weights(active);
    points = [particles.x(active,ns),particles.y(active,ns),particles.Q(active,ns)];
    relparticles{ns} = points;
    mass = sum(w);
    totalestconfidence(ns) = 100*mass;
    if mass > 0
        w = w/mass;
        totalest(ns,:) = w'*points;
        totalestuncertainty(ns,:) = w'*((points-totalest(ns,:)).^2);
    end
end
selected = totalestconfidence > 100*existenceThreshold;
confidentest.mean = totalest(selected,:);
confidentest.var = totalestuncertainty(selected,:);
if any(selected)
    confidentest.normedstd = sqrt(sum(confidentest.var,'all')/sum(selected));
    confidentest.normedPosestd = sqrt(sum(confidentest.var(:,1:2),'all')/sum(selected));
else
    confidentest.normedstd = NaN;
    confidentest.normedPosestd = NaN;
end
estconfidence = totalestconfidence(selected);
confidentrelparticles = relparticles(selected);
end
