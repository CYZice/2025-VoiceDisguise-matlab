% 测试新的倒谱域共振峰校正实现
clear; clc; close all;

% 添加项目路径
addpath('core');

% 生成测试信号
fs = 16000;
duration = 2.0;
t = 0:1/fs:duration-1/fs;

% 创建包含多个共振峰的合成语音信号
f0 = 100; % 基频
f1 = 500; % 第一共振峰
f2 = 1500; % 第二共振峰
f3 = 2500; % 第三共振峰

x = sin(2*pi*f0*t) + 0.5*sin(2*pi*f1*t) + 0.3*sin(2*pi*f2*t) + 0.2*sin(2*pi*f3*t);
x = x / max(abs(x)); % 归一化

% 测试倒谱域共振峰校正
compensation = 0.8; % 共振峰下移20%

fprintf('测试倒谱域共振峰校正...\n');
tic;
y_cepstral= formant_correction(x,4, fs, 'method', 'spectral_tilt', 'intensity', 0.6)
time_cepstral = toc;
fprintf('倒谱域方法处理时间: %.3f 秒\n', time_cepstral);

% 频谱分析
nfft = 4096;
[X, f] = periodogram(x, hamming(length(x)), nfft, fs);
[Y, ~] = periodogram(y_cepstral, hamming(length(y_cepstral)), nfft, fs);

% 绘制结果
figure('Position', [100, 100, 1200, 800]);

% 时域波形
subplot(2,2,1);
plot(t(1:min(1000, length(t))), x(1:min(1000, length(x))), 'b-', 'LineWidth', 1.5);
hold on;
plot(t(1:min(1000, length(t))), y_cepstral(1:min(1000, length(y_cepstral))), 'r-', 'LineWidth', 1.5);
legend('原始信号', '校正后信号', 'Location', 'best');
xlabel('时间 (s)');
ylabel('幅度');
title('时域波形比较');
grid on;

% 频谱比较
subplot(2,2,2);
semilogy(f, X, 'b-', 'LineWidth', 1.5);
hold on;
semilogy(f, Y, 'r-', 'LineWidth', 1.5);
legend('原始频谱', '校正后频谱', 'Location', 'best');
xlabel('频率 (Hz)');
ylabel('功率谱密度');
title('频谱比较');
xlim([0, 4000]);
grid on;

% 共振峰分析
subplot(2,2,3);
plot(f, 10*log10(X), 'b-', 'LineWidth', 1.5);
hold on;
plot(f, 10*log10(Y), 'r-', 'LineWidth', 1.5);
legend('原始信号', '校正后信号', 'Location', 'best');
xlabel('频率 (Hz)');
ylabel('功率 (dB)');
title('共振峰分析');
xlim([0, 4000]);
grid on;

% 频谱包络比较
subplot(2,2,4);
% 使用简单的移动平均平滑频谱
window_size = 50;
X_smooth = movmean(10*log10(X), window_size);
Y_smooth = movmean(10*log10(Y), window_size);
plot(f, X_smooth, 'b-', 'LineWidth', 2);
hold on;
plot(f, Y_smooth, 'r-', 'LineWidth', 2);
legend('原始包络', '校正后包络', 'Location', 'best');
xlabel('频率 (Hz)');
ylabel('平滑功率 (dB)');
title('频谱包络比较');
xlim([0, 4000]);
grid on;

% 保存结果
audiowrite('test_original.wav', x, fs);
y_normalized = y_cepstral / max(abs(y_cepstral));
audiowrite('test_cepstral_corrected.wav', y_normalized, fs);

fprintf('测试完成！结果已保存为 test_original.wav 和 test_cepstral_corrected.wav\n');
fprintf('共振峰校正因子: %.1f (下移 %.0f%%)\n', compensation, (1-compensation)*100);