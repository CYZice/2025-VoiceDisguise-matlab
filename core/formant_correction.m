function y = formant_correction(x, y,semitones, fs, varargin)
% 共振峰校正 - 提高变调后的音质自然度
% x: 原信号
% y: 变调后的信号
% semitones: 半音变化量
% fs: 采样率
% varargin: 校正强度参数
cepstral_order = round(fs / 1000);
p = inputParser;
addRequired(p, 'x', @isvector);
addRequired(p, 'semitones', @isnumeric);
addRequired(p, 'fs', @(x) x > 0);
addParameter(p, 'intensity', 0.5, @(x) x >= 0 && x <= 1); % 校正强度
addParameter(p, 'method', 'cepstral', @ischar); % 'lpc' 或 'spectral_tilt'
addParameter(p, 'beta', 1.5, @isnumeric);
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
        y = formant_correction_lpc(y, formant_compensation, fs);


    case 'cepstral'
        % 基于倒谱域的共振峰校正（迭代估计频谱包络）
        y = formant_preservation_cepstral(x,y,fs,cepstral_order,beta);

    otherwise
        y = formant_correction_lpc(y, formant_compensation, fs);
end
end

function y = formant_correction_lpc(x, compensation, fs)
% 基于LPC的共振峰校正
fprintf("使用基于LPC的共振峰校正");
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

function y = formant_correction_spectral1(x, compensation, fs)
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

function y = formant_correction_cepstral(x, compensation, fs)
% 基于倒谱域的共振峰校正 - 标准实现
% 采用标准的倒谱分析流程：信号分帧 → 加窗 → DFT → 对数能谱 → 倒谱分析 → 共振峰估计 → 频域校正

% 参数设置
frame_size = round(0.03 * fs);    % 30ms帧长
hop_size = round(frame_size / 4); % 25%重叠
nfft = 2^nextpow2(frame_size * 2); % FFT点数（零填充）
num_formants = 3;                % 估计前3个共振峰

% 分帧处理
frames = buffer(x, frame_size, frame_size - hop_size, 'nodelay');
y_frames = zeros(size(frames));

for i = 1:size(frames, 2)
    frame = frames(:, i);

    if max(abs(frame)) > 1e-6
        % 步骤1: 加窗处理
        window = hann(frame_size);
        windowed_frame = frame .* window;

        % 步骤2: DFT得到频谱
        X = fft(windowed_frame, nfft);

        % 步骤3: 计算对数能谱（标准倒谱分析使用对数功率谱）
        mag_X = abs(X);
        power_spectrum = mag_X .^ 2;
        log_power_spectrum = log(max(power_spectrum, 1e-10));

        % 步骤4: 逆傅里叶变换得到倒谱
        cepstrum = real(ifft(log_power_spectrum));

        % 步骤5: 倒谱分析与共振峰估计
        % 共振峰信息在低倒频率区域（通常1-3ms）
        max_quefrency = round(0.003 * fs);  % 3ms倒频率截止

        % 提取低倒频率部分（共振峰包络）
        low_quefrency_cepstrum = cepstrum(1:max_quefrency);

        % 创建倒谱滤波器（低通滤波器）
        lifter = zeros(nfft, 1);
        lifter(1:max_quefrency) = 1;

        % 应用倒谱滤波提取共振峰包络
        filtered_cepstrum = cepstrum .* lifter;

        % 转换回频域得到共振峰包络
        formant_envelope = real(fft(filtered_cepstrum));

        % 步骤6: 共振峰校正
        % 应用补偿因子到共振峰包络
        corrected_envelope = formant_envelope * compensation;

        % 计算频谱包络比率
        envelope_ratio = exp(formant_envelope - corrected_envelope);

        % 确保频谱比率在正负频率部分对称
        if nfft > 1
            if mod(nfft, 2) == 0
                % 偶数长度FFT
                envelope_ratio(nfft/2+2:end) = conj(envelope_ratio(nfft/2:-1:2));
            else
                % 奇数长度FFT
                envelope_ratio((nfft+3)/2:end) = conj(envelope_ratio((nfft+1)/2:-1:2));
            end
        end

        % 应用频谱包络比率调整原始频谱
        Y = X .* envelope_ratio;

        % 步骤7: 逆变换回时域
        y_frame = real(ifft(Y, nfft));
        y_frame = y_frame(1:frame_size) .* window;

        y_frames(:, i) = y_frame;
    end
