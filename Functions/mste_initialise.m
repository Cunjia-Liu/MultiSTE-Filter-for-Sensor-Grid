function [theta,weights,priorCentres] = mste_initialise(cfg,scene)
%MSTE_INITIALISE Broad unknown-cardinality prior or controlled merged belief.
N = cfg.Np; K = cfg.Mmax;
xl = cfg.xlimits; yl = cfg.ylimits;
theta = struct('x',zeros(N,K),'y',zeros(N,K),'Q',zeros(N,K),'mask',zeros(N,K));
for j=1:K
    theta.x(:,j) = xl(1)+diff(xl)*rand(N,1);
    theta.y(:,j) = yl(1)+diff(yl)*rand(N,1);
    theta.Q(:,j) = gamrnd(2*ones(N,1),5*ones(N,1));
end
priorCentres = [];
if strcmp(cfg.example,'recovery')
    pair = cfg.recovery.mergePair;
    S = scene.sources;
    mergedQ = sum(S(1,pair));
    mergedXY = (S(2:3,pair)*S(1,pair).'/mergedQ).';
    remaining = setdiff(1:3,pair,'stable');
    priorCentres = [mergedXY mergedQ; S(2,remaining) S(3,remaining) S(1,remaining)];
    theta.Q(:) = 0;
    for j=1:2
        draw = priorCentres(j,:) + randn(N,3).*cfg.recovery.initialStd;
        bad = outside(draw,xl,yl);
        attempts = 0;
        while any(bad)
            draw(bad,:) = priorCentres(j,:) + randn(sum(bad),3).*cfg.recovery.initialStd;
            bad = outside(draw,xl,yl);
            attempts = attempts+1;
            assert(attempts<=10000,'Recovery prior rejection sampling did not converge.');
        end
        theta.x(:,j) = draw(:,1); theta.y(:,j) = draw(:,2); theta.Q(:,j) = draw(:,3);
        theta.mask(:,j) = 1;
    end
else
    M = randi([1,K],N,1);
    for i=1:N
        theta.mask(i,randperm(K,M(i))) = 1;
    end
    theta.Q = theta.Q.*theta.mask;
end
weights = ones(N,1)/N;
end

function bad = outside(X,xl,yl)
bad = X(:,1)<xl(1) | X(:,1)>xl(2) | X(:,2)<yl(1) | X(:,2)>yl(2) | X(:,3)<=0;
end
