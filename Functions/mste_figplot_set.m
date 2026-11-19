function [f,at1,at2,plotstruct] = mste_figplot_set(EstHistory,particles,tnow,f,at1,at2,plotstruct)
%MSTE_FIGPLOT_SET Update the existing rate and spatial animation artists.
% Clear stale estimates when no source passes the existence threshold.
if ~isgraphics(f) || ~isgraphics(at1) || ~isgraphics(at2), return; end
frame = EstHistory(end);
N_sourcesmax = size(particles.Q,2);
partpoints = frame.scatterplotpoints;
predN_sources = numel(partpoints);
estmat = frame.confidentest.mean;
for ns=1:N_sourcesmax
    if ns<=predN_sources
        set(plotstruct.histogramarray(ns),'Data',partpoints{ns}(:,3));
        set(plotstruct.histmean(ns),'Value',estmat(ns,3));
        set(plotstruct.particle_plots(ns),'XData',partpoints{ns}(:,1),'YData',partpoints{ns}(:,2));
        set(plotstruct.sourestPlot(ns),'XData',estmat(ns,1),'YData',estmat(ns,2));
    else
        set(plotstruct.histogramarray(ns),'Data',NaN);
        set(plotstruct.histmean(ns),'Value',NaN);
        set(plotstruct.particle_plots(ns),'XData',NaN,'YData',NaN);
        set(plotstruct.sourestPlot(ns),'XData',NaN,'YData',NaN);
    end
end
% Let the density axis follow the updated histogram heights.
ylim(at1,'auto');
title(at1,sprintf('Time = %g s | Extracted sources: %d',tnow,predN_sources), ...
    'FontSize',12,'Interpreter','none');
drawnow;
end