end

% 重叠相加合成
y = overlap_add(y_frames, hop_size);
y = y(1:length(x)); % 修剪到原始长度

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


function y = formant_preservation_cepstral(original_signal, pitch_shifted_signal, fs, cepstral_order,beta)
% 基于文档描述的迭代式倒谱域共振峰保持算法
% 输入:
%   original_signal     - 原始音频信号
%   pitch_shifted_signal - 变调后的音频信号
%   fs                  - 采样率
%   cepstral_order      - 倒谱阶数（控制倒频率带宽）
% 输出:
%   y - 共振峰校正后的音频信号
fprintf("使用基于倒谱域的共振峰保持算法");
if nargin < 4
    cepstral_order = round(fs / 1000);  % 默认约1ms对应的倒谱阶数
end
if nargin < 5
    beta = 1;   % 1 表示不移动共振峰（你的原逻辑）
end

% 参数设置
frame_size = round(0.03 * fs);          % 30ms帧长
hop_size = round(frame_size / 4);       % 75%重叠
nfft = 2^nextpow2(frame_size * 2);      % FFT点数
max_iterations = 100;                    % 最大迭代次数
tolerance = log(10^(1/20));             % 收敛容差 (约0.115)

% 确保信号长度一致
min_len = min(length(original_signal), length(pitch_shifted_signal));
original_signal = original_signal(1:min_len);
pitch_shifted_signal = pitch_shifted_signal(1:min_len);

% 分帧处理
original_frames = buffer(original_signal, frame_size, frame_size - hop_size, 'nodelay');
shifted_frames = buffer(pitch_shifted_signal, frame_size, frame_size - hop_size, 'nodelay');

num_frames = size(original_frames, 2);
y_frames = zeros(frame_size, num_frames);

% 窗函数
window = hann(frame_size);

for i = 1:num_frames
    orig_frame = original_frames(:, i) .* window;
    shifted_frame = shifted_frames(:, i) .* window;

    % 检查帧是否有足够能量
    if max(abs(orig_frame)) > 1e-6 && max(abs(shifted_frame)) > 1e-6
        % 计算频谱
        X = fft(orig_frame, nfft);
        Y = fft(shifted_frame, nfft);

        % 计算幅度谱（对数域）
        mag_X = abs(X);
        mag_Y = abs(Y);
        log_X = log(max(mag_X, 1e-10));
        log_Y = log(max(mag_Y, 1e-10));

        % 估计原始信号的频谱包络
        env_X = estimate_spectral_envelope(log_X, cepstral_order, max_iterations, tolerance);

        % 估计变调信号的频谱包络
        env_Y = estimate_spectral_envelope(log_Y, cepstral_order, max_iterations, tolerance);

        % 对原包络 env_X 进行频率轴拉伸/压缩
        env_target = scale_spectral_envelope(env_X, beta);

        % 对比原变调信号的包络 env_Y
        envelope_ratio = exp(env_target - env_Y);



        % 应用包络校正
        Y_corrected = Y .* envelope_ratio;

        % 逆变换回时域
        y_frame = real(ifft(Y_corrected, nfft));
        y_frame = y_frame(1:frame_size) .* window;

        y_frames(:, i) = y_frame;
    else
        % 低能量帧直接使用变调后的帧
        y_frames(:, i) = shifted_frame;
    end
end

% 重叠相加合成
y = overlap_add_synthesis(y_frames, hop_size, min_len);

% 归一化窗函数增益
y = normalize_ola_gain(y, window, hop_size, min_len);
end

function env = estimate_spectral_envelope(log_spectrum, cepstral_order, max_iterations, tolerance)
% 迭代式频谱包络估计算法
% 基于文档描述的倒谱域迭代估计方法
% 输入:
%   log_spectrum    - 对数幅度谱
%   cepstral_order  - 倒谱阶数（控制倒频率带宽）
%   max_iterations  - 最大迭代次数
%   tolerance       - 收敛容差
% 输出:
%   env - 估计的对数频谱包络

nfft = length(log_spectrum);

