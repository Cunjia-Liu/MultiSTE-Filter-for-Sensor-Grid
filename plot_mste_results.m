function figures = plot_mste_results(input)
%PLOT_MSTE_RESULTS Replot a demonstration without rerunning the filter.
% plot_mste_results(result), plot_mste_results('.../demo_result.mat'), or
% plot_mste_results with no input to choose a saved file interactively.
if nargin<1
    [file,folder] = uigetfile('*.mat','Select demo_result.mat');
    if isequal(file,0), figures=gobjects(0); return; end
    input = fullfile(folder,file);
end
if ischar(input) || isstring(input)
    S = load(input,'result');
    assert(isfield(S,'result'),'Expected a demo_result.mat file.');
    result = S.result;
    result.outputFolder = fileparts(char(input));
else
    result = input;
end
cfg = result.cfg;
figures = gobjects(0);
qLimits = cfg.plot.qLimits;
if isempty(qLimits)
    qMax = max(result.truth.Q);
    for r=1:numel(result.runs)
        snapshots = {result.runs{r}.initial,result.runs{r}.final};
        for j=1:2
            p = snapshots{j}.particles;
            q = p.Q(p.mask~=0);
            if ~isempty(q), qMax=max(qMax,prctile(q,99.5)); end
        end
    end
    qLimits = [0,5*ceil(max(qMax*1.1,5)/5)];
end
figures(end+1) = distributionFigure(result.runs{1}.initial,result,cfg,qLimits,'Initial belief');
saveFigure(figures(end),result.outputFolder,[cfg.example '_initial']);
for r=1:numel(result.runs)
    runData = result.runs{r};
    figures(end+1) = distributionFigure(runData.final,result,cfg,qLimits, ...
        sprintf('Final belief: %s',runData.label));
    saveFigure(figures(end),result.outputFolder,sprintf('%s_final_%d',cfg.example,r));
end

figures(end+1) = figure('Color','w','Name','MSTE single-trial metrics', ...
    'Units','centimeters','Position',[3 3 18 15]);
layout = tiledlayout(figures(end),2,1,'TileSpacing','compact','Padding','compact');
axP = nexttile(layout); hold(axP,'on');
axG = nexttile(layout); hold(axG,'on');
colours = lines(numel(result.runs)); styles = {'-','--'};
nTrue = numel(result.truth.Q);
for r=1:numel(result.runs)
    runData = result.runs{r};
    if strcmp(cfg.example,'recovery')
        xx = runData.update;
        pp = runData.cardinalityProbability(:,nTrue+1);
        gg = runData.jointGOSPA;
        xLabel = 'Filter update k (0 = prior)';
    else
        xx = result.observationTimes;
        pp = runData.cardinalityProbability(2:end,nTrue+1);
        gg = runData.jointGOSPA(2:end);
        xLabel = 'Time (s)';
    end
    plot(axP,xx,pp,styles{min(r,2)},'Color',colours(r,:),'LineWidth',1.6, ...
        'DisplayName',runData.label);
    plot(axG,xx,gg,styles{min(r,2)},'Color',colours(r,:),'LineWidth',1.6, ...
        'DisplayName',runData.label);
end
ylabel(axP,sprintf('P(M = %d)',nTrue)); ylim(axP,[0 1]);
ylabel(axG,'Joint-state GOSPA'); xlabel(axG,xLabel);
grid(axP,'on'); grid(axG,'on'); box(axP,'on'); box(axG,'on');
if numel(xx)>1, xlim(axP,[xx(1) xx(end)]); xlim(axG,[xx(1) xx(end)]); end
legend(axP,'Location','best','Interpreter','none');
title(axP,sprintf('Single trial: seed %d, wind %+g deg',cfg.seed,cfg.wind.directionDeg));
set([axP axG],'FontSize',11);
saveFigure(figures(end),result.outputFolder,[cfg.example '_metrics']);
end

function f = distributionFigure(snapshot,result,cfg,qLimits,caption)
% Physical plot-box widths match, including non-square search domains.
aspect = diff(cfg.xlimits)/diff(cfg.ylimits);
mapWidth = min(14.5,14.5*aspect);
mapHeight = mapWidth/aspect;
mapPosition = [2 2 mapWidth mapHeight];
f = figure('Color','w','Name',caption,'Units','centimeters', ...
    'Position',[2 2 mapWidth+3.5 mapHeight+7.2]);
