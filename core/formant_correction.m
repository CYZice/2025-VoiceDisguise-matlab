function y = formant_correction(x, semitones, fs, varargin)
% 共振峰校正 - 提高变调后的音质自然度
% x: 输入信号
% semitones: 半音变化量
% fs: 采样率
% varargin: 校正强度参数

    p = inputParser;
    addRequired(p, 'x', @isvector);
    addRequired(p, 'semitones', @isnumeric);
    addRequired(p, 'fs', @(x) x > 0);
    addParameter(p, 'intensity', 0.5, @(x) x >= 0 && x <= 1); % 校正强度
    addParameter(p, 'method', 'lpc', @ischar); % 'lpc' 或 'spectral_tilt'
    parse(p, x, semitones, fs, varargin{:});
    
    if semitones == 0
        y = x;
        return;
    end
    
    % 计算共振峰补偿因子
    % 较大的音高变化需要更多的共振峰补偿
    formant_compensation = 1.0 - (p.Results.intensity * abs(semitones) / 24);
    formant_compensation = max(0.5, min(1.5, formant_compensation));
    
    switch p.Results.method
        case 'lpc'
            % 基于LPC的共振峰校正（质量较高）
            y = formant_correction_lpc(x, formant_compensation, fs);
            
        case 'spectral_tilt'
            % 基于频谱倾斜的简单校正（计算量小）
            y = formant_correction_spectral(x, formant_compensation, fs);
            
        otherwise
            y = formant_correction_lpc(x, formant_compensation, fs);
    end
end

function y = formant_correction_lpc(x, compensation, fs)
% 基于LPC的共振峰校正
    
    frame_size = round(0.03 * fs); % 30ms帧
    hop_size = round(frame_size / 4);
    
    % 分帧处理
    frames = buffer(x, frame_size, frame_size - hop_size, 'nodelay');
    y_frames = zeros(size(frames));
    
    for i = 1:size(frames, 2)
        frame = frames(:, i);
        
        if max(abs(frame)) > 1e-6
            % LPC分析
            lpc_order = min(12, round(fs/1000) + 2); % 自适应LPC阶数
            a = lpc(frame, lpc_order);
            
            % 调整共振峰频率
            roots_a = roots(a);
            
            % 缩放极点的角度（改变共振峰频率）
            angles = angle(roots_a);
            magnitudes = abs(roots_a);
            
            % 应用补偿
            new_angles = angles * compensation;
            new_roots = magnitudes .* exp(1j * new_angles);
            
            % 重建LPC系数
            new_a = real(poly(new_roots));
            
            % LPC合成
            residual = filter(a, 1, frame);
            y_frame = filter(1, new_a, residual);
            
            y_frames(:, i) = y_frame;
        end
    end
    
    % 重叠相加合成
    y = overlap_add(y_frames, hop_size);
    y = y(1:length(x)); % 修剪到原始长度
end

function y = formant_correction_spectral(x, compensation, fs)
% 基于频谱倾斜的简单共振峰校正
    
    % 设计一个简单的频谱倾斜滤波器
    if compensation > 1
        % 提升高频（补偿共振峰下移）
        [b, a] = butter(2, 0.4/compensation, 'high');
    else
        % 衰减高频（补偿共振峰上移）
        [b, a] = butter(2, 0.4*compensation);
    end
    
    y = filter(b, a, x);
    
    % 保持原始能量
    y = y * (rms(x) / rms(y));
end

function y = overlap_add(frames, hop_size)
% 重叠相加合成
    [frame_size, num_frames] = size(frames);
    y_length = (num_frames - 1) * hop_size + frame_size;
    y = zeros(y_length, 1);
    
    for i = 1:num_frames
        start_idx = (i - 1) * hop_size + 1;
        end_idx = start_idx + frame_size - 1;
        y(start_idx:end_idx) = y(start_idx:end_idx) + frames(:, i);
    end
end