% 初始化: EnvXa = X (对数域)
env_a = log_spectrum;

for iter = 1:max_iterations
    % 步骤1: 倒谱低通滤波得到新估计 EnvXb
    env_b = cepstral_lowpass_filter(env_a, cepstral_order);

    % 步骤2: 取元素级最大值更新包络估计
    % EnvXa = max(EnvXa, EnvXb)
    env_a = max(env_a, env_b);

    % 检查收敛条件
    % 如果所有bins的估计对数包络都在原始对数谱的容差范围内
    diff = abs(env_b - log_spectrum);
    if all(diff <= tolerance)
        break;
    end
end

% 返回最终的平滑包络估计
env = env_b;
end

function filtered = cepstral_lowpass_filter(log_spectrum, cepstral_order)
% 倒谱域低通滤波
% 输入:
%   log_spectrum   - 对数幅度谱
%   cepstral_order - 保留的倒谱系数数量（控制倒频率带宽）
% 输出:
%   filtered - 低通滤波后的对数频谱（频谱包络）

nfft = length(log_spectrum);

% 计算倒谱（对数谱的IFFT）
cepstrum = real(ifft(log_spectrum));

% 创建低通lifter（倒谱滤波器）
% 保留低倒频率成分（0到cepstral_order）
lifter = zeros(nfft, 1);

% 保留第一个系数（DC分量）和低倒频率成分
% 注意：倒谱是对称的，需要保留两端
if cepstral_order >= nfft/2
    lifter(:) = 1;
else
    % 保留 [0, cepstral_order] 和 [nfft-cepstral_order+1, nfft-1] 的系数
    lifter(1:cepstral_order+1) = 1;
    lifter(nfft-cepstral_order+1:nfft) = 1;
end

% 应用lifter
filtered_cepstrum = cepstrum .* lifter;

% 转换回频域
filtered = real(fft(filtered_cepstrum));
end

function y = overlap_add_synthesis(frames, hop_size, output_length)
% 重叠相加合成
% 输入:
%   frames        - 帧矩阵 [frame_size x num_frames]
%   hop_size      - 帧移
%   output_length - 期望输出长度
% 输出:
%   y - 合成后的信号

[frame_size, num_frames] = size(frames);
y_length = (num_frames - 1) * hop_size + frame_size;
y = zeros(y_length, 1);

for i = 1:num_frames
    start_idx = (i - 1) * hop_size + 1;
    end_idx = start_idx + frame_size - 1;
    y(start_idx:end_idx) = y(start_idx:end_idx) + frames(:, i);
end

% 修剪到期望长度
if length(y) > output_length
    y = y(1:output_length);
end
end

function y = normalize_ola_gain(signal, window, hop_size, output_length)
% 归一化重叠相加增益
% 计算窗函数的重叠相加增益并进行归一化

frame_size = length(window);

% 计算窗函数平方的重叠相加
num_frames = ceil((output_length - frame_size) / hop_size) + 1;
gain_length = (num_frames - 1) * hop_size + frame_size;
gain = zeros(gain_length, 1);

window_squared = window .^ 2;

for i = 1:num_frames
    start_idx = (i - 1) * hop_size + 1;
    end_idx = start_idx + frame_size - 1;
    gain(start_idx:end_idx) = gain(start_idx:end_idx) + window_squared;
end

% 归一化
gain = gain(1:output_length);
gain(gain < 1e-6) = 1;  % 避免除零

y = signal ./ gain;
end


function env_scaled = scale_spectral_envelope(env, beta)
% 共振峰频率轴缩放
% 输入:
%   env   - 原始对数包络 (size: nfft)
%   beta  - 缩放因子 (beta<1 降共振峰，beta>1 升共振峰)
% 输出:
%   env_scaled - 频轴缩放后的对数包络

n = length(env);
freq = linspace(0, 1, n).';       % 归一化频率坐标
freq_scaled = freq / beta;        % 频率轴压缩或扩张

% 超出范围的裁剪到 0~1
freq_scaled(freq_scaled > 1) = 1;
freq_scaled(freq_scaled < 0) = 0;

% 插值获取新包络
env_scaled = interp1(freq, env, freq_scaled, 'linear','extrap');
end