rates = axes('Parent',f,'Units','centimeters','Position',[2 mapHeight+3.3 mapWidth 2.8]);
hold(rates,'on');
map = axes('Parent',f,'Units','centimeters','Position',mapPosition); hold(map,'on');
p = snapshot.particles; w = snapshot.weights;
colours = lines(cfg.Mmax);
edges = linspace(qLimits(1),qLimits(2),61);
centres = (edges(1:end-1)+edges(2:end))/2;
for j=1:cfg.Mmax
    active = p.mask(:,j)~=0;
    mass = sum(w(active));
    if mass<=0, continue; end
    ww = w(active)/mass;
    q = p.Q(active,j);
    bins = discretize(q,edges);
    valid = ~isnan(bins);
    density = accumarray(bins(valid),ww(valid),[numel(centres),1],@sum,0)/diff(edges(1:2));
    bar(rates,centres,density,1,'FaceColor',colours(j,:), ...
        'FaceAlpha',0.25,'EdgeColor','none','HandleVisibility','off');
    xy = [p.x(active,j),p.y(active,j)];
    % Deterministic weighted quantiles: plotting consumes no random numbers.
    nDisplay = min(cfg.plot.maxParticles,size(xy,1));
    cdf = cumsum(ww); cdf(end)=1;
    targets = ((1:nDisplay)-0.5)/nDisplay;
    indices = zeros(nDisplay,1); ii=1;
    for a=1:nDisplay
        while cdf(ii)<targets(a), ii=ii+1; end
        indices(a)=ii;
    end
    scatter(map,xy(indices,1),xy(indices,2),5,colours(j,:), ...
        'filled','MarkerFaceAlpha',0.18,'HandleVisibility','off');
end
for q=result.truth.Q
    xline(rates,q,'k-','LineWidth',1.4,'HandleVisibility','off');
end
estimates = snapshot.estimate.mean;
for j=1:size(estimates,1)
    xline(rates,estimates(j,3),'--','Color',[0 0.45 0.74], ...
        'LineWidth',1.4,'HandleVisibility','off');
end
hMarginal = patch(rates,NaN,NaN,[0 0.45 0.74],'FaceAlpha',0.25,'EdgeColor','none');
hRate = plot(rates,NaN,NaN,'k-','LineWidth',1.4);
hEstimateRate = plot(rates,NaN,NaN,'--','Color',[0 0.45 0.74],'LineWidth',1.4);
legend(rates,[hMarginal,hRate,hEstimateRate], ...
    {'Conditional particle marginals','True rates','Estimated/prior rates'}, ...
    'Location','northeast','FontSize',8);
xlim(rates,qLimits); ylabel(rates,'Density'); xlabel(rates,'Release rate Q (g/s)');
title(rates,{caption,sprintf('k=%d; wind %+g deg',snapshot.update,cfg.wind.directionDeg)}, ...
    'Interpreter','none','FontSize',11);
sensor = plot(map,result.sensorPositions(:,1),result.sensorPositions(:,2), ...
    '+','Color',[0.55 0.55 0.55],'MarkerSize',6,'LineWidth',1);
truth = plot(map,result.truth.x,result.truth.y,'kp','MarkerFaceColor','k','MarkerSize',11);
estimate = plot(map,estimates(:,1),estimates(:,2),'p', ...
    'Color',[0 0.45 0.74],'MarkerSize',11,'LineWidth',1.5);
for j=1:size(estimates,1)
    text(map,estimates(j,1)+0.015*diff(cfg.xlimits),estimates(j,2)+0.025*diff(cfg.ylimits), ...
        sprintf('Q=%.2g',estimates(j,3)),'FontSize',9);
end
phi = deg2rad(cfg.wind.directionDeg);
arrowLength = 0.12*min([diff(cfg.xlimits),diff(cfg.ylimits)]);
origin = [cfg.xlimits(1)+0.18*diff(cfg.xlimits),cfg.ylimits(1)+0.5*diff(cfg.ylimits)];
quiver(map,origin(1),origin(2),arrowLength*cos(phi),arrowLength*sin(phi),0, ...
    'k','LineWidth',1.5,'MaxHeadSize',0.5,'HandleVisibility','off');
text(map,origin(1),origin(2)+0.04*diff(cfg.ylimits),'Wind','FontSize',10);
xlim(map,cfg.xlimits); ylim(map,cfg.ylimits); axis(map,'equal');
xlim(map,cfg.xlimits); ylim(map,cfg.ylimits);
xlabel(map,'x (m)'); ylabel(map,'y (m)'); box(map,'on'); box(rates,'on');
legend(map,[sensor,truth,estimate],{'Sensors','True sources','Estimates / prior centres'}, ...
    'Location','southoutside','NumColumns',3,'FontSize',8);
set(map,'Position',mapPosition); % keep histogram and domain plot boxes aligned
set([map rates],'FontSize',10);
end

function saveFigure(f,folder,name)
if isempty(folder), return; end
if ~isfolder(folder), mkdir(folder); end
drawnow;
exportgraphics(f,fullfile(folder,[name '.png']),'Resolution',200);
savefig(f,fullfile(folder,[name '.fig']));
fprintf('Saved figure: %s\n',fullfile(folder,[name '.png']));
end
