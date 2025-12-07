function plot_signals_spectrum(signals, fs, titles)
    n_signals = length(signals);
    
    % 频谱对比
    figure('Position', [200, 200, 1800, 800]);
    
    for i = 1:n_signals
        x = signals{i};
        N = length(x);
        
        % 计算频谱
        X = fft(x);
        f = (0:floor(N/2)-1) * fs / N;
        mag = 20*log10(abs(X(1:floor(N/2))) + eps);
        mag = mag - max(mag); % 归一化到0dB
        
        subplot(n_signals, 1, i);
        plot(f, mag);
        xlabel('f');
        ylabel('dB');
        title(titles{i});
        grid on;
    end
    
    xlabel('频率 (Hz)');
    ylabel('幅度 (dB)');
    title('信号频谱对比');
    legend('show');
    grid on;
    xlim([0, min(18000, fs)]);
    ylim([-150, 10]);


end