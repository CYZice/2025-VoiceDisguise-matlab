function plot_formant_correction_comparison(x, fs, semitones_up, varargin)
% 专业绘图函数：共振峰校正效果综合对比（重构版）
% 基于8类图表模板彻底重构，提供独立figure生成和完整性能评估
% 输入：
%   x - 原始信号
%   fs - 采样率
%   semitones_up - 变调半音数
%   varargin - 可选参数：'methods', 'intensity', 'show_plots', 'save_figures'
%
% 输出：生成8类专业对比图表和完整性能评估报告
addpath("core")

% 参数解析
p = inputParser;
addRequired(p, 'x', @isnumeric);
addRequired(p, 'fs', @isscalar);
addRequired(p, 'semitones_up', @isscalar);
addParameter(p, 'methods', {'lpc', 'cepstral','mlt'}, @iscell);
addParameter(p, 'intensity', 0.6, @isscalar);
addParameter(p, 'show_plots', true, @islogical);
addParameter(p, 'save_figures', false, @islogical);
parse(p, x, fs, semitones_up, varargin{:});

methods = p.Results.methods;
intensity = p.Results.intensity;
show_plots = p.Results.show_plots;
save_figures = p.Results.save_figures;

fprintf('=== 共振峰校正效果可视化分析 ===\n');
fprintf('信号长度: %d 样本 (%.2f 秒)\n', length(x), length(x)/fs);
fprintf('采样率: %d Hz\n', fs);
fprintf('变调量: %+d 半音\n', semitones_up);
fprintf('校正方法: %s\n', strjoin(methods, ', '));

% 1. 核心处理
fprintf('\n[1/8] 应用变调处理...\n');
y_ps = pitch_shift(x, semitones_up, fs, 'formant_correction', false);
y_fc = pitch_shift(x, semitones_up, fs, 'formant_correction', true);
y_lpc = pitch_shift(x, semitones_up, fs, 'formant_correction', true);

% 确保信号长度一致
min_len = min([length(x), length(y_ps), length(y_fc), length(y_lpc)]);
x = x(1:min_len);
y_ps = y_ps(1:min_len);
y_fc = y_fc(1:min_len);
y_lpc = y_lpc(1:min_len);

% 2. 应用不同的共振峰校正方法
results = struct();
times = zeros(length(methods), 1);

for i = 1:length(methods)
    method = methods{i};
    fprintf('[2/8] 正在处理 %s 方法...\n', method);

    tic;
    switch method
        case 'lpc'
            y = pitch_shift(x, semitones_up, fs,'formant_correction',true,'method', 'lpc');
        case 'cepstral'
            y = pitch_shift(x, semitones_up, fs,'formant_correction',true,'method', 'cepstral');
        case 'mlt'
            y = shiftPitch(x, semitones_up,"PreserveFormants",true);
        otherwise
            error('未知的共振峰校正方法: %s', method);
    end
    times(i) = toc;

    % 确保结果信号长度一致
    min_len_result = min(min_len, length(y));
    results(i).method = method;
    results(i).signal = y(1:min_len_result);
    results(i).time = times(i);

    fprintf('    %s 方法处理完成，耗时: %.4f 秒\n', method, times(i));
end

% 3. 生成8类专业对比图表
if show_plots
    fprintf('\n[3/8] 生成8类专业对比图表...\n');

    % 图表1: 时域波形对比图
    plot_time_domain_comparison(x, y_ps, y_fc, results, fs, save_figures, semitones_up);

    % 图表2: 频谱图（FFT）对比
    plot_spectrum_comparison(x, y_ps, y_fc, results, fs, save_figures, semitones_up);

    % 图表3: 包络对比图（核心）
    plot_envelope_comparison(x, y_ps, y_fc, results, fs, save_figures, semitones_up);

    % 图表4: Formant提取结果标注
    plot_formant_tracking(x, y_ps, y_fc, results, fs, save_figures, semitones_up);


end

% 4. 控制台输出完整性能报告
fprintf('\n[4/8] 生成完整性能评估报告...\n');
generate_performance_report(x, y_ps, y_fc, results, fs, methods, times);

fprintf('\n=== 可视化分析完成！ ===\n');
end

%% 图表1: 时域波形对比图
function plot_time_domain_comparison(x, y_ps, y_fc, results, fs, save_figures, semitones_up)
fprintf('  生成时域波形对比图...\n');

figure('Name', sprintf('时域波形对比 (变调: %d 半音)', semitones_up), ...
    'Position', [100, 100, 1200, 600], 'NumberTitle', 'off');

t = (0:length(x)-1)/fs;
t_ps = (0:length(y_ps)-1)/fs;
t_fc = (0:length(y_fc)-1)/fs;

% 创建子图布局 - 每条线单独绘制
num_plots = 3 + length(results); % 基础3个信号 + 各方法结果
cols = 1
rows = ceil(num_plots/cols)-1; % 计算行数

