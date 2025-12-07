function y = formant_correction_main(x, y, semitones, fs, varargin)
% 共振峰校正 - 提高变调后的音质自然度
% x: 原信号, y: 变调后的信号, semitones: 半音变化量, fs: 采样率

p = inputParser;
addRequired(p, 'x', @isvector);
addRequired(p, 'semitones', @isnumeric);
addRequired(p, 'fs', @(x) x > 0);
addParameter(p, 'intensity', 0.5, @(x) x >= 0 && x <= 1);
addParameter(p, 'method', 'cepstral', @ischar);
addParameter(p, 'beta', 1.5, @isnumeric);
parse(p, x, semitones, fs, varargin{:});

if semitones == 0
    y = x;
    return;
end

% 计算共振峰补偿因子
formant_compensation = 1.0 - (p.Results.intensity * abs(semitones) / 24);
formant_compensation = max(0.5, min(1.5, formant_compensation));

switch p.Results.method
    case 'lpc'
        y = formant_correction_lpc(y, formant_compensation, fs);
    case 'cepstral'
        cepstral_order = round(fs / 1000);
        y = formant_preservation_cepstral(x, y, fs, cepstral_order, p.Results.beta);
    otherwise
        y = formant_correction_lpc(y, formant_compensation, fs);
end

end

function y = formant_correction_lpc(x, compensation, fs)
% 基于LPC的共振峰校正
frame_size = round(0.03 * fs);
hop_size = round(frame_size / 4);

frames = buffer(x, frame_size, frame_size - hop_size, 'nodelay');
y_frames = zeros(size(frames));

for i = 1:size(frames, 2)
    frame = frames(:, i);
    
    if max(abs(frame)) > 1e-6
        % LPC分析
        lpc_order = min(12, round(fs/1000) + 2);
        a = lpc(frame, lpc_order);
        
        % 调整共振峰频率
        roots_a = roots(a);
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
y = y(1:length(x));

end

function y = formant_preservation_cepstral(original_signal, pitch_shifted_signal, fs, cepstral_order, beta)
% 基于倒谱域的共振峰保持算法
% ... 省略详细的迭代估计和频域处理代码

frame_size = round(0.03 * fs);
hop_size = round(frame_size / 4);
nfft = 2^nextpow2(frame_size * 2);

% 确保信号长度一致
min_len = min(length(original_signal), length(pitch_shifted_signal));
original_signal = original_signal(1:min_len);
pitch_shifted_signal = pitch_shifted_signal(1:min_len);

% 分帧处理
original_frames = buffer(original_signal, frame_size, frame_size - hop_size, 'nodelay');
shifted_frames = buffer(pitch_shifted_signal, frame_size, frame_size - hop_size, 'nodelay');

num_frames = size(original_frames, 2);
y_frames = zeros(frame_size, num_frames);

window = hann(frame_size);

for i = 1:num_frames
    orig_frame = original_frames(:, i) .* window;
    shifted_frame = shifted_frames(:, i) .* window;
    
    if max(abs(orig_frame)) > 1e-6 && max(abs(shifted_frame)) > 1e-6
        % 计算频谱
        X = fft(orig_frame, nfft);
        Y = fft(shifted_frame, nfft);
        
        % 估计频谱包络
        env_X = estimate_spectral_envelope(log(abs(X) + 1e-10), cepstral_order);
        env_Y = estimate_spectral_envelope(log(abs(Y) + 1e-10), cepstral_order);
        
        % 频率轴缩放
        env_target = scale_spectral_envelope(env_X, beta);
        
        % 计算包络比率
        envelope_ratio = exp(env_target - env_Y);
        
        % 应用校正
        Y_corrected = Y .* envelope_ratio;
        
        % 逆变换回时域
        y_frame = real(ifft(Y_corrected, nfft));
        y_frame = y_frame(1:frame_size) .* window;
        
        y_frames(:, i) = y_frame;
    else
        y_frames(:, i) = shifted_frame;
    end
end

% 重叠相加合成
y = overlap_add_synthesis(y_frames, hop_size, min_len);
y = normalize_ola_gain(y, window, hop_size, min_len);

end

function env = estimate_spectral_envelope(log_spectrum, cepstral_order)
% 估计频谱包络（倒谱低通滤波）
nfft = length(log_spectrum);
cepstrum = real(ifft(log_spectrum));

% 创建低通lifter
lifter = zeros(nfft, 1);
lifter(1:cepstral_order+1) = 1;
lifter(nfft-cepstral_order+1:nfft) = 1;

% 应用lifter
filtered_cepstrum = cepstrum .* lifter;
env = real(fft(filtered_cepstrum));

end

function env_scaled = scale_spectral_envelope(env, beta)
% 频谱包络频率轴缩放
n = length(env);
freq = linspace(0, 1, n).';
freq_scaled = freq / beta;
freq_scaled(freq_scaled > 1) = 1;
freq_scaled(freq_scaled < 0) = 0;

env_scaled = interp1(freq, env, freq_scaled, 'linear', 'extrap');

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

function y = overlap_add_synthesis(frames, hop_size, output_length)
% 重叠相加合成（带长度控制）
y = overlap_add(frames, hop_size);
if length(y) > output_length
    y = y(1:output_length);
end
end

function y = normalize_ola_gain(signal, window, hop_size, output_length)
% 归一化重叠相加增益
frame_size = length(window);
num_frames = ceil((output_length - frame_size) / hop_size) + 1;
gain_length = (num_frames - 1) * hop_size + frame_size;
gain = zeros(gain_length, 1);

window_squared = window .^ 2;

for i = 1:num_frames
    start_idx = (i - 1) * hop_size + 1;
    end_idx = start_idx + frame_size - 1;
    gain(start_idx:end_idx) = gain(start_idx:end_idx) + window_squared;
end

gain = gain(1:output_length);
gain(gain < 1e-6) = 1;

y = signal ./ gain;

end