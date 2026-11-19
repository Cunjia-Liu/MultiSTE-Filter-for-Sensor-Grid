function [orderedparticles,clustermean] = ClusterTransitionUpdate2(particles)
%CLUSTERTRANSITIONUPDATE2 Align source slots for estimate extraction only.
% Cost and returned particles use THE SAME permutation. Coordinates are
% [x,y,5*Q], as in the final corrected research implementation.
% Inactive slots remain in the fixed-size representation.
[Np,N_sources] = size(particles.x);
points = [particles.x(:),particles.y(:),5*particles.Q(:)];
[~,clustermean] = kmeans(points,N_sources);
permcombination = perms(1:N_sources);
partvec3d = zeros(N_sources,3,Np);
partvec3d(:,1,:) = particles.x';
partvec3d(:,2,:) = particles.y';
partvec3d(:,3,:) = 5*particles.Q';
cost = zeros(size(permcombination,1),Np);
for m = 1:size(permcombination,1)
    cost(m,:) = reshape(sum(vecnorm( ...
        partvec3d(permcombination(m,:),:,:) - clustermean,2,2),1),1,Np);
end
[~,classification] = min(cost,[],1);
orderedparticles = particles;
for np = 1:Np
    order = permcombination(classification(np),:);
    orderedparticles.x(np,:) = particles.x(np,order);
    orderedparticles.y(np,:) = particles.y(np,order);
    orderedparticles.Q(np,:) = particles.Q(np,order);
    orderedparticles.mask(np,:) = particles.mask(np,order);
end
end