% 1. 原始信号
subplot(rows, cols, 1);
plot(t, x, 'k', 'LineWidth', 1.5);
xlabel('Time (s)', 'FontSize', 10);
ylabel('Amplitude', 'FontSize', 10);
title('原始信号', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
% 动态设置显示范围，适配短信号
max_time = min([t(end), 4, max(0.1, t(end))]); % 至少显示0.1秒
xlim([0, max_time]);

% 2. 变调后信号
subplot(rows, cols, 2);
plot(t, x, 'k', 'LineWidth', 1.5);
plot(t_ps, y_ps, 'r', 'LineWidth', 1.5);
xlabel('Time (s)', 'FontSize', 10);
ylabel('Amplitude', 'FontSize', 10);
title('变调后', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
max_time = min([t_ps(end), 4, max(0.1, t_ps(end))]);
xlim([0, max_time]);


% 4. 各方法结果（单独子图）
colors = {'g', 'm', 'c', 'y'};
for i = 1:length(results)
    y = results(i).signal;
    t_y = (0:length(y)-1)/fs;
    subplot(rows, cols, 2+i);
    plot(t, x, 'k', 'LineWidth', 1.5);
    plot(t_y, y, colors{i}, 'LineWidth', 1.2);
    xlabel('Time (s)', 'FontSize', 10);
    ylabel('Amplitude', 'FontSize', 10);
    title(sprintf('%s校正', upper(results(i).method)), 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    % 动态设置显示范围
    max_time = min([t_y(end), 4, max(0.1, t_y(end))]);
    xlim([0, max_time]);
end

% 添加总标题
sgtitle(sprintf('Time-domain Waveform Comparison (Pitch Shift: %d semitones)', semitones_up), ...
    'FontSize', 14, 'FontWeight', 'bold');

if save_figures
    saveas(gcf, sprintf('time_domain_comparison_%dsemitones.png', semitones_up));
end
end

%% 图表2: 频谱图（FFT）对比 - 使用语音信号优化方法
function plot_spectrum_comparison(x, y_ps, y_fc, results, fs, save_figures, semitones_up)
fprintf('  生成频谱图对比...\n');

% 创建子图布局 - 每条线单独绘制
num_plots = 3 + length(results); % 基础3个信号 + 各方法结果
cols = 1; % 单列显示
rows = ceil(num_plots/cols); % 计算行数

figure('Name', sprintf('Spectrum Comparison (Pitch Shift: %d semitones)', semitones_up), ...
    'Position', [150, 100, 800, 1200], 'NumberTitle', 'off');

% 1. 原始信号频谱
subplot(rows, cols, 1);
[f_orig, mag_orig] = calculate_spectrum(x, fs);
plot(f_orig, mag_orig, 'k', 'LineWidth', 1.5);
xlabel('Frequency (Hz)', 'FontSize', 10);
ylabel('Magnitude (dB)', 'FontSize', 10);
title('原始信号频谱', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
xlim([0 5000]);
ylim([-80, 5]); % 设置合理的dB范围

% 2. 变调后信号频谱对比
subplot(rows, cols, 2);
[f_ps, mag_ps] = calculate_spectrum(y_ps, fs);
plot(f_orig, mag_orig, 'k', 'LineWidth', 1.5); hold on;
plot(f_ps, mag_ps, 'r', 'LineWidth', 1.5);
xlabel('Frequency (Hz)', 'FontSize', 10);
ylabel('Magnitude (dB)', 'FontSize', 10);
title('变调后频谱对比', 'FontSize', 12, 'FontWeight', 'bold');
legend({'原始', '变调后'}, 'Location', 'best', 'FontSize', 8);
grid on;
xlim([0 5000]);
ylim([-80, 5]);


% 4. 各方法结果频谱对比（单独子图）
colors = {'g', 'm', 'c', 'y'};
for i = 1:length(results)
    y_signal = results(i).signal;
    % 确保信号足够长进行频谱分析
    if length(y_signal) >= 256 % 最小信号长度要求
        [f_result, mag_result] = calculate_spectrum(y_signal, fs);
        subplot(rows, cols, 2+i);
        plot(f_orig, mag_orig, 'k', 'LineWidth', 1.5); hold on;
        plot(f_result, mag_result, colors{i}, 'LineWidth', 1.2);
        xlabel('Frequency (Hz)', 'FontSize', 10);
        ylabel('Magnitude (dB)', 'FontSize', 10);
        title(sprintf('%s校正频谱', upper(results(i).method)), 'FontSize', 12, 'FontWeight', 'bold');
        legend({'原始', sprintf('%s校正', upper(results(i).method))}, 'Location', 'best', 'FontSize', 8);
        grid on;
        xlim([0 5000]);
        ylim([-80, 5]);
    else
        subplot(rows, cols, 2+i);
        text(0.5, 0.5, '信号太短，无法生成有效频谱', ...
            'HorizontalAlignment', 'center', 'FontSize', 12);
        title(sprintf('%s校正频谱', upper(results(i).method)), 'FontSize', 12, 'FontWeight', 'bold');
        xlim([0 1]);
        ylim([0 1]);
    end
end

% 添加总标题
sgtitle(sprintf('Spectrum Comparison (Pitch Shift: %d semitones)', semitones_up), ...
    'FontSize', 14, 'FontWeight', 'bold');

if save_figures
    saveas(gcf, sprintf('spectrum_comparison_%dsemitones.png', semitones_up));
end
end

%% 辅助函数：计算语音信号频谱（使用您提供的方法）
function [f, mag] = calculate_spectrum(x, fs)
% 确保信号非空
if isempty(x) || all(x == 0) || length(x) < 2
    f = 0:100:5000;
    mag = zeros(size(f)) - 80; % 返回-80dB的静音频谱
    return;
end

% 计算信号长度
N = length(x);

% 计算频谱
X = fft(x);
f = (0:floor(N/2)) * fs / N;
mag = 20*log10(abs(X(1:floor(N/2)+1)) + eps);

% 确保有有效数据
if ~isempty(mag) && max(mag) > min(mag)
    mag = mag - max(mag); % 归一化到0dB
end
end

%% 图表3: 包络对比图（核心）
function plot_envelope_comparison(x, y_ps, y_fc,results, fs, save_figures, semitones_up)
fprintf('  生成频谱包络对比图...\n');

% 计算各信号的频谱包络（使用倒谱法）- 适配不同信号长度
% 确保窗口大小不超过信号长度
win_size = min([1024, length(x), length(y_ps), length(y_fc)]);
overlap_size = round(win_size * 0.5); % 50%重叠
nfft_size = max(2048, win_size); % 确保nfft足够大

[Pxx1, f1] = pwelch(x, hamming(win_size), overlap_size, nfft_size, fs);
min_nfft = max(512, min(length(x), 2048)); % 确保nfft适中
[env1_db, ~, ~] = extract_spectral_envelope_cepstral(x, fs, 'nfft', min_nfft, 'mcep', 29);

[Pxx2, f2] = pwelch(y_ps, hamming(win_size), overlap_size, nfft_size, fs);
min_nfft = max(512, min(length(y_ps), 2048));
[env2_db, ~, ~] = extract_spectral_envelope_cepstral(y_ps, fs, 'nfft', min_nfft, 'mcep', 29);

[Pxx3, f3] = pwelch(y_fc, hamming(win_size), overlap_size, nfft_size, fs);
min_nfft = max(512, min(length(y_fc), 2048));
[env3_db, ~, ~] = extract_spectral_envelope_cepstral(y_fc, fs, 'nfft', min_nfft, 'mcep', 29);
metrics = evaluate_envelope_metrics(env1_db, env2_db);
fprintf('  未校正包络对比指标:\n');
fprintf('    MSE: %.4f\n', metrics.MSE);
fprintf('    MAE: %.4f\n', metrics.MAE);
fprintf('    Correlation: %.4f\n', metrics.Correlation);
fprintf('    SD: %.4f\n', metrics.SD);


for i = 1:length(results)
    y = results(i).signal;
    % 使用与前面一致的参数
    [Pxx, f_temp] = pwelch(y, hamming(win_size), overlap_size, nfft_size, fs);
    min_nfft = max(512, min(length(y), 2048));
    [env_result_db, ~, ~] = extract_spectral_envelope_cepstral(y, fs, 'nfft', min_nfft, 'mcep', 29);
    metrics = evaluate_envelope_metrics(env1_db, env_result_db);
    fprintf('  方法 %s 包络对比指标:\n', upper(results(i).method));
    fprintf('    MSE: %.4f\n', metrics.MSE);
    fprintf('    MAE: %.4f\n', metrics.MAE);
    fprintf('    Correlation: %.4f\n', metrics.Correlation);
    fprintf('    SD: %.4f\n', metrics.SD);
end

figure('Name', sprintf('Spectral Envelope Comparison (Pitch Shift: %d semitones)', semitones_up), ...
    'Position', [200, 100, 1200, 600], 'NumberTitle', 'off');



% 频率向量对齐（确保所有包络长度一致）
env_min = min([length(env1_db), length(env2_db), length(env3_db)]);
f_min = min([length(f1), length(f2), length(f3)]);
f_common = (0:env_min-1) * fs / (2 * env_min); % 统一频率刻度（基于倒谱包络长度）

% 截取包络到相同长度
env1_db = env1_db(1:env_min);
env2_db = env2_db(1:env_min);
env3_db = env3_db(1:env_min);


% 绘制包络
plot(f_common, env1_db, 'k', 'LineWidth', 2, 'DisplayName', 'Original'); hold on;
plot(f_common, env2_db, 'r', 'LineWidth', 2, 'DisplayName', 'Pitch-shifted');

% 绘制各方法结果
colors = {'g', 'm', 'c', 'y'};
for i = 1:length(results)
    % 适配信号长度的nfft参数
    y_signal = results(i).signal;
    min_nfft = max(512, min(length(y_signal), 2048));
    [env_result_db, ~, ~] = extract_spectral_envelope_cepstral(y_signal, fs, 'nfft', min_nfft, 'mcep', 29);
    env_result_db = env_result_db(1:env_min); % 截取到相同长度
    plot(f_common, env_result_db, colors{i}, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s校正', upper(results(i).method)));
    fprintf('  方法 %s 包络对比图已生成\n', upper(results(i).method));
end

xlim([0 5000]);
xlabel('Frequency (Hz)', 'FontSize', 12);
ylabel('Envelope (dB)', 'FontSize', 12);
title(sprintf('Spectral Envelope Comparison (Pitch Shift: %d semitones)', semitones_up), ...
    'FontSize', 14, 'FontWeight', 'bold');
legend('show', 'Location', 'bestoutside', 'FontSize', 10);
grid on;

if save_figures
    saveas(gcf, sprintf('envelope_comparison_%dsemitones.png', semitones_up));
end
end


function metrics = evaluate_envelope_metrics(E_orig, E_corr)
% 评估频谱包络校正性能
% 输入：
%   E_orig   原始频谱包络 (dB)
%   E_corr   校正后频谱包络 (dB)
% 输出：
%   metrics  结构体，包括以下指标：
%       .MSE
%       .MAE
%       .Correlation
%       .SD

% 输入验证
if isempty(E_orig) || isempty(E_corr)
    warning('Empty input arrays in evaluate_envelope_metrics');
    metrics.MSE = NaN;
    metrics.MAE = NaN;
    metrics.Correlation = NaN;
    metrics.SD = NaN;
    return;
end

% 确保列向量
E_orig = E_orig(:);
E_corr = E_corr(:);

% 确保长度一致
min_len = min(length(E_orig), length(E_corr));
if min_len < 2
    warning('Input arrays too short in evaluate_envelope_metrics');
    metrics.MSE = NaN;
    metrics.MAE = NaN;
    metrics.Correlation = NaN;
    metrics.SD = NaN;
    return;
end

% 截取到相同长度
E_orig = E_orig(1:min_len);
E_corr = E_corr(1:min_len);

% 1. MSE
metrics.MSE = mean((E_corr - E_orig).^2);

% 2. MAE
metrics.MAE = mean(abs(E_corr - E_orig));

% 3. Correlation
R = corrcoef(E_corr, E_orig);
metrics.Correlation = R(1,2);

% 4. Spectral Distortion（SD）
metrics.SD = sqrt(mean((E_corr - E_orig).^2));

end

%% 图表4: 共振峰对比分析 - 完整三状态对比
function plot_formant_tracking(x, y_ps, y_fc, results, fs, save_figures, semitones_up)
fprintf('  生成共振峰对比分析图...\n');

% 提取各信号的formants
try
    [F1_orig, F2_orig, F3_orig] = extract_formants_lpc(x, fs);
    [F1_ps, F2_ps, F3_ps] = extract_formants_lpc(y_ps, fs);
    [F1_fc, F2_fc, F3_fc] = extract_formants_lpc(y_fc, fs);
catch ME
    fprintf('Formant提取失败: %s\n', ME.message);
    F1_orig = NaN; F2_orig = NaN; F3_orig = NaN;
    F1_ps = NaN; F2_ps = NaN; F3_ps = NaN;
    F1_fc = NaN; F2_fc = NaN; F3_fc = NaN;
end

% 创建子图布局 - 三个状态对比
figure('Name', sprintf('Formant Analysis Comparison (Pitch Shift: %d semitones)', semitones_up), ...
    'Position', [100, 50, 1400, 900], 'NumberTitle', 'off');

% 1. 原始信号频谱和共振峰
subplot(2, 2, 1);
plot_single_formant_spectrum(x, fs, [F1_orig, F2_orig, F3_orig], '原始信号', 'k');
title(sprintf('原始信号共振峰 (F1=%.0f, F2=%.0f, F3=%.0f Hz)', ...
    F1_orig, F2_orig, F3_orig), 'FontSize', 12, 'FontWeight', 'bold');

% 2. 变调后信号频谱和共振峰
subplot(2, 2, 2);
plot_single_formant_spectrum(y_ps, fs, [F1_ps, F2_ps, F3_ps], '变调后', 'r');
title(sprintf('变调后共振峰 (F1=%.0f, F2=%.0f, F3=%.0f Hz)', ...
    F1_ps, F2_ps, F3_ps), 'FontSize', 12, 'FontWeight', 'bold');

% 3. 校正后信号频谱和共振峰
subplot(2, 2, 3);
plot_single_formant_spectrum(y_fc, fs, [F1_fc, F2_fc, F3_fc], '校正后', 'b');
title(sprintf('校正后共振峰 (F1=%.0f, F2=%.0f, F3=%.0f Hz)', ...
    F1_fc, F2_fc, F3_fc), 'FontSize', 12, 'FontWeight', 'bold');

% 4. 三状态共振峰对比总结
subplot(2, 2, 4);
plot_formant_comparison_summary([F1_orig, F2_orig, F3_orig], ...
    [F1_ps, F2_ps, F3_ps], ...
    [F1_fc, F2_fc, F3_fc], semitones_up);

% 添加总标题
sgtitle(sprintf('共振峰对比分析 (Pitch Shift: +%d semitones)', semitones_up), ...
    'FontSize', 16, 'FontWeight', 'bold');

if save_figures
    saveas(gcf, sprintf('formant_tracking_%dsemitones.png', semitones_up));
end

% 显示formant变化分析表格
display_formant_analysis_table([F1_orig, F2_orig, F3_orig], ...
    [F1_ps, F2_ps, F3_ps], ...
    [F1_fc, F2_fc, F3_fc], semitones_up);
end

%% 辅助函数：绘制单个信号的频谱和共振峰
function plot_single_formant_spectrum(signal, fs, formants, title_prefix, color)
% 计算频谱
N = length(signal);
% 根据信号长度动态设置nfft
if N < 512
    nfft = 512; % 最小nfft
elseif N < 1024
    nfft = 1024;
elseif N < 2048
    nfft = 2048;
else
    nfft = 2048; % 最大nfft，避免过大
end

if N < nfft
    signal = [signal; zeros(nfft-N, 1)]; % 零填充
end

Y = fft(signal, nfft);
magnitude_spectrum = abs(Y(1:floor(nfft/2)+1));
f = (0:floor(nfft/2)) * fs / nfft;

% 转换为dB并归一化
spectrum_db = 20*log10(magnitude_spectrum + eps);
spectrum_db = spectrum_db - max(spectrum_db);

% 绘制频谱
plot(f, spectrum_db, color, 'LineWidth', 1.5); hold on;
grid on;

% 确保频率向量是有效的
if length(f) > 1 && f(end) > f(1)
    xlim([0 min(4000, f(end))]); % 聚焦语音主要频段
else
    xlim([0 4000]);
end

% 确保幅度范围有效
if ~isempty(spectrum_db) && length(spectrum_db) > 0
    ylim([-80, 5]);
else
    ylim([-80, 0]);
end

xlabel('Frequency (Hz)', 'FontSize', 10);
ylabel('Magnitude (dB)', 'FontSize', 10);

% 标注共振峰位置
formant_colors = {'r', 'g', 'b'};
formant_names = {'F1', 'F2', 'F3'};
y_range = get(gca, 'YLim');

for i = 1:3
    if ~isnan(formants(i)) && formants(i) > 100 && formants(i) < 4000
        % 绘制垂直线标记共振峰
        plot([formants(i) formants(i)], y_range, '--', ...
            'Color', formant_colors{i}, 'LineWidth', 2);

        % 添加共振峰标签
        text(formants(i), max(y_range) - 10 - (i-1)*15, ...
            sprintf('%s\n%.0fHz', formant_names{i}, formants(i)), ...
            'Color', formant_colors{i}, ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 9, 'FontWeight', 'bold', ...
            'BackgroundColor', 'white', 'EdgeColor', 'none');
    end
end
end

%% 辅助函数：绘制共振峰对比总结
function plot_formant_comparison_summary(orig_formants, ps_formants, fc_formants, semitones)
% 创建共振峰对比图
formant_names = {'F1', 'F2', 'F3'};
colors = {'k', 'r', 'b'};
markers = {'o', 's', '^'};

% 计算偏移量
x = 1:3;
offset = 0.15;

% 绘制三组数据
hold on;

% 原始信号
valid_orig = ~isnan(orig_formants) & orig_formants > 0;
plot(x(valid_orig), orig_formants(valid_orig), ...
    [colors{1} markers{1}], 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', '原始');

% 变调后
valid_ps = ~isnan(ps_formants) & ps_formants > 0;
plot(x(valid_ps) + offset, ps_formants(valid_ps), ...
    [colors{2} markers{2}], 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', sprintf('变调后 (+%dst)', semitones));

% 校正后
valid_fc = ~isnan(fc_formants) & fc_formants > 0;
plot(x(valid_fc) + 2*offset, fc_formants(valid_fc), ...
    [colors{3} markers{3}], 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', sprintf('校正后 (%dst)', semitones));

% 添加数值标签
for i = 1:3
    if valid_orig(i)
        text(i, orig_formants(i) + 50, sprintf('%.0f', orig_formants(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', colors{1});
    end
    if valid_ps(i)
        text(i + offset, ps_formants(i) + 50, sprintf('%.0f', ps_formants(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', colors{2});
    end
    if valid_fc(i)
        text(i + 2*offset, fc_formants(i) + 50, sprintf('%.0f', fc_formants(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', colors{3});
    end
end

% 图形美化
set(gca, 'XTick', x + offset);
set(gca, 'XTickLabel', formant_names);
grid on;
xlabel('共振峰', 'FontSize', 12);
ylabel('频率 (Hz)', 'FontSize', 12);
title(sprintf('共振峰频率对比 (Pitch Shift: +%d semitones)', semitones), ...
    'FontSize', 12, 'FontWeight', 'bold');

% 确保有有效的数据才显示图例
all_formants = [orig_formants(valid_orig), ps_formants(valid_ps), fc_formants(valid_fc)];
if ~isempty(all_formants)
    ylim([min(all_formants) * 0.8, max(all_formants) * 1.2]);
end

legend('show', 'Location', 'best', 'FontSize', 10);


end

%% 辅助函数：显示共振峰分析表格
function display_formant_analysis_table(orig_formants, ps_formants, fc_formants, semitones)
fprintf('\n========== 共振峰变化分析 ==========\n');
fprintf('变调幅度: +%d semitones\n\n', semitones);

fprintf('状态\t\tF1(Hz)\tF2(Hz)\tF3(Hz)\t偏移分析\n');
fprintf('%-12s\t', '原始信号');
for i = 1:3
    if ~isnan(orig_formants(i))
        fprintf('%.0f\t', orig_formants(i));
    else
        fprintf('N/A\t');
    end
end
fprintf('基准\n');

fprintf('%-12s\t', '变调后');
for i = 1:3
    if ~isnan(ps_formants(i))
        fprintf('%.0f\t', ps_formants(i));
    else
        fprintf('N/A\t');
    end
end
fprintf('vs 原始\n');

fprintf('%-12s\t', '校正后');
for i = 1:3
    if ~isnan(fc_formants(i))
        fprintf('%.0f\t', fc_formants(i));
    else
        fprintf('N/A\t');
    end
end
fprintf('vs 原始\n');

% 计算并显示偏移分析
fprintf('\n偏移分析:\n');
formant_names = {'F1', 'F2', 'F3'};
for i = 1:3
    if ~isnan(orig_formants(i)) && ~isnan(ps_formants(i)) && ~isnan(fc_formants(i))
        ps_shift = ps_formants(i) - orig_formants(i);
        fc_correction = orig_formants(i) - fc_formants(i);
        correction_rate = (fc_correction / ps_shift) * 100;

        fprintf('%s: 变调偏移 %+.0fHz, 校正偏移 %+.0fHz, 校正率 %.1f%%\n', ...
            formant_names{i}, ps_shift, fc_correction, correction_rate);
    end
end
fprintf('=====================================\n');
end

%% 图表7: 性能评估条形图
function plot_performance_comparison(methods, times, save_figures, semitones_up)
fprintf('  生成性能评估条形图...\n');

figure('Name', sprintf('Performance Comparison (Pitch Shift: %d semitones)', semitones_up), ...
    'Position', [400, 100, 800, 600], 'NumberTitle', 'off');

% 创建条形图
bar_data = times';
bar_colors = lines(length(methods));

bar(bar_data, 'FaceColor', 'flat');
for i = 1:length(methods)
    b = bar_data(i);
    text(i, b + max(times)*0.02, sprintf('%.3f s', b), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

set(gca, 'XTickLabel', upper(methods));
ylabel('Processing Time (s)', 'FontSize', 12);
title(sprintf('Formant Correction Computational Cost (Pitch Shift: %d semitones)', semitones_up), ...
    'FontSize', 14, 'FontWeight', 'bold');
grid on;

% 添加相对效率标注
base_time = times(1);
fprintf('\nRelative Efficiency (baseline: %s = 1.0):\n', methods{1});
for i = 1:length(methods)
    efficiency = base_time / times(i);
    fprintf('%s: %.2f\n', methods{i}, efficiency);
end

if save_figures
    saveas(gcf, sprintf('performance_comparison_%dsemitones.png', semitones_up));
end
end

%% 图表8: 综合质量评估雷达图
function plot_quality_assessment(x, y_ps, y_fc, results, fs, save_figures, semitones_up)
fprintf('  生成综合质量评估雷达图...\n');

% 计算各信号的综合质量指标
quality_data = calculate_quality_metrics(x, y_ps, y_fc, results, fs);

figure('Name', sprintf('Quality Assessment (Pitch Shift: %d semitones)', semitones_up), ...
    'Position', [450, 100, 800, 600], 'NumberTitle', 'off');

% 创建雷达图
categories = {'Correlation', 'Formant\nPreservation', 'Envelope\nSmoothness', 'Spectral\nDistortion', 'Dynamic\nRange'};
num_categories = length(categories);

% 为每个方法创建雷达图
theta = linspace(0, 2*pi, num_categories + 1);

% 颜色定义
colors = {'k', 'r', 'b', 'g', 'm', 'c'};

% 绘制雷达图
for i = 1:length(quality_data)
    data = [quality_data(i).metrics.correlation, ...
        quality_data(i).metrics.formant_preservation, ...
        quality_data(i).metrics.smoothness, ...
        quality_data(i).metrics.spectral_distortion, ...
        quality_data(i).metrics.dynamic_range];
    data = [data data(1)]; % 闭合图形

    polarplot(theta, data, 'LineWidth', 2, 'Color', colors{i}, ...
        'DisplayName', quality_data(i).method);
    hold on;
end

% 设置雷达图属性
rlim([0 1]);
thetaticks(rad2deg(theta(1:end-1)));
thetaticklabels(categories);
title('Comprehensive Quality Assessment', 'FontSize', 14, 'FontWeight', 'bold');
legend('show', 'Location', 'bestoutside', 'FontSize', 10);

if save_figures
    saveas(gcf, sprintf('quality_assessment_%dsemitones.png', semitones_up));
end
end



%% 图表5: 时频图（Spectrogram）对比
function plot_spectrogram_comparison(x, y_ps, y_fc, results, fs, save_figures, semitones_up)
fprintf('  生成时频图对比...\n');

figure('Name', sprintf('Spectrogram Comparison (Pitch Shift: %d semitones)', semitones_up), ...
    'Position', [300, 100, 1400, 800], 'NumberTitle', 'off');

% 原始信号时频图
subplot(3,1,1);
spectrogram(x, hamming(512), 256, 1024, fs, 'yaxis');
title('Original Signal Spectrogram', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Frequency (Hz)', 'FontSize', 10);

% 变调信号时频图
subplot(3,1,2);
spectrogram(y_ps, hamming(512), 256, 1024, fs, 'yaxis');
title('Pitch-shifted Signal Spectrogram', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Frequency (Hz)', 'FontSize', 10);

% 共振峰校正信号时频图
subplot(3,1,3);
spectrogram(y_fc, hamming(512), 256, 1024, fs, 'yaxis');
title('Formant-corrected Signal Spectrogram', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)', 'FontSize', 10);
ylabel('Frequency (Hz)', 'FontSize', 10);

if save_figures
    saveas(gcf, sprintf('spectrogram_comparison_%dsemitones.png', semitones_up));
end
end

%% 图表6: 包络误差评估指标
function plot_envelope_metrics(x, y_ps, y_fc, results, fs, save_figures, semitones_up)
fprintf('  生成包络误差评估指标...\n');

% 计算各信号的频谱包络（使用倒谱法）- 适配信号长度
% 确保窗口大小不超过信号长度
win_size = min(1024, length(x), length(y_ps), length(y_fc));
overlap_size = round(win_size * 0.5); % 50%重叠
nfft_size = max(2048, win_size); % 确保nfft足够大

[Pxx1, f1] = pwelch(x, hamming(win_size), overlap_size, nfft_size, fs);
min_nfft1 = max(512, min(length(x), 2048)); % 确保nfft适中
[env1_db, ~, ~] = extract_spectral_envelope_cepstral(x, fs, 'nfft', min_nfft1, 'mcep', 29);

[Pxx2, f2] = pwelch(y_ps, hamming(win_size), overlap_size, nfft_size, fs);
min_nfft2 = max(512, min(length(y_ps), 2048));
[env2_db, ~, ~] = extract_spectral_envelope_cepstral(y_ps, fs, 'nfft', min_nfft2, 'mcep', 29);

[Pxx3, f3] = pwelch(y_fc, hamming(win_size), overlap_size, nfft_size, fs);
min_nfft3 = max(512, min(length(y_fc), 2048));
[env3_db, ~, ~] = extract_spectral_envelope_cepstral(y_fc, fs, 'nfft', min_nfft3, 'mcep', 29);

% 频谱重采样以对齐
env_len = min([length(env1_db) length(env2_db) length(env3_db)]);
E1 = env1_db(1:env_len);
E2 = env2_db(1:env_len);
E3 = env3_db(1:env_len);
f_common = (0:env_len-1) * fs / (2 * env_len); % 生成对应的频率向量

% 计算误差指标
MSE_ps = mean((E1 - E2).^2);
MSE_fc = mean((E1 - E3).^2);

MAE_ps = mean(abs(E1 - E2));
MAE_fc = mean(abs(E1 - E3));

Corr_ps = corrcoef(E1, E2);
Corr_ps = Corr_ps(1,2);
Corr_fc = corrcoef(E1, E3);
Corr_fc = Corr_fc(1,2);

SD_ps = sqrt(mean((E1 - E2).^2));
SD_fc = sqrt(mean((E1 - E3).^2));

% 创建指标表格和可视化
figure('Name', sprintf('Envelope Error Metrics (Pitch Shift: %d semitones)', semitones_up), ...
    'Position', [350, 100, 1200, 600], 'NumberTitle', 'off');

% 子图1: 误差指标表格
subplot(1,2,1);
T = table([MSE_ps; MSE_fc], [MAE_ps; MAE_fc], [Corr_ps; Corr_fc], [SD_ps; SD_fc], ...
    'VariableNames', {'MSE', 'MAE', 'Corr', 'SD'}, ...
    'RowNames', {'Pitch-shifted', 'Formant-corrected'});

% 显示表格
uitable('Data', T{:,:}, 'ColumnName', T.Properties.VariableNames, ...
    'RowName', T.Properties.RowNames, 'Position', [50 100 400 200]);
title('Envelope Error Metrics', 'FontSize', 12, 'FontWeight', 'bold');
axis off;

% 子图2: 包络差异图
subplot(1,2,2);
plot(f_common, E1 - E2, 'r', 'LineWidth', 2, 'DisplayName', 'Pitch-shifted vs Original'); hold on;
plot(f_common, E1 - E3, 'b', 'LineWidth', 2, 'DisplayName', 'Formant-corrected vs Original');
plot(f_common, zeros(size(f_common)), 'k--', 'LineWidth', 1);

xlabel('Frequency (Hz)', 'FontSize', 12);
ylabel('Envelope Difference (dB)', 'FontSize', 12);
title('Envelope Difference Analysis', 'FontSize', 12, 'FontWeight', 'bold');
legend('show', 'Location', 'best', 'FontSize', 10);
grid on;
xlim([0 5000]);

% 控制台输出详细指标
fprintf('\nEnvelope Error Metrics:\n');
fprintf('Method\t\t\tMSE\t\tMAE\t\tCorr\t\tSD\n');
fprintf('Pitch-shifted\t\t%.4f\t\t%.4f\t\t%.4f\t\t%.4f\n', MSE_ps, MAE_ps, Corr_ps, SD_ps);
fprintf('Formant-corrected\t%.4f\t\t%.4f\t\t%.4f\t\t%.4f\n', MSE_fc, MAE_fc, Corr_fc, SD_fc);

if save_figures
    saveas(gcf, sprintf('envelope_metrics_%dsemitones.png', semitones_up));
end
end

%% LPC Formant提取函数（用户提供的模板）
function [F1, F2, F3] = extract_formants_lpc(x, fs)
% 输入验证
if isempty(x) || any(~isfinite(x))
    F1 = NaN; F2 = NaN; F3 = NaN;
    return;
end

% 确保信号足够长
min_length = round(0.03 * fs); % 至少30ms
if length(x) < min_length

    F1 = NaN; F2 = NaN; F3 = NaN;
    return;
end

try
    % 预加重
    x = filter([1 -0.97], 1, x);

    % 分帧（取语音中心一帧）
    frame_len = round(0.03*fs);   % 30 ms
    frame_len = min(frame_len, length(x)); % 确保不超过信号长度
    % 计算信号中间位置的起始样本索引
    target_time = min(1.0, (length(x)/fs) * 0.5); % 使用信号中间位置，确保不超过信号长度
    start_sample = round(target_time * fs) + 1; % +1因为MATLAB索引从1开始

    % 确保起始位置在有效范围内
    start_sample = max(1, min(start_sample, length(x) - frame_len + 1));

    % 截取1秒处的语音帧
    frame = x(start_sample:start_sample + frame_len - 1) .* hamming(frame_len);

    % LPC阶数
    order = round(2*fs/1000) + 2;  % 例如 fs=16k => 34阶
    order = min(order, frame_len-1); % 确保阶数不超过帧长-1

    % LPC系数
    a = lpc(frame, order);

    % 验证LPC系数是否有效
    if any(~isfinite(a))
        F1 = NaN; F2 = NaN; F3 = NaN;
        return;
    end

    % 求极点
    roots_lpc = roots(a);

    % 验证极点是否有效
    if any(~isfinite(roots_lpc))
        F1 = NaN; F2 = NaN; F3 = NaN;
        return;
    end

    % 仅保留复数极点
    roots_lpc = roots_lpc(imag(roots_lpc) > 0);

    % 验证是否有足够的复数极点
    if length(roots_lpc) < 3
        F1 = NaN; F2 = NaN; F3 = NaN;
        return;
    end

    % 极点角频率
    angs = atan2(imag(roots_lpc), real(roots_lpc));
    freqs = angs * (fs/(2*pi));

    % 仅保留低频（0~4000Hz）
    freqs = sort(freqs);
    freqs = freqs(freqs > 90 & freqs < 4000);   % filter unrealistic F0

    % 返回F1 F2 F3
    if length(freqs) >= 3
        F1 = freqs(1);
        F2 = freqs(2);
        F3 = freqs(3);
    else
        F1 = NaN; F2 = NaN; F3 = NaN;
    end

catch ME
    % 如果发生任何错误，返回NaN
    fprintf('Formant提取错误: %s\n', ME.message);
    F1 = NaN; F2 = NaN; F3 = NaN;
end
end
%% 子函数：计算平滑度指标
function smoothness = calculate_smoothness(envelope, f)
% 使用二阶导数计算平滑度
df = f(2) - f(1);

% 计算一阶和二阶导数
first_deriv = gradient(envelope, df);
second_deriv = gradient(first_deriv, df);

% 平滑度指标（二阶导数的绝对值，越小越平滑）
smoothness = abs(second_deriv);

% 归一化
smoothness = smoothness / max(smoothness + eps);
end

%% 质量指标计算函数
function quality_data = calculate_quality_metrics(x, y_ps, y_fc, results, fs)
% 计算各信号的综合质量指标
quality_data = [];

% 计算参考信号（原始）的指标
ref_metrics = calculate_single_quality_metrics(x, x, fs, 'Original');
quality_data = [quality_data; ref_metrics];

% 计算变调信号的指标
ps_metrics = calculate_single_quality_metrics(x, y_ps, fs, 'Pitch-shifted');
quality_data = [quality_data; ps_metrics];

% 计算共振峰校正信号的指标
fc_metrics = calculate_single_quality_metrics(x, y_fc, fs, 'Formant-corrected');
quality_data = [quality_data; fc_metrics];

% 计算各方法结果的指标
for i = 1:length(results)
    method_metrics = calculate_single_quality_metrics(x, results(i).signal, fs, ...
        sprintf('%s', upper(results(i).method)));
    quality_data = [quality_data; method_metrics];
end
end

%% 单个信号质量指标计算
function metrics = calculate_single_quality_metrics(x_orig, x_comp, fs, method_name)
% 计算频谱包络（使用倒谱法）- 适配信号长度
min_nfft_orig = max(512, min(length(x_orig), 2048));
min_nfft_comp = max(512, min(length(x_comp), 2048));
[env_orig_db, ~, ~] = extract_spectral_envelope_cepstral(x_orig, fs, 'nfft', min_nfft_orig, 'mcep', 29);
[env_comp_db, ~, ~] = extract_spectral_envelope_cepstral(x_comp, fs, 'nfft', min_nfft_comp, 'mcep', 29);

% 对齐频谱
env_len = min(length(env_orig_db), length(env_comp_db));
env_orig = env_orig_db(1:env_len);
env_comp = env_comp_db(1:env_len);

% 生成频率向量（用于后续计算）
f_common = (0:env_len-1) * fs / (2 * env_len);

% 计算各项指标
metrics = struct();
metrics.method = method_name;

% 1. 频谱相关性 (归一化到0-1)
[R, ~] = corrcoef(env_orig, env_comp);
metrics.correlation = max(0, R(1,2));

% 2. 共振峰保持度
metrics.formant_preservation = calculate_formant_preservation_metric(env_orig, env_comp, f_common);

% 3. 包络平滑度 (基于二阶导数)
smoothness_orig = calculate_envelope_smoothness(env_orig, f_common);
smoothness_comp = calculate_envelope_smoothness(env_comp, f_common);
metrics.smoothness = 1 - abs(smoothness_comp - smoothness_orig) / (smoothness_orig + eps);
metrics.smoothness = max(0, min(1, metrics.smoothness));

% 4. 频谱失真度 (转换为质量分数)
spectral_distortion = mean((env_comp - env_orig).^2);
metrics.spectral_distortion = max(0, 1 - spectral_distortion / 100); % 归一化

% 5. 动态范围保持度
dr_orig = max(env_orig) - min(env_orig);
dr_comp = max(env_comp) - min(env_comp);
metrics.dynamic_range = min(1, max(0, 1 - abs(dr_comp - dr_orig) / (dr_orig + eps)));
end

%% 共振峰保持度计算
function preservation = calculate_formant_preservation_metric(envelope_orig, envelope_comp, f)
% 寻找原始包络的共振峰
[pks_orig, locs_orig_idx] = findpeaks(envelope_orig, 'MinPeakHeight', max(envelope_orig)-15, ...
    'MinPeakDistance', 150, 'MinPeakProminence', 2);

% 寻找比较包络的共振峰
[pks_comp, locs_comp_idx] = findpeaks(envelope_comp, 'MinPeakHeight', max(envelope_comp)-15, ...
    'MinPeakDistance', 150, 'MinPeakProminence', 2);

% 获取对应的频率值
locs_orig = f(locs_orig_idx);
locs_comp = f(locs_comp_idx);

% 计算共振峰匹配度
if length(pks_orig) == 0 || length(pks_comp) == 0
    preservation = 0;
    return;
end

% 匹配最近的共振峰
matches = 0;
tolerance = 100; % 100Hz容差

for i = 1:length(pks_orig)
    for j = 1:length(pks_comp)
        if abs(locs_orig(i) - locs_comp(j)) < tolerance
            matches = matches + 1;
            break;
        end
    end
end

total_possible = max(length(pks_orig), length(pks_comp));
preservation = matches / total_possible;
end

%% 包络平滑度计算
function smoothness = calculate_envelope_smoothness(envelope, f)
% 使用二阶导数计算平滑度
df = f(2) - f(1);
second_deriv = gradient(gradient(envelope, df), df);
smoothness = std(second_deriv);
end

%% 性能报告生成函数
function generate_performance_report(x, y_ps, y_fc, results, fs, methods, times)
fprintf('\n=== COMPREHENSIVE PERFORMANCE REPORT ===\n');
addpath("../core")
% 1. 基础信息
fprintf('\n1. BASIC INFORMATION:\n');
fprintf('   Signal length: %d samples (%.3f s)\n', length(x), length(x)/fs);
fprintf('   Sampling rate: %d Hz\n', fs);
%fprintf('   Pitch shift: %+d semitones\n', results(1).pitch_shift);

% 2. 处理时间分析
fprintf('\n2. PROCESSING TIME ANALYSIS:\n');
fprintf('   Method\t\tTime (s)\tRelative Speed\n');
base_time = times(1);
for i = 1:length(methods)
    relative_speed = base_time / times(i);
    fprintf('   %-15s\t%.4f\t\t%.2fx\n', methods{i}, times(i), relative_speed);
end

% 3. 质量指标汇总
fprintf('\n3. QUALITY METRICS SUMMARY:\n');
quality_data = calculate_quality_metrics(x, y_ps, y_fc, results, fs);

fprintf('   Method\t\tCorrelation\tFormant Pres.\tSmoothness\tSpectral Dist.\tDynamic Range\n');
for i = 1:length(quality_data)
    fprintf('   %-15s\t%.3f\t\t%.3f\t\t%.3f\t\t%.3f\t\t%.3f\n', ...
        quality_data(i).method, ...
        quality_data(i).metrics.correlation, ...
        quality_data(i).metrics.formant_preservation, ...
        quality_data(i).metrics.smoothness, ...
        quality_data(i).metrics.spectral_distortion, ...
        quality_data(i).metrics.dynamic_range);
end

% 4. 共振峰变化分析
fprintf('\n4. FORMANT FREQUENCY CHANGES:\n');
[F1_orig, F2_orig, F3_orig] = extract_formants_lpc(x, fs);
[F1_ps, F2_ps, F3_ps] = extract_formants_lpc(y_ps, fs);
[F1_fc, F2_fc, F3_fc] = extract_formants_lpc(y_fc, fs);

fprintf('   Formant\tOriginal\tPitch-shifted\tCorrected\tShift->Corrected\n');
fprintf('   F1 (Hz)\t%.0f\t\t%.0f\t\t%.0f\t\t%.0f\n', ...
    F1_orig, F1_ps, F1_fc, F1_fc - F1_ps);
fprintf('   F2 (Hz)\t%.0f\t\t%.0f\t\t%.0f\t\t%.0f\n', ...
    F2_orig, F2_ps, F2_fc, F2_fc - F2_ps);
fprintf('   F3 (Hz)\t%.0f\t\t%.0f\t\t%.0f\t\t%.0f\n', ...
    F3_orig, F3_ps, F3_fc, F3_fc - F3_ps);

% 5. 推荐方法
fprintf('\n5. RECOMMENDATIONS:\n');

% 找出最佳方法
best_method_idx = 1;
best_score = -inf;

for i = 1:length(quality_data)
    if strcmp(quality_data(i).method, 'Original')
        continue;
    end

    current_score = quality_data(i).metrics.correlation + ...
        quality_data(i).metrics.formant_preservation + ...
        quality_data(i).metrics.smoothness + ...
        quality_data(i).metrics.spectral_distortion + ...
        quality_data(i).metrics.dynamic_range;

    if current_score > best_score
        best_score = current_score;
        best_method_idx = i;
    end
end

fprintf('   Recommended method: %s\n', quality_data(best_method_idx).method);
fprintf('   Overall quality score: %.2f/5.0\n', best_score);

% 6. 使用建议
fprintf('\n6. USAGE RECOMMENDATIONS:\n');
fprintf('   - For real-time applications: Choose fastest method (%s)\n', methods{find(times == min(times), 1)});
fprintf('   - For highest quality: Choose %s method\n', quality_data(best_method_idx).method);
fprintf('   - For balanced performance: Consider method with best time/quality ratio\n');

fprintf('\n=== END OF REPORT ===\n');
end





%% 子函数：希尔伯特分析提取频谱包络（新增）
function envelope = extract_spectral_envelope_hilbert(Pxx_db, f)
% 使用希尔伯特变换提取解析包络
% 基于您提供的示例代码思想，应用于频谱数据

% 转换为线性尺度（希尔伯特变换需要实数信号）
Pxx_linear = 10.^(Pxx_db/10);

% 尝试不同的滤波器长度
filter_lengths = [30, 50, 80, 120];  % 不同的滤波器长度选项
best_envelope = [];
best_score = inf;

for fl = filter_lengths
    try
        % 使用希尔伯特变换计算解析包络
        [up, lo] = envelope(Pxx_linear, fl, 'analytic');

        % 取上包络（或平均上下包络）
        hilbert_envelope = (up + lo) / 2;

        % 转换回dB尺度
        hilbert_envelope_db = 10*log10(hilbert_envelope + eps);

        % 评估包络质量（与原始频谱的相关性和平滑度）
        [R, ~] = corrcoef(Pxx_db, hilbert_envelope_db);
        correlation = R(1,2);

        % 计算平滑度（二阶导数的标准差）
        df = f(2) - f(1);
        second_deriv = gradient(gradient(hilbert_envelope_db, df), df);
        smoothness = std(second_deriv);

        % 综合评分（相关性高且平滑度好）
        score = (1 - correlation) + smoothness * 0.1;

        % 选择最佳结果
        if score < best_score
            best_score = score;
            best_envelope = hilbert_envelope_db;
            best_fl = fl;
        end

    catch
        continue;  % 如果当前滤波器长度失败，尝试下一个
    end
end


envelope = best_envelope;

% 确保包络不会低于原始频谱太多
envelope = max(envelope, Pxx_db - 20);  % 限制最大差异为20dB
end

%% 辅助函数：自动确定最佳倒谱阶数
function optimal_mcep = find_optimal_cepstral_order(signal, fs, nfft)
%% 自动确定最佳倒谱阶数
% 基于包络平滑度和对原始频谱的拟合程度自动选择mcep

if nargin < 3
    nfft = 1024;
end

% 候选倒谱阶数范围（基于语音特性）
mcep_candidates = round(linspace(10, min(50, nfft/8), 15));

best_score = inf;
optimal_mcep = 29; % 默认值，参考文章使用29

for mcep = mcep_candidates
    try
        % 提取包络
        [envelope_db, ~, ~] = extract_spectral_envelope_cepstral(signal, fs, 'nfft', nfft, 'mcep', mcep);

        % 获取原始频谱（dB）
        Y = fft(signal, nfft);
        magnitude_spectrum = abs(Y(1:nfft/2));
        original_db = 10*log10(magnitude_spectrum + eps);

        % 评估包络质量
        valid_idx = isfinite(envelope_db) & isfinite(original_db);
        if sum(valid_idx) < 20
            continue;
        end

        % 1. 相关性评估
        R = corrcoef(original_db(valid_idx), envelope_db(valid_idx));
        correlation_score = 1 - abs(R(1,2));

        % 2. 平滑度评估（一阶导数方差）
        df = fs / nfft;
        first_deriv = diff(envelope_db(valid_idx)) / df;
        smoothness_score = std(first_deriv) / 100; % 归一化

        % 3. 包络在原始频谱之上的程度评估
        above_ratio = mean(envelope_db(valid_idx) >= original_db(valid_idx) - 3);
        above_score = 1 - above_ratio;

        % 综合评分
        total_score = correlation_score + smoothness_score + above_score;

        if total_score < best_score
            best_score = total_score;
            optimal_mcep = mcep;
        end

    catch ME
        fprintf('mcep=%d 失败: %s\n', mcep, ME.message);
        continue;
    end
end
end

function [envelope_db, cepstrum, cepstrum_liftered] = extract_spectral_envelope_cepstral(signal, fs, varargin)
%% 倒谱法提取语音信号频谱包络
% 基于参考文章案例2的标准实现
% 输入：
%   signal - 输入语音信号
%   fs - 采样频率
%   varargin - 可选参数：'nfft', nfft_value, 'mcep', mcep_value
% 输出：
%   envelope_db - 频谱包络(dB)
%   cepstrum - 原始倒谱
%   cepstrum_liftered - 滤波后的倒谱

% 参数解析
p = inputParser;
addOptional(p, 'nfft', 1024);
addOptional(p, 'mcep', 29); % 默认倒谱阶数，参考文章使用29
parse(p, varargin{:});

nfft = p.Results.nfft;
mcep = p.Results.mcep;

% 确保信号为列向量
signal = signal(:);

% 步骤1：计算信号的FFT频谱
Y = fft(signal, nfft);
half_nfft = floor(nfft/2); % 确保使用整数索引
magnitude_spectrum = abs(Y(1:half_nfft+1)); % 取正频率部分（包括奈奎斯特频率）
f = (0:half_nfft) * fs / nfft; % 频率刻度（修正：0到nfft/2）

% 步骤2：取对数（倒谱分析的关键步骤）
log_spectrum = log(magnitude_spectrum + eps); % 加eps避免log(0)

% 步骤3：进行逆FFT得到倒谱（参考文章中的 z = ifft(Y)）
cepstrum_full = ifft(log_spectrum, nfft);
cepstrum = cepstrum_full(1:half_nfft+1); % 取有效部分（包括奈奎斯特频率）

% 步骤4：倒滤波分离声门激励和声道响应（参考文章的关键步骤）
% 构建声道冲击响应的倒谱序列（参考文章中的zy构建方法）
cepstrum_liftered = zeros(nfft, 1);

% 保留前mcep+1个倒谱系数（对应声道冲击响应）
cepstrum_liftered(1:mcep+1) = cepstrum_full(1:mcep+1);

% 对称处理，保持实倒谱特性（参考文章中的对称构建）
% zy = [zy' zeros(1,1024-2*mcep-1) conj(zy(end:-1:2))']
if mcep+2 <= nfft-mcep % 确保索引有效
    cepstrum_liftered(mcep+2:nfft-mcep) = 0;
end
if nfft-mcep+1 <= nfft && mcep+1 >= 2 % 确保索引有效
    cepstrum_liftered(nfft-mcep+1:nfft) = conj(cepstrum_full(mcep+1:-1:2));
end

% 步骤5：FFT变换回频域，得到平滑的频谱包络（参考文章中的 ZY = fft(zy)）
log_envelope_full = fft(cepstrum_liftered);
log_envelope = real(log_envelope_full(1:half_nfft+1)); % 取实部（包括奈奎斯特频率）

% 步骤6：指数变换和dB转换
envelope_linear = exp(log_envelope);
envelope_db = 10*log10(envelope_linear + eps);

% 步骤7：原始频谱也转换为dB尺度用于比较
original_spectrum_db = 10*log10(magnitude_spectrum + eps);
end




%% 子函数：分析共振峰轨迹
function [time_axis, formants] = analyze_formant_trajectory(x, fs, frame_size, hop_size)
% 简化的共振峰轨迹分析（基于频谱峰值）
num_frames = floor((length(x) - frame_size) / hop_size) + 1;
formants = zeros(num_frames, 2); % 只分析前两个共振峰
time_axis = (0:num_frames-1) * hop_size / fs;

for i = 1:num_frames
    start_idx = (i-1)*hop_size + 1;
    end_idx = min(start_idx + frame_size - 1, length(x));
    frame = x(start_idx:end_idx);

    % 加窗
    frame = frame .* hamming(length(frame));

    % 计算频谱
    nfft = 1024;
    X = fft(frame, nfft);
    f = (0:nfft/2)*fs/nfft;
    mag = abs(X(1:nfft/2+1));

    % 寻找频谱峰值（简化共振峰估计）
    [pks, locs] = findpeaks(mag, 'MinPeakHeight', max(mag)*0.1, ...
        'MinPeakDistance', 100);

    % 处理找不到峰值的情况
    if isempty(locs)
        formants(i,:) = [0, 0]; % 设置为0表示未找到共振峰
        continue;
    end

    % 将索引转换为频率值
    freq_locs = f(locs);

    % 取前两个峰值作为共振峰
    if length(pks) >= 1
        formants(i,1) = freq_locs(1);
    end
    if length(pks) >= 2
        formants(i,2) = freq_locs(2);
    end
end
end