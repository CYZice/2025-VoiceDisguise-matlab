function spectrum_analysis(x, fs, plot_title)
% 频谱分析
% x: 输入信号
% fs: 采样率
% plot_title: 图表标题

    if nargin < 3
        plot_title = '信号频谱';
    end
    
    % 计算FFT
    N = length(x);
    f = (0:N-1) * fs / N;
    X = fft(x);
    
    % 取正频率部分
    if mod(N,2) == 0
        k = N/2;
    else
        k = (N-1)/2;
    end
    f = f(1:k);
    X = X(1:k);
    
    % 幅度谱（dB）
    mag_dB = 20*log10(abs(X)/max(abs(X)));
    
    % 绘图
    figure('Position', [100, 100, 800, 600]);
    
    subplot(2,1,1);
    t = (0:N-1)/fs;
    plot(t, x);
    xlabel('时间 (s)');
    ylabel('幅度');
    title([plot_title ' - 时域波形']);
    grid on;
    
    subplot(2,1,2);
    plot(f, mag_dB);
    xlabel('频率 (Hz)');
    ylabel('幅度 (dB)');
    title([plot_title ' - 频谱']);
    xlim([0, min(8000, fs/2)]); % 显示到8kHz或奈奎斯特频率
    grid on;
    
    % 统计信息
    fprintf('=== 频谱分析结果 ===\n');
    fprintf('信号长度: %d 采样点\n', N);
    fprintf('时长: %.2f 秒\n', N/fs);
    fprintf('最大幅度: %.4f\n', max(abs(x)));
    fprintf('RMS: %.4f\n', rms(x));
    
    % 找到主要频率成分
    [peaks, locs] = findpeaks(abs(X), 'SortStr','descend', 'NPeaks',5);
    if ~isempty(peaks)
        fprintf('主要频率成分:\n');
        for i = 1:min(3, length(peaks))
            freq = f(locs(i));
            fprintf('  %.1f Hz (幅度: %.2f dB)\n', freq, 20*log10(peaks(i)/max(peaks)));
        end
    end
    fprintf('\n');
end