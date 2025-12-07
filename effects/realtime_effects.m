function output = realtime_pitch_shift(input, semitones, fs, varargin)
% 实时变调效果器 - 直接调用现有的pitch_shift函数
% 针对实时处理进行优化（分帧处理）

    if semitones == 0
        output = input;
        return;
    end
    
    % 直接调用现有的高质量变调函数
    try
        output = pitch_shift(input, semitones, fs, varargin{:});
        fprintf('实时变调: %.1f 半音 (使用pitch_shift函数)\n', semitones);
    catch ME
        fprintf('pitch_shift调用失败: %s\n使用简化方法\n', ME.message);
        % 备用方案：重采样方法
        output = fallback_pitch_shift(input, semitones, fs);
    end
end

function output = realtime_time_stretch(input, ratio, fs, varargin)
% 实时时间拉伸 - 直接调用现有的time_stretch函数

    if ratio == 1
        output = input;
        return;
    end
    
    % 直接调用现有的高质量时间拉伸函数
    try
        output = time_stretch(input, ratio, fs, varargin{:});
        fprintf('实时时间拉伸: 比例 %.2f (使用time_stretch函数)\n', ratio);
    catch ME
        fprintf('time_stretch调用失败: %s\n使用简化方法\n', ME.message);
        % 备用方案：重采样方法
        output = fallback_time_stretch(input, ratio, fs);
    end
end

function output = realtime_filter(input, filter_type, frequencies, fs, varargin)
% 实时滤波器 - 调用现有的滤波器函数

    if isempty(frequencies) || frequencies(1) <= 0 || frequencies(end) >= fs/2
        output = input;
        return;
    end
    
    % 使用现有的滤波器设计函数
    try
        order = 4; % 实时处理使用较低阶数
        [b, a] = design_filter(filter_type, frequencies(1), frequencies(end), fs, order);
        
        % 使用现有的滤波函数
        output = apply_filter(input, b, a);
        fprintf('实时滤波: %s, 频率范围: [%.0f, %.0f] Hz\n', ...
                filter_type, frequencies(1), frequencies(end));
    catch ME
        fprintf('滤波器调用失败: %s\n使用原始信号\n', ME.message);
        output = input;
    end
end