function y = apply_filter(x, b, a)
% 应用滤波器 - 修复版
% x: 输入信号
% b, a: 滤波器系数

    if nargin < 3
        error('需要滤波器系数b和a');
    end
    
    % 检查滤波器稳定性
    if ~isstable(b, a)
        warning('滤波器可能不稳定，使用简单滤波');
        y = filter(b, a, x);
    else
        try
            % 尝试零相位滤波
            y = filtfilt(b, a, x);
        catch
            % 如果失败，使用普通滤波
            warning('零相位滤波失败，使用普通滤波');
            y = filter(b, a, x);
        end
    end
    
    % 避免除零错误
    if max(abs(y)) > 0 && max(abs(x)) > 0
        % 保持原始幅度范围
        gain = max(abs(x)) / max(abs(y));
        if isfinite(gain) && gain > 0
            y = y * gain;
        end
    end
    
    fprintf('滤波完成: 输入RMS=%.4f, 输出RMS=%.4f\n', rms(x), rms(y));
end