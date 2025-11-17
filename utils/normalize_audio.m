function y = normalize_audio(x, target_level)
% 音频归一化
% x: 输入信号
% target_level: 目标电平（0-1）

    if nargin < 2
        target_level = 0.95;
    end
    
    current_max = max(abs(x));
    if current_max > 0
        y = x / current_max * target_level;
    else
        y = x;
    end
end