function plot_frequency_response(b, a, fs, title_str)
% 绘制滤波器频率响应 - 修复版
% b, a: 滤波器系数
% fs: 采样率
% title_str: 标题

    if nargin < 4
        title_str = '滤波器频率响应';
    end
    
    % 检查输入参数
    if isempty(b) || isempty(a)
        error('滤波器系数b和a不能为空');
    end
    
    figure('Position', [150, 150, 900, 600]);
    
    try
        % 频率响应 - 使用正确的频率向量
        N = 1024;
        [H, w] = freqz(b, a, N, fs); % 直接得到Hz单位的频率响应
        
        % 正确的频率轴（freqz已经返回Hz单位）
        f = w;
        
        % 幅度响应 (dB)
        mag_dB = 20*log10(abs(H) + eps); % 避免log10(0)
        
        subplot(3,1,1);
        plot(f, mag_dB, 'LineWidth', 2);
        xlabel('频率 (Hz)');
        ylabel('幅度 (dB)');
        title([title_str ' - 幅度响应']);
        grid on;
        xlim([0, min(10000, fs/2)]);
        ylim([-100, 5]); % 固定范围便于比较
        
        % 相位响应
        subplot(3,1,2);
        phase_deg = unwrap(angle(H)) * 180/pi;
        plot(f, phase_deg, 'LineWidth', 2);
        xlabel('频率 (Hz)');
        ylabel('相位 (度)');
        title('相位响应');
        grid on;
        xlim([0, min(10000, fs/2)]);
        
        % 群延迟
        subplot(3,1,3);
        [gd, f_gd] = grpdelay(b, a, N, fs);
        plot(f_gd, gd/fs*1000, 'LineWidth', 2); % 转换为毫秒
        xlabel('频率 (Hz)');
        ylabel('群延迟 (ms)');
        title('群延迟');
        grid on;
        xlim([0, min(10000, fs/2)]);
        
        % 计算滤波器特性
        fprintf('=== 滤波器特性 ===\n');
        fprintf('滤波器阶数: %d\n', length(b)-1);
        
        % 找到通带特性
        passband_idx = find(f <= 1000); % 1kHz以内作为通带参考
        if ~isempty(passband_idx)
            passband_ripple = max(mag_dB(passband_idx)) - min(mag_dB(passband_idx));
            fprintf('通带波动: %.2f dB\n', passband_ripple);
        end
        
        % 找到-3dB点
        max_mag = max(mag_dB);
        idx_3db = find(mag_dB <= max_mag-3, 1);
        if ~isempty(idx_3db) && idx_3db > 1
            fprintf('-3dB 频率: %.1f Hz\n', f(idx_3db));
        end
        
        % 检查稳定性
        r = roots(a);
        if all(abs(r) < 1)
            fprintf('滤波器稳定\n');
        else
            fprintf('警告: 滤波器可能不稳定\n');
        end
        
    catch ME
        fprintf('绘制频响失败: %s\n', ME.message);
        
        % 简单绘图作为备用
        subplot(1,1,1);
        plot(0,0);
        text(0.5, 0.5, '频响计算失败', 'HorizontalAlignment', 'center');
        title('错误');
    end
end