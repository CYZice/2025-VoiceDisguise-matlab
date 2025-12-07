% GUI工具函数

function update_status(fig, message)
% 更新状态栏
status_text = findobj(fig, 'Tag', 'status_text');
if ~isempty(status_text)
    set(status_text, 'String', message);
end
drawnow;
fprintf('%s\n', message);
end

function update_file_info(fig, filename, duration, fs)
% 更新文件信息显示
file_info = findobj(fig, 'Tag', 'file_info_text');
if ~isempty(file_info)
    info_str = sprintf('文件: %s (%.1fs, %dHz)', filename, duration, fs);
    set(file_info, 'String', info_str);
end
end

function update_waveform_plot(fig)
% 更新波形图
app_data = guidata(fig);

if isempty(app_data.original_signal)
    return;
end

axes(app_data.plot_handles.waveform_ax);
cla;

t = (0:length(app_data.original_signal)-1) / app_data.fs;
plot(t, app_data.original_signal, 'b', 'LineWidth', 1);
title('原始信号波形');
xlabel('时间 (s)');
ylabel('幅度');
grid on;

% 如果有处理结果，叠加显示
hold on;
if ~isempty(app_data.time_stretched)
    t_processed = (0:length(app_data.time_stretched)-1) / app_data.fs;
    plot(t_processed, app_data.time_stretched, 'r', 'LineWidth', 1);
    legend('原始', '处理结果', 'Location', 'best');
elseif ~isempty(app_data.pitch_shifted)
    t_processed = (0:length(app_data.pitch_shifted)-1) / app_data.fs;
    plot(t_processed, app_data.pitch_shifted, 'r', 'LineWidth', 1);
    legend('原始', '处理结果', 'Location', 'best');
end
hold off;
end

function update_spectrum_plot(fig)
% 更新频谱图
app_data = guidata(fig);

if isempty(app_data.original_signal)
    return;
end

axes(app_data.plot_handles.spectrum_ax);
cla;
fprintf('正在更新频谱图\n');

fs = app_data.fs;

% 计算原始信号频谱
x_orig = app_data.original_signal;
[f_orig, mag_orig] = compute_spectrum(x_orig, fs);
h1 = plot(f_orig, mag_orig, 'b', 'LineWidth', 1.5, 'DisplayName', '原始信号');

% 获取处理后信号
processed_signal = get_final_processed_signal(app_data);

% 如果有处理结果，绘制对比
if ~isempty(processed_signal)
    [f_proc, mag_proc] = compute_spectrum(processed_signal, fs);
    h2 = plot(f_proc, mag_proc, 'r', 'LineWidth', 1.5, 'DisplayName', '处理后信号');
    legend([h1, h2], 'Location', 'northeast');
    title('频谱分析对比');
else
    legend(h1, 'Location', 'northeast');
    title('频谱分析');
end

xlabel('频率 (Hz)');
ylabel('幅度 (dB)');
grid on;
xlim([0, min(12000, fs/2)]);
ylim([-120, 10]);
end

function update_filter_response_plot(fig, b, a)
% 更新滤波器响应图
app_data = guidata(fig);

axes(app_data.plot_handles.filter_ax);
cla;

% 计算频率响应
[H, w] = freqz(b, a, 1024, app_data.fs);
f = w;
mag_db = 20*log10(abs(H) + eps);

plot(f, mag_db, 'g', 'LineWidth', 2);
title('滤波器频率响应');
xlabel('频率 (Hz)');
ylabel('幅度 (dB)');
grid on;
xlim([0, min(12000, app_data.fs/2)]);
end

function update_result_plot(fig)
% 更新结果图
app_data = guidata(fig);

axes(app_data.plot_handles.result_ax);
cla;

if isempty(app_data.original_signal)
    text(0.5, 0.5, '请加载音频文件开始处理', ...
        'HorizontalAlignment', 'center', 'FontSize', 14);
    axis off;
    return;
end

% 显示处理结果统计信息
stats_text = generate_processing_stats(app_data);

text(0.1, 0.9, '处理结果统计', 'FontSize', 16, 'FontWeight', 'bold');
text(0.1, 0.7, stats_text, 'FontSize', 12, 'VerticalAlignment', 'top');
axis([0, 1, 0, 1]);
axis off;
end

function update_all_visualizations(fig)
% 统一更新所有可视化区域
update_waveform_plot(fig);
update_spectrum_plot(fig);
update_spectrogram_plot(fig);
update_result_plot(fig);
drawnow;
end

function processed_signal = get_final_processed_signal(app_data)
% 获取最终处理后的信号
processed_signal = [];
if ~isempty(app_data.time_stretched)
    processed_signal = app_data.time_stretched;
elseif ~isempty(app_data.pitch_shifted)
    processed_signal = app_data.pitch_shifted;
elseif ~isempty(app_data.filtered_signal)
    processed_signal = app_data.filtered_signal;
end
end

function stats_text = generate_processing_stats(app_data)
% 生成处理结果统计信息
stats_text = '';

% 原始信号信息
if ~isempty(app_data.original_signal)
    orig_len = length(app_data.original_signal);
    orig_duration = orig_len / app_data.fs;
    stats_text = sprintf('%s原始信号: %.2f秒, %d采样点\n', ...
        stats_text, orig_duration, orig_len);
end

% 滤波信息
if ~isempty(app_data.filtered_signal)
    stats_text = sprintf('%s✓ 滤波器已应用\n', stats_text);
else
    stats_text = sprintf('%s✗ 滤波器未应用\n', stats_text);
end

% 变声信息
if ~isempty(app_data.pitch_shifted)
    stats_text = sprintf('%s✓ 变声已应用 (%.1f半音)\n', ...
        stats_text, app_data.processing_params.semitones);
else
    stats_text = sprintf('%s✗ 变声未应用\n', stats_text);
end

% 时间拉伸信息
if ~isempty(app_data.time_stretched)
    stats_text = sprintf('%s✓ 时间拉伸已应用 (%.2fx)\n', ...
        stats_text, app_data.processing_params.time_ratio);
else
    stats_text = sprintf('%s✗ 时间拉伸未应用\n', stats_text);
end

% 处理状态
if app_data.is_processed
    stats_text = sprintf('%s\n✅ 全部处理完成', stats_text);
else
    stats_text = sprintf('%s\n⏳ 处理未完成', stats_text);
end
end

function close_app(src, ~)
% 关闭应用程序
selection = questdlg('确定要退出语音信号处理系统吗？', ...
    '退出确认', ...
    '是', '否', '是');
if strcmp(selection, '是')
    delete(src);
end
end