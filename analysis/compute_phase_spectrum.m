function [f, phase] = compute_phase_spectrum(x, fs, fft_size)
% 相位谱计算
    N = min(length(x), fft_size);
    x_short = x(1:N);
    
    window = hanning(N);
    x_windowed = x_short .* window;
    X = fft(x_windowed);
    
    f = (0:N/2-1) * fs / N;
    phase = unwrap(angle(X(1:N/2))) * 180/pi;
end