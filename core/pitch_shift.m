function y = pitch_shift(x, semitones, fs, varargin)
% 完整的变调不变速函数 - 使用Dan Ellis相位声码器
% x: 输入信号
% semitones: 半音数（正数升调，负数降调）
% fs: 采样率
% varargin: 可选参数

    p = inputParser;
    addRequired(p, 'x', @isvector);
    addRequired(p, 'semitones', @isnumeric);
    addRequired(p, 'fs', @(x) x > 0);
    addParameter(p, 'nfft', 1024, @(x) x > 0);
    addParameter(p, 'formant_correction', true, @islogical);
    addParameter(p, 'quality', 'high', @ischar);
    parse(p, x, semitones, fs, varargin{:});
    
    if semitones == 0
        y = x;
        return;
    end
    
    % 确保列向量
    x = x(:);
    
    % 计算音高比例
    pitch_ratio = 2^(semitones/12);
    
    try
        if semitones > 0
            % 升调流程：先拉伸时间，再重采样升调
            stretch_factor = 1 / pitch_ratio;
            
            % 使用Dan Ellis相位声码器进行时间拉伸
            time_stretched = pvoc(x, stretch_factor, p.Results.nfft);
            
            % 重采样改变音高（同时恢复时长）
            y = resample_pitch(time_stretched, pitch_ratio, fs, ...
                              'quality', p.Results.quality);
            
        else
            % 降调流程：先压缩时间，再重采样降调
            stretch_factor = abs(1 / pitch_ratio);
            
            % 时间压缩
            time_compressed = pvoc(x, stretch_factor, p.Results.nfft);
            
            % 重采样改变音高
            y = resample_pitch(time_compressed, pitch_ratio, fs, ...
                              'quality', p.Results.quality);
        end
        
        % 共振峰校正
        if p.Results.formant_correction && abs(semitones) >= 2
            y = formant_correction(y, semitones, fs, ...
                                  'intensity', 0.6, 'method', 'lpc');
        end
        
        % 确保输出长度与输入大致相同
        min_len = min(length(x), length(y));
        y = y(1:min_len);
        
        % 归一化
        y = y / max(abs(y)) * max(abs(x));
        
    catch ME
        warning('变调处理失败，返回原始信号。错误: %s', ME.message);
        y = x;
    end
end