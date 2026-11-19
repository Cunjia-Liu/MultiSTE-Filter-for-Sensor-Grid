function [result,gifFile] = make_readme_animation(exampleOrConfig)
%MAKE_README_ANIMATION Run a single trial and record a GIF for the README.
% [result,gifFile] = make_readme_animation;            % recovery, default
% [result,gifFile] = make_readme_animation('standard');
% cfg=mste_config('recovery'); cfg.seed=1001;
% [result,gifFile] = make_readme_animation(cfg);        % keep custom settings
% Output: docs/images/<example>.gif. An existing GIF at that path is replaced.
% Run in desktop MATLAB and keep the live window open until completion.
root = fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'Functions'));
if nargin<1, exampleOrConfig='recovery'; end
if isstruct(exampleOrConfig)
    cfg = exampleOrConfig;
else
    example = validatestring(exampleOrConfig,{'standard','recovery'});
    cfg = mste_config(example);
end
cfg.example = validatestring(cfg.example,{'standard','recovery'});
cfg.plot.live = true;
% These defaults affect presentation only. Particle counts, seeds, layouts
% and all inference settings are inherited from cfg without modification.
defaults = struct('updateEvery',1,'pauseSeconds',0, ...
    'gifFrameDelay',0.20,'gifInitialHold',1.0,'gifFinalHold',2.0, ...
    'gifFile',fullfile(root,'docs','images',[cfg.example '.gif']));
names = fieldnames(defaults);
for j=1:numel(names)
    if ~isfield(cfg.plot,names{j}) || isempty(cfg.plot.(names{j}))
        cfg.plot.(names{j}) = defaults.(names{j});
    end
end
gifFile = char(cfg.plot.gifFile);
[folder,~,ext] = fileparts(gifFile);
assert(strcmpi(ext,'.gif'),'cfg.plot.gifFile must end in .gif.');
for name={'gifFrameDelay','gifInitialHold','gifFinalHold'}
    validateattributes(cfg.plot.(name{1}),{'numeric'}, ...
        {'scalar','finite','>=',0.02,'<=',655});
end
if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
fprintf('Recording %s animation to: %s\n',cfg.example,gifFile);
% Remove an earlier output so it cannot be mistaken for this run if capture
% fails before the first frame. Existing run data under Results are retained.
if isfile(gifFile), delete(gifFile); end
result = run_mste_demo(cfg);
recordEvery = result.cfg.plot.updateEvery;
expectedFrames = numel(unique([0,1,recordEvery:recordEvery:cfg.nUpdates,cfg.nUpdates]));
if ~isfile(gifFile)
    warning('MSTE:GIFMissing','No GIF was recorded. Check the capture warning above.');
    return;
end
frames = imfinfo(gifFile);
if numel(frames)~=expectedFrames
    warning('MSTE:GIFIncomplete', ...
        'GIF has %d of %d expected frames. Keep the live window open for the full run.', ...
        numel(frames),expectedFrames);
    return;
end
fileInfo = dir(gifFile);
fprintf('Saved GIF: %s (%d frames, %.2f MB)\n', ...
    gifFile,numel(frames),fileInfo.bytes/1e6);
fprintf('Playback is accelerated; frame titles show simulation time.\n');
end
