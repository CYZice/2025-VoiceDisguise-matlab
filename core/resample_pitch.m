function y = resample_pitch(x, pitch_ratio, fs, varargin)
% 智能重采样组件 - 高质量音高变换
% x: 输入信号
% pitch_ratio: 音高比例 (>1升调, <1降调)
% fs: 采样率
% varargin: 可选参数 ('quality', 'high'/ 'medium'/ 'low')

    p = inputParser;
    addRequired(p, 'x', @isvector);
    addRequired(p, 'pitch_ratio', @(x) x > 0);
    addRequired(p, 'fs', @(x) x > 0);
    addParameter(p, 'quality', 'high', @ischar);
    addParameter(p, 'antialias', true, @islogical);
    parse(p, x, pitch_ratio, fs, varargin{:});
    
    % 确保列向量
    if size(x, 2) > 1
        x = x(:);
    end
    
    % 根据质量选择设置不同的重采样参数
    switch p.Results.quality
        case 'high'
            n = 64;  % 高质量：高滤波器阶数
            beta = 12; % Kaiser窗参数
        case 'medium'
            n = 32;
            beta = 8;
        case 'low'
            n = 16;
            beta = 5;
        otherwise
            n = 64;
            beta = 12;
    end
    
    % 计算重采样比例
    P = 1;
    Q = pitch_ratio;
    
    % 简化比例以避免过大的滤波器
    [P, Q] = rat(P/Q, 1e-6);
    
    if P/Q == 1
        % 不需要重采样
        y = x;
        return;
    end
    
    % 使用resample函数进行高质量重采样
    if p.Results.antialias
        % 带抗混叠滤波的重采样
        y = resample(x, P, Q, n, beta);
    else
        % 简单重采样（速度快但质量较低）
        y = resample(x, P, Q);
    end
    
    % 保持原始幅值范围
    y = y * (max(abs(x)) / max(abs(y)));
end