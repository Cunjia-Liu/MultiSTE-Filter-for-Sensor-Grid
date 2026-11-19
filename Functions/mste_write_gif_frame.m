function state = mste_write_gif_frame(state,cfg,update)
%MSTE_WRITE_GIF_FRAME Append one live-display frame without retaining history.
% Enabled only when cfg.plot.gifFile is nonempty. Requires a visible figure.
% A new run replaces its GIF; ablation variants receive separate filenames.
if isfield(state,'gifFailed') && state.gifFailed, return; end
if ~isgraphics(state.figure), return; end
try
    firstFrame = ~isfield(state,'gifPath');
    if firstFrame
        path = char(cfg.plot.gifFile);
        [folder,name,ext] = fileparts(path);
        assert(strcmpi(ext,'.gif'),'cfg.plot.gifFile must end in .gif.');
        if strcmp(cfg.example,'ablation')
            if contains(state.figure.Name,'without')
                name = [name '_no_merge_removal'];
            else
                name = [name '_full'];
            end
            path = fullfile(folder,[name ext]);
        end
        if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
        state.gifPath = path;
        state.gifFrames = 0;
        % Fix the window size for consistent frames, fitting the current
        % screen. No change to particles, extraction or axis data is made.
        state.figure.WindowStyle = 'normal';
        state.figure.Units = 'pixels';
        oldUnits = get(groot,'Units');
        resetUnits = onCleanup(@() set(groot,'Units',oldUnits));
        set(groot,'Units','pixels');
        screen = get(groot,'ScreenSize');
        scale = min([1,0.85*screen(3)/640,0.85*screen(4)/800]);
        frameSize = round(scale*[640 800]);
        set(state.figure,'Position',[screen(1)+20 screen(2)+20 frameSize], ...
            'Resize','off','MenuBar','none','ToolBar','none');
        movegui(state.figure,'onscreen');
        clear resetUnits;
    end
    delay = option(cfg.plot,'gifFrameDelay',0.20);
    if update==0, delay=option(cfg.plot,'gifInitialHold',1.0); end
    if update==cfg.nUpdates, delay=option(cfg.plot,'gifFinalHold',2.0); end
    validateattributes(delay,{'numeric'},{'scalar','finite','>=',0.02,'<=',655});
    drawnow;
    if ~isgraphics(state.figure), return; end
    captured = getframe(state.figure);
    % Each frame has its own palette, so colours introduced by later births
    % are retained. No Image Processing Toolbox functions are required.
    [indexed,map] = rgb2ind(captured.cdata,256,'nodither');
    if firstFrame
        state.gifImageSize = size(indexed);
        imwrite(indexed,map,state.gifPath,'gif','LoopCount',Inf, ...
            'DelayTime',delay,'DisposalMethod','doNotSpecify');
    else
        assert(isequal(size(indexed),state.gifImageSize), ...
            'Frame size changed. Keep the recording window on the same display.');
        imwrite(indexed,map,state.gifPath,'gif','WriteMode','append', ...
            'DelayTime',delay,'DisposalMethod','doNotSpecify');
    end
    state.gifFrames = state.gifFrames+1;
catch exception
    state.gifFailed = true;
    warning('MSTE:GIFCaptureFailed', ...
        'GIF capture stopped; filtering continues. %s',exception.message);
end
end

function value = option(settings,name,fallback)
if isfield(settings,name), value=settings.(name); else, value=fallback; end
end
