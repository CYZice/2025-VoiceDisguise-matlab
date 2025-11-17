function y = time_stretch(x, time_ratio, fs)
% 时间拉伸（快慢放效果）
% x: 输入信号
% time_ratio: 时间拉伸比例 (>1变慢，<1变快)
% fs: 采样率

    if time_ratio == 1
        y = x;
        return;
    end
    
    if time_ratio > 0
        % 使用相位声码器进行高质量时间拉伸
        y = pvoc(x, time_ratio, 1024);
    else
        error('时间拉伸比例必须为正数');
    end
    
    fprintf('时间拉伸: 比例=%.2f, 输入时长=%.2fs, 输出时长=%.2fs\n', ...
            time_ratio, length(x)/fs, length(y)/fs);
end