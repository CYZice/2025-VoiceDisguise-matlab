function plot_formant_comparison_demo(x, fs, semitones_up, varargin)
% 共振峰校正效果对比绘图（简化版）
% 输入：x - 原始信号, fs - 采样率, semitones_up - 变调半音数

addpath("core")

% 参数解析
p = inputParser;
addRequired(p, 'x', @isnumeric);
addRequired(p, 'fs', @isscalar);
addRequired(p, 'semitones_up', @isscalar);
addParameter(p, 'methods', {'lpc', 'cepstral'}, @iscell);
addParameter(p, 'show_plots', true, @islogical);
addParameter(p, 'save_figures', false, @islogical);
parse(p, x, fs, semitones_up, varargin{:});

methods = p.Results.methods;
show_plots = p.Results.show_plots;

fprintf('=== 共振峰校正效果对比 ===\n');
fprintf('信号长度: %d 样本 (%.2f 秒)\n', length(x), length(x)/fs);
fprintf('采样率: %d Hz\n', fs);
fprintf('变调量: %+d 半音\n', semitones_up);
fprintf('校正方法: %s\n', strjoin(methods, ', '));

% 1. 核心处理
y_ps = pitch_shift(x, semitones_up, fs, 'formant_correction', false);
y_fc = pitch_shift(x, semitones_up, fs, 'formant_correction', true);

% 确保信号长度一致
min_len = min([length(x), length(y_ps), length(y_fc)]);
x = x(1:min_len);
y_ps = y_ps(1:min_len);
y_fc = y_fc(1:min_len);

% 应用不同的共振峰校正方法
results = struct();
for i = 1:length(methods)
    method = methods{i};
    fprintf('正在处理 %s 方法...\n', method);
    
    switch method
        case 'lpc'
            y = pitch_shift(x, semitones_up, fs,'formant_correction',true,'method', 'lpc');
        case 'cepstral'
            y = pitch_shift(x, semitones_up, fs,'formant_correction',true,'method', 'cepstral');
        otherwise
            error('未知的共振峰校正方法: %s', method);
    end
    
    results(i).method = method;
    results(i).signal = y(1:min_len);
end

% 2. 生成对比图表
if show_plots
    plot_time_domain_simple(x, y_ps, y_fc, results, fs, semitones_up);
    plot_spectrum_simple(x, y_ps, y_fc, results, fs, semitones_up);
end

fprintf('\n=== 对比分析完成 ===\n');
end

function plot_time_domain_simple(x, y_ps, y_fc, results, fs, semitones_up)
% 简化时域波形对比
fprintf('  生成时域波形对比图...\n');

figure('Name', sprintf('时域波形对比 (变调: %d 半音)', semitones_up), ...
    'Position', [100, 100, 1000, 600], 'NumberTitle', 'off');

t = (0:length(x)-1)/fs;
t_ps = (0:length(y_ps)-1)/fs;
t_fc = (0:length(y_fc)-1)/fs;

% 原始信号
subplot(2,2,1);
plot(t, x, 'k', 'LineWidth', 1.5);
title('原始信号', 'FontSize', 12, 'FontWeight', 'bold');
grid on; axis tight;

% 变调后对比
subplot(2,2,2);
plot(t, x, 'k', 'LineWidth', 1.5); hold on;
plot(t_ps, y_ps, 'r', 'LineWidth', 1.5);
title('变调后对比', 'FontSize', 12, 'FontWeight', 'bold');
legend({'原始', '变调后'}, 'Location', 'best');
grid on;

% 校正后对比
subplot(2,2,3);
plot(t, x, 'k', 'LineWidth', 1.5); hold on;
plot(t_fc, y_fc, 'b', 'LineWidth', 1.5);
title('校正后对比', 'FontSize', 12, 'FontWeight', 'bold');
legend({'原始', '校正后'}, 'Location', 'best');
grid on;

% 各方法结果
subplot(2,2,4);
colors = {'g', 'm'};
plot(t, x, 'k', 'LineWidth', 1.5); hold on;
for i = 1:length(results)
    y = results(i).signal;
    t_y = (0:length(y)-1)/fs;
    plot(t_y, y, colors{i}, 'LineWidth', 1.2, 'DisplayName', upper(results(i).method));
end
title('各方法对比', 'FontSize', 12, 'FontWeight', 'bold');
legend('show', 'Location', 'best');
grid on;

sgtitle(sprintf('时域波形对比 (Pitch Shift: %d semitones)', semitones_up), ...
    'FontSize', 14, 'FontWeight', 'bold');
end

function plot_spectrum_simple(x, y_ps, y_fc, results, fs, semitones_up)
% 简化频谱对比
fprintf('  生成频谱对比图...\n');

figure('Name', sprintf('频谱对比 (变调: %d 半音)', semitones_up), ...
    'Position', [150, 100, 800, 600], 'NumberTitle', 'off');

% 计算频谱
[f_orig, mag_orig] = calculate_spectrum_simple(x, fs);
[f_ps, mag_ps] = calculate_spectrum_simple(y_ps, fs);
[f_fc, mag_fc] = calculate_spectrum_simple(y_fc, fs);

% 原始信号频谱
subplot(2,2,1);
plot(f_orig, mag_orig, 'k', 'LineWidth', 1.5);
title('原始信号频谱', 'FontSize', 12, 'FontWeight', 'bold');
grid on; xlim([0 4000]); ylim([-80, 5]);

% 变调后频谱对比
subplot(2,2,2);
plot(f_orig, mag_orig, 'k', 'LineWidth', 1.5); hold on;
plot(f_ps, mag_ps, 'r', 'LineWidth', 1.5);
title('变调后频谱对比', 'FontSize', 12, 'FontWeight', 'bold');
legend({'原始', '变调后'}, 'Location', 'best');
grid on; xlim([0 4000]); ylim([-80, 5]);

% 校正后频谱对比
subplot(2,2,3);
plot(f_orig, mag_orig, 'k', 'LineWidth', 1.5); hold on;
plot(f_fc, mag_fc, 'b', 'LineWidth', 1.5);
title('校正后频谱对比', 'FontSize', 12, 'FontWeight', 'bold');
legend({'原始', '校正后'}, 'Location', 'best');
grid on; xlim([0 4000]); ylim([-80, 5]);

% 各方法频谱对比
subplot(2,2,4);
colors = {'g', 'm'};
plot(f_orig, mag_orig, 'k', 'LineWidth', 1.5); hold on;
for i = 1:length(results)
    [f_result, mag_result] = calculate_spectrum_simple(results(i).signal, fs);
    plot(f_result, mag_result, colors{i}, 'LineWidth', 1.2, ...
        'DisplayName', upper(results(i).method));
end
title('各方法频谱对比', 'FontSize', 12, 'FontWeight', 'bold');
legend('show', 'Location', 'best');
grid on; xlim([0 4000]); ylim([-80, 5]);

sgtitle(sprintf('频谱对比 (Pitch Shift: %d semitones)', semitones_up), ...
    'FontSize', 14, 'FontWeight', 'bold');
end

function [f, mag] = calculate_spectrum_simple(x, fs)
% 简化频谱计算
N = length(x);
if N < 256
    f = 0:100:4000;
    mag = zeros(size(f)) - 80;
    return;
end

X = fft(x);
f = (0:floor(N/2)) * fs / N;
mag = 20*log10(abs(X(1:floor(N/2)+1)) + eps);

if ~isempty(mag) && max(mag) > min(mag)
    mag = mag - max(mag);
end
end