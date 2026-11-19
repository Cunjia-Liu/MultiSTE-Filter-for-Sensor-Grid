function [newparticle,newweights,Dk,hopt] = resample_PF(particles,weights,D,regularizeMode)

        % --- residual resampling ---
    % 1. expected counts
    expCount = D * weights(:);                  % D x 1

    % 2. deterministic copies
    copies_int = floor(expCount);               % integer part
    N_det = sum(copies_int);
    % indices for deterministic part
    det_idx = repelem((1:length(weights))', copies_int);  % N_det x 1

    % 3. stochastic copies for the remainder
    R = D - N_det;
    if R > 0
        % fractional remainder, renormalized
        frac = expCount - copies_int;
        if sum(frac) > 0
            frac = frac ./ sum(frac);
        else
            % all were integers somehow -> just uniform fallback
            frac = ones(size(frac)) / numel(frac);
        end

        % systematic draw on the remainder part
        CSW = cumsum(frac);
        ii = 1;
        stoch_idx = zeros(R,1);
        u0 = rand/R;
        for jj = 1:R
            uj = u0 + (jj-1)/R;
            while uj > CSW(ii)
                ii = ii + 1;
            end
            stoch_idx(jj) = ii;
        end

        full_idx = [det_idx; stoch_idx];        % total D x 1
    else
        full_idx = det_idx;
    end

    % now build newparticle from full_idx
    fields = fieldnames(particles);
    for f = 1:numel(fields)
        newparticle.(fields{f}) = particles.(fields{f})(full_idx,:);
    end

    % carry mask & enforce inactive Q=0 (keep your invariant)
    if isfield(newparticle,'mask')
        newparticle.Q = newparticle.Q .* (newparticle.mask ~= 0);
    end

    % equal weights after resample
    % newweights = ones(D,1) / D;

    newweights = ones(D,1)/D;


    [Np, N_sources] = size(particles.(fields{1}));

    if regularizeMode == 1
        % Per-source, decoupled regularisation (xy and Q separate)
        for ns = 1:N_sources

            % Active particles for this source
            if isfield(particles,'mask')
                idx = (particles.mask(:,ns) ~= 0);
            else
                idx = true(Np,1);
            end

            if ~any(idx)
                % No active samples: tiny jitter
                Dk.xy(:,:,ns) = 1e-6 * eye(2);
                Dk.Q(ns,1)    = 1e-6;
                continue;
            end

            w = weights(idx);
            sw = sum(w);
            if sw <= 0 || ~isfinite(sw)
                Dk.xy(:,:,ns) = 1e-6 * eye(2);
                Dk.Q(ns,1)    = 1e-6;
                continue;
            end
            w = w / sw;

            % Data for this source
            Xxy = [particles.x(idx,ns), particles.y(idx,ns)];
            XQ  = particles.Q(idx,ns);

            % Means
            mu_xy = w' * Xxy;      % 1x2
            mu_Q  = w' * XQ;       % scalar

            % Deviations
            dxy = Xxy - mu_xy;     % Na x 2
            dQ  = XQ  - mu_Q;      % Na x 1

            % Weighted covariances
            Cxy = (dxy' .* w') * dxy + 1e-9*eye(2);
            CQ  = (dQ'  .* w') * dQ  + 1e-9;

            % Store Cholesky / std
            Dk.xy(:,:,ns) = cholcov(Cxy);   % 2x2
            Dk.Q(ns,1)    = sqrt(CQ);       % scalar
        end

    elseif regularizeMode == 2
        % Block-diagonal global matrices:
        % - each source ns has its own [x,y] 2x2 block and Q scalar
        % - combine into Dk.xy (2N x 2N) and Dk.Q (N x N, diagonal)
        Lxy_blocks = cell(1, N_sources);
        LQ_diag    = zeros(N_sources,1);

        for ns = 1:N_sources

            % Active particles for this source
            if isfield(particles,'mask')
                idx = (particles.mask(:,ns) ~= 0);
            else
                idx = true(Np,1);
            end

            if ~any(idx)
                Lxy_blocks{ns} = 1e-6 * eye(2);
                LQ_diag(ns)    = 1e-6;
                continue;
            end

            w = weights(idx);
            sw = sum(w);
            if sw <= 0 || ~isfinite(sw)
                Lxy_blocks{ns} = 1e-6 * eye(2);
                LQ_diag(ns)    = 1e-6;
                continue;
            end
            w = w / sw;

            % Data for this source
            Xxy = [particles.x(idx,ns), particles.y(idx,ns)];
            XQ  = particles.Q(idx,ns);

            % Means
            mu_xy = w' * Xxy;      % 1x2
            mu_Q  = w' * XQ;

            % Deviations
            dxy = Xxy - mu_xy;
            dQ  = XQ  - mu_Q;

            % Weighted covariances
            Cxy = (dxy' .* w') * dxy + 0.001*eye(2);
            CQ  = (dQ'  .* w') * dQ  + 1e-6;

            % Cholesky for this block
            Lxy_blocks{ns} = cholcov(Cxy);  % 2x2
            LQ_diag(ns)    = sqrt(CQ);      % 1x1
        end

        % Assemble big block-diagonal matrices (same interface as old code)
        Dk.xy = blkdiag(Lxy_blocks{:});     % (2N_sources x 2N_sources)
        Dk.Q  = diag(LQ_diag);              % (N_sources x N_sources)

    else
        error("Regularization Mode Incorrectly set. Set 'regularizeMode' to 1 or 2.");
    end

    newweights = ones(D,1)/D;

    mm = N_sources * length(fields);              % same as before
    A  = (4/(mm+2))^(1/(mm+4));
    hopt = A * (D^(-1/(mm+4)));


end
