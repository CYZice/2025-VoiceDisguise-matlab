function [f, mag_dB] = compute_spectrum(x, fs, fft_size)
% 通用频谱计算函数
    N = min(length(x), fft_size);
    x_short = x(1:N);
    
    window = hanning(N);
    x_windowed = x_short .* window;
    X = fft(x_windowed);
    
    f = (0:N/2-1) * fs / N;
    mag_dB = 20*log10(abs(X(1:N/2)) + eps);
    mag_dB = mag_dB - max(mag_dB);
end

