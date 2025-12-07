function plot_signals(signals, fs, titles)
% 绘制多个信号对比
% signals: 信号元胞数组
% fs: 采样率
% titles: 标题元胞数组

    n_signals = length(signals);
    
    figure('Position', [200, 200, 1000, 800]);
    
    for i = 1:n_signals
        x = signals{i};
        N = length(x);
        t = (0:N-1)/fs;
        
        subplot(n_signals, 1, i);
        plot(t, x);
        xlabel('时间 (s)');
        ylabel('幅度');
        title(titles{i});
        grid on;
        
        % 添加统计信息
        text(0.02, 0.98, sprintf('时长: %.2fs, RMS: %.4f', N/fs, rms(x)), ...
             'Units','normalized', 'VerticalAlignment','top', ...
             'BackgroundColor','white', 'FontSize',10);
    end
    
    % % 频谱对比
    % figure('Position', [300, 100, 1200, 600]);
    % 
    % for i = 1:n_signals
    %     x = signals{i};
    %     N = length(x);
    % 
    %     % 计算频谱
    %     X = fft(x);
    %     f = (0:floor(N/2)-1) * fs / N;
    %     mag = 20*log10(abs(X(1:floor(N/2))) + eps);
    %     mag = mag - max(mag); % 归一化到0dB
    % 
    %     subplot(n_signals, 1, i);
    %     plot(f, mag);
    %     xlabel('f');
    %     ylabel('dB');
    %     title(titles{i});
    %     grid on;
    % end
    % 
    % xlabel('频率 (Hz)');
    % ylabel('幅度 (dB)');
    % title('信号频谱对比');
    % legend('show');
    % grid on;
    % xlim([0, min(8000, fs/2)]);
    % ylim([-80, 5]);
end