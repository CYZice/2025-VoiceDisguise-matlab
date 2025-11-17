function [b, a] = design_filter(filter_type, fc1, fc2, fs, order)
% 设计数字滤波器 - 修复版
% filter_type: 'lowpass', 'highpass', 'bandpass', 'bandstop'
% fc1, fc2: 截止频率（Hz）
% fs: 采样率
% order: 滤波器阶数

    if nargin < 5
        order = 4; % 降低阶数提高稳定性（默认4阶）
    end
    
    % 输入验证
    if fc1 <= 0 || fc1 >= fs/2
        error('截止频率1必须在0和奈奎斯特频率(%d Hz)之间', fs/2);
    end
    
    if strcmpi(filter_type, 'bandpass') || strcmpi(filter_type, 'bandstop')
        if fc2 <= fc1 || fc2 >= fs/2
            error('截止频率2必须在频率1和奈奎斯特频率(%d Hz)之间', fs/2);
        end
    end
    
    % 归一化频率（确保在0-1之间）
    nyquist = fs / 2;
    
    % 限制阶数避免数值问题
    max_order = 8; % 最大8阶
    order = min(order, max_order);
    
    fprintf('设计 %s 滤波器: 阶数=%d, 采样率=%d Hz\n', filter_type, order, fs);
    
    try
        switch lower(filter_type)
            case 'lowpass'
                Wn = fc1 / nyquist;
                if Wn >= 1, Wn = 0.99; end % 确保小于1
                [b, a] = butter(order, Wn, 'low');
                fprintf('低通截止频率: %.1f Hz\n', fc1);
                
            case 'highpass'
                Wn = fc1 / nyquist;
                if Wn <= 0, Wn = 0.01; end % 确保大于0
                [b, a] = butter(order, Wn, 'high');
                fprintf('高通截止频率: %.1f Hz\n', fc1);
                
            case 'bandpass'
                Wn = [fc1, fc2] / nyquist;
                if Wn(1) <= 0, Wn(1) = 0.01; end
                if Wn(2) >= 1, Wn(2) = 0.99; end
                [b, a] = butter(order, Wn, 'bandpass');
                fprintf('带通截止频率: [%.1f, %.1f] Hz\n', fc1, fc2);
                
            case 'bandstop'
                Wn = [fc1, fc2] / nyquist;
                if Wn(1) <= 0, Wn(1) = 0.01; end
                if Wn(2) >= 1, Wn(2) = 0.99; end
                [b, a] = butter(order, Wn, 'stop');
                fprintf('带阻截止频率: [%.1f, %.1f] Hz\n', fc1, fc2);
                
            otherwise
                error('不支持的滤波器类型: %s', filter_type);
        end
        
        % 验证滤波器稳定性
        if ~isstable(b, a)
            warning('滤波器不稳定，尝试降低阶数');
            [b, a] = butter(2, Wn); % 降为2阶
        end
        
        fprintf('滤波器设计成功\n');
        
    catch ME
        fprintf('滤波器设计失败: %s\n', ME.message);
        fprintf('使用默认低通滤波器\n');
        % 备用方案
        Wn = 4000 / nyquist;
        [b, a] = butter(2, Wn, 'low');
    end
end

function stable = isstable(b, a)
% 检查滤波器稳定性
    r = roots(a);
    stable = all(abs(r) < 1);
end