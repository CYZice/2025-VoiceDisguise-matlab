
% 添加项目路径
addpath(genpath('core'));
addpath(genpath('analysis'));
addpath(genpath('io'));

% 生成测试信号或读取音频文件
% 方法1: 生成合成语音信号
fs = 16000; % 采样率
t = 0:1/fs:2; % 2秒时长
% 生成一个基础语音信号（带共振峰特征）
f0 = 120; % 基频120Hz
x = chirp(t, 80, t(end), 300); % 时变频率成分
x = x .* sin(2*pi*f0*t); % 调制产生共振峰效应
x = x + 0.7*sin(2*pi*2500*t) + 0.5*sin(2*pi*3500*t); % 添加高频率成分模拟共振峰
x = x + 0.05*randn(size(t)); % 添加噪声

% 方法2: 如果有实际音频文件，取消注释下面这行并提供文件路径
% [x, fs] = audioread('test.wav');

% 参数设置
semitones_up = 4; % 4个半音升调

fprintf('测试信号长度: %d samples (%.2f 秒)\n', length(x), length(x)/fs);
fprintf('采样率: %d Hz\n', fs);
fprintf('变调量: %+d 半音\n', semitones_up);

% 使用项目中正确的变调处理方法
% 调用pitch_shift函数进行完整的变调处理
shifted_x = pitch_shift(x, semitones_up, fs, 'formant_correction', false);

% 确保信号长度合适
min_len = min(length(x), length(shifted_x));
x = x(1:min_len);
shifted_x = shifted_x(1:min_len);

% 测试不同的共振峰校正方法
methods = {'lpc', 'spectral_tilt', 'cepstral'};
results = cell(length(methods), 1);
times = zeros(length(methods), 1);

for i = 1:length(methods)
    method = methods{i};
    fprintf('\n正在测试 %s 方法...\n', method);
    
    tic;
    switch method
        case 'lpc'
            y = formant_correction(shifted_x, semitones_up, fs, 'method', 'lpc', 'intensity', 0.6);
        case 'spectral_tilt'
            y = formant_correction(shifted_x, semitones_up, fs, 'method', 'spectral_tilt', 'intensity', 0.6);
        case 'cepstral'
            y = formant_correction(shifted_x, semitones_up, fs, 'method', 'cepstral', 'intensity', 0.6);
    end
    times(i) = toc;
    results{i} = y;
    
    fprintf('处理完成，耗时: %.4f 秒\n', times(i));
    
    % 保存结果（先进行归一化避免裁剪警告）
    y_normalized = y / max(abs(y));
    audiowrite(sprintf('result_%s.wav', method), y_normalized, fs);
end

% 结果比较
fprintf('\n=== 处理时间比较 ===\n');
for i = 1:length(methods)
    fprintf('%s 方法: %.4f 秒\n', methods{i}, times(i));
end


    figure('Name', '共振峰校正效果比较', 'Position', [100, 100, 1200, 800]);
    
% 显示原始信号
subplot(3, 2, [1, 2]);
plot((0:length(x)-1)/fs, x);
title('原始信号');
xlabel('时间 (秒)');
ylabel('幅度');
grid on;

% 显示变调后未经校正的信号
subplot(3, 2, [3, 4]);
plot((0:length(shifted_x)-1)/fs, shifted_x);
title('变调后未经校正的信号');
xlabel('时间 (秒)');
ylabel('幅度');
grid on;

% 显示各方法校正后的信号
for i = 1:length(methods)
    subplot(3, 2, 4+i);
    plot((0:length(results{i})-1)/fs, results{i});
    title(sprintf('%s 方法校正后', methods{i}));
    xlabel('时间 (秒)');
    ylabel('幅度');
    grid on;
end

% 频谱比较
figure('Name', '频谱比较', 'Position', [150, 150, 1000, 600]);

nfft = 2^nextpow2(length(x));
f = (0:nfft/2)*fs/nfft;

% 原始信号频谱
subplot(2, 2, 1);
X = fft(x, nfft);
plot(f, 20*log10(abs(X(1:nfft/2+1))));
title('原始信号频谱');
xlabel('频率 (Hz)');
ylabel('幅度 (dB)');
grid on;

% 变调后信号频谱
subplot(2, 2, 2);
X_shifted = fft(shifted_x, nfft);
plot(f(1:length(X_shifted)/2+1), 20*log10(abs(X_shifted(1:length(X_shifted)/2+1))));
title('变调后信号频谱');
xlabel('频率 (Hz)');
ylabel('幅度 (dB)');
grid on;

% 各方法校正后频谱
colors = {'r', 'g', 'b'};
for i = 1:length(methods)
    subplot(2, 2, 2+i);
    Y = fft(results{i}, nfft);
    plot(f(1:length(Y)/2+1), 20*log10(abs(Y(1:length(Y)/2+1))), 'Color', colors{i});
    title(sprintf('%s 方法校正后频谱', methods{i}));
    xlabel('频率 (Hz)');
    ylabel('幅度 (dB)');
    grid on;
end


fprintf('\n测试完成！结果已保存为WAV文件。\n');
