function state = mste_live_plot(snapshot,scene,cfg,state,label,tnow)
%MSTE_LIVE_PLOT Adapt the current posterior to the original animation helpers.
% Only the current frame is kept. No clustering/filter update is repeated.
% Closing the live window disables animation for the rest of this trial.
if ~isempty(state) && (state.closed || ~isgraphics(state.figure) || ...
        ~isgraphics(state.rates) || ~isgraphics(state.map))
    state.closed = true;
    return;
end
% Rendering/callbacks must not advance the random stream used by inference.
oldRng = rng;
restoreRng = onCleanup(@() rng(oldRng)); %#ok<NASGU>
p = snapshot.particles;
w = snapshot.weights;
selected = find(snapshot.existence>cfg.existenceThreshold);
points = cell(numel(selected),1);
means = zeros(numel(selected),3);
for j=1:numel(selected)
    slot = selected(j);
    active = p.mask(:,slot)~=0;
    X = [p.x(active,slot),p.y(active,slot),p.Q(active,slot)];
    ww = w(active); ww = ww/sum(ww);
    means(j,:) = ww'*X;
    % Deterministic weighted display sample, with no RNG calls. The complete
    % population is still used by inference, extraction and final metrics.
    count = min(cfg.plot.maxParticles,size(X,1));
    cdf = cumsum(ww); cdf(end)=1;
    targets = ((1:count)-0.5)/count;
    indices = zeros(count,1); ii=1;
    for a=1:count
        while cdf(ii)<targets(a), ii=ii+1; end
        indices(a)=ii;
    end
    points{j} = X(indices,:);
end
frame = struct('pose',scene.positions,'measurement',zeros(size(scene.positions,1),1), ...
    'confidentest',struct('mean',means), ...
    'estconfidence',100*snapshot.existence(selected),'scatterplotpoints',{points});
if snapshot.update>0, frame.measurement=scene.measurements(:,snapshot.update); end
if isempty(state)
    f = figure('Name',['Live MSTE: ' label],'NumberTitle','off','Color','w');
    [f,a1,a2,plots] = mste_figplot_initial(frame,scene.domain,scene.truth,f,tnow,cfg.Mmax);
    state = struct('figure',f,'rates',a1,'map',a2,'plots',plots,'closed',false);
end
if ~isgraphics(state.figure) || ~isgraphics(state.rates) || ~isgraphics(state.map)
    state.closed=true; return;
end
% A fixed user Q range is honoured; otherwise expand the live range as needed.
if isempty(cfg.plot.qLimits)
    largestRate = max([scene.truth.Q(:);means(:,3);20]);
    limits = [0,max(state.rates.XLim(2),5*ceil(1.15*largestRate/5))];
else
    limits = cfg.plot.qLimits;
end
xlim(state.rates,limits);
% Setting BinLimits alone selects manual binning and can preserve a single
% bin from the empty initial histogram. Always specify edges for all 60 bins.
edges = linspace(limits(1),limits(2),61);
for j=1:numel(state.plots.histogramarray)
    state.plots.histogramarray(j).BinEdges=edges;
end
[state.figure,state.rates,state.map,state.plots] = mste_figplot_set( ...
    frame,p,tnow,state.figure,state.rates,state.map,state.plots);
if ~isgraphics(state.figure) || ~isgraphics(state.rates) || ~isgraphics(state.map)
    state.closed=true; return;
end
if snapshot.update==0
    titleText=sprintf('%s | Initial prior (before measurements)',label);
else
    titleText=sprintf('%s | Update %d, t = %g s | %d extracted sources', ...
        label,snapshot.update,tnow,size(means,1));
end
title(state.rates,titleText,'Interpreter','none','FontSize',10);
drawnow;
if cfg.plot.pauseSeconds>0 && isgraphics(state.figure)
    pause(cfg.plot.pauseSeconds);
end
end
