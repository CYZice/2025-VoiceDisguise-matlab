%% 时域波形对比测试 - 慢录快放 vs 快录慢放
% 图13：慢录快放的时域波形对比（2倍速）
% 图14：快录慢放的时域波形对比（2倍速）
% 音频文件：test.wav

%% 清理和初始化
clear; close all; clc;
fprintf('=== 时域波形对比测试 - 慢录快放 vs 快录慢放 ===\n');

%% 1. 读取音频文件
fprintf('正在读取音频文件 test.wav...\n');
try
    [x, fs] = audioread('test.wav');
    fprintf('音频文件读取成功！\n');
catch
    error('无法读取 test.wav 文件，请确保文件存在于当前目录');
end

% 如果是立体声，转换为单声道
if size(x, 2) > 1
    x = mean(x, 2);
    fprintf('检测到立体声，已转换为单声道\n');
end

% 信号基本信息
fprintf('信号长度: %d 样本 (%.2f 秒)\n', length(x), length(x)/fs);
fprintf('采样率: %d Hz\n', fs);

%% 2. 时间拉伸处理
fprintf('\n=== 时间拉伸处理 ===\n');

% 慢录快放：时间拉伸比例 0.5（变快2倍）
fprintf('慢录快放处理（时间拉伸比例 0.5，变快2倍）...\n');
y_fast = time_stretch(x, 0.5, fs);

% 快录慢放：时间拉伸比例 2.0（变慢2倍）
fprintf('快录慢放处理（时间拉伸比例 2.0，变慢2倍）...\n');
y_slow = time_stretch(x, 2.0, fs);

%% 3. 绘制对比图表
fprintf('\n=== 绘制时域波形对比图 ===\n');

% 创建时间轴
N_orig = length(x);
t_orig = (0:N_orig-1)/fs;

N_fast = length(y_fast);
t_fast = (0:N_fast-1)/fs;

N_slow = length(y_slow);
t_slow = (0:N_slow-1)/fs;

%% 图13：慢录快放的时域波形对比
figure('Position', [100, 500, 1200, 600]);

% 原始信号
subplot(2, 1, 1);
plot(t_orig, x, 'b-', 'LineWidth', 1.5);
xlabel('时间 (s)');
ylabel('幅度');
title('原始信号（正常速度）', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
axis tight;

% 快放信号（慢录快放）
subplot(2, 1, 2);
plot(t_fast, y_fast, 'r-', 'LineWidth', 1.5);
xlabel('时间 (s)');
ylabel('幅度');
title('慢录快放信号（时间拉伸比例 0.5，变快2倍）', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
axis tight;


%% 图14：快录慢放的时域波形对比
figure( 'Position', [100, 100, 1200, 600]);

% 原始信号
subplot(2, 1, 1);
plot(t_orig, x, 'b-', 'LineWidth', 1.5);
xlabel('时间 (s)');
ylabel('幅度');
title('原始信号（正常速度）', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
axis tight;

% 慢放信号（快录慢放）
subplot(2, 1, 2);
plot(t_slow, y_slow, 'g-', 'LineWidth', 1.5);
xlabel('时间 (s)');
ylabel('幅度');
title('快录慢放信号（时间拉伸比例 2.0，变慢2倍）', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
axis tight;


%% 4. 保存图表
fprintf('正在保存图表...\n');

% 保存图13
saveas(gcf, 'time_domain_comparison_slow_record_fast_play.png');
saveas(gcf, 'time_domain_comparison_slow_record_fast_play.fig');



fprintf('图表保存完成！\n');
fprintf('  - 慢录快放对比图: time_domain_comparison_slow_record_fast_play.png\n');
fprintf('  - 快录慢放对比图: time_domain_comparison_fast_record_slow_play.png\n');

%% 5. 输出处理结果统计信息
fprintf('\n=== 处理结果统计 ===\n');
fprintf('原始信号: 时长=%.2f秒，RMS=%.4f\n', N_orig/fs, rms(x));
fprintf('慢录快放: 时长=%.2f秒，RMS=%.4f\n', N_fast/fs, rms(y_fast));
fprintf('快录慢放: 时长=%.2f秒，RMS=%.4f\n', N_slow/fs, rms(y_slow));

fprintf('\n=== 测试完成！ ===\n');