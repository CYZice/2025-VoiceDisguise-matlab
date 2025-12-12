function y = pitch_shift_complete(x, semitones, fs, varargin)
% 完整变调不变速函数
% x: 输入信号, semitones: 半音变化, fs: 采样率

p = inputParser;
addRequired(p, 'x', @isvector);
addRequired(p, 'semitones', @isnumeric);
addRequired(p, 'fs', @(x) x > 0);
addParameter(p, 'nfft', 1024, @(x) x > 0);
addParameter(p, 'formant_correction', true, @islogical);
addParameter(p, 'method', 'lpc', @ischar);
addParameter(p, 'beta', 1.5, @isnumeric);
parse(p, x, semitones, fs, varargin{:});

if semitones == 0
    y = x;
    return;
end

x = x(:);
pitch_ratio = 2^(semitones/12);

try
    if semitones > 0
        % 升调：先拉伸时间，再重采样升调
        stretch_factor = 1 / pitch_ratio;
        time_stretched = pvoc(x, stretch_factor, p.Results.nfft);
        y = resample_pitch(time_stretched, pitch_ratio, fs, 'quality', 'high');
    else
        % 降调：先压缩时间，再重采样降调
        stretch_factor = abs(1 / pitch_ratio);
        time_compressed = pvoc(x, stretch_factor, p.Results.nfft);
        y = resample_pitch(time_compressed, pitch_ratio, fs, 'quality', 'high');
    end

    % 共振峰校正
    if p.Results.formant_correction && abs(semitones) >= 2
        y = formant_correction(x, y, semitones, fs, ...
            'intensity', 0.6, 'method', p.Results.method, 'beta', p.Results.beta);
    end

    % 长度和幅度调整
    min_len = min(length(x), length(y));
    y = y(1:min_len);
    y = y / max(abs(y)) * max(abs(x));
    
catch ME
    error('变调处理失败: %s', ME.message);
end

end