function main_gui()
% 语音信号处理系统 - 完整GUI版本
% 所有函数都在同一个文件中定义

clc; clear; close all;

% 添加路径
addpath("io");
addpath("analysis");
addpath("core");
addpath("effects");
addpath("filters");
addpath("utils");

% 创建主窗口
create_main_window();
end

% ========== 回调函数定义（必须放在主函数之前）==========

function close_app(src, ~)
% 关闭应用程序
selection = questdlg('确定要退出语音信号处理系统吗？', ...
    '退出确认', '是', '否', '是');
if strcmp(selection, '是')
    delete(src);
end
end

function menu_exit(fig, ~)
% 退出菜单
close(fig);
end

function menu_open_file(fig, ~)
% 打开音频文件
update_status(fig, '正在打开音频文件...');

[filename, pathname] = uigetfile({'*.wav;*.mp3;*.m4a','音频文件'});
if filename == 0
    update_status(fig, '用户取消选择文件');
    return;
end

filepath = fullfile(pathname, filename);


    app_data = guidata(fig);

    % 读取音频文件
    [x, fs] = read_audio(filepath);

    % 转换为单声道
    if size(x, 2) > 1
        x = mean(x, 2);
    end

    % 保存到应用程序数据
    app_data.original_signal = x;
    app_data.fs = fs;
    app_data.current_file = filename;
    app_data.is_processed = false;

    % 重置处理结果
    app_data.filtered_signal = [];
    app_data.pitch_shifted = [];
    app_data.time_stretched = [];

    guidata(fig, app_data);

    % 更新界面
    update_file_info(fig, filename, length(x)/fs, fs);
    update_waveform_plot(fig);
    update_spectrum_plot(fig);
    update_spectrogram_plot(fig)
    update_status(fig, sprintf('成功加载: %s', filename));



end

function menu_record_audio(fig, ~)
% 录制音频
app_data = guidata(fig);

% 录音参数对话框
prompt = {'录音时长 (秒):', '采样率 (Hz):'};
dlgtitle = '录音设置';
dims = [1, 35];
definput = {'5', num2str(app_data.fs)};
answer = inputdlg(prompt, dlgtitle, dims, definput);

if isempty(answer)
    return;
end

duration = str2double(answer{1});
fs = str2double(answer{2});

if isnan(duration) || isnan(fs) || duration <= 0 || fs <= 0
    errordlg('请输入有效的参数', '参数错误');
    return;
end

update_status(fig, sprintf('开始录音 %d 秒...', duration));

try
    % 录音
    x = record_audio(duration, fs);

    % 保存到应用程序数据
    app_data.original_signal = x;
    app_data.fs = fs;
    app_data.current_file = sprintf('recorded_%s.wav', datestr(now, 'HHMMSS'));
    app_data.is_processed = false;

    % 重置处理结果
    app_data.filtered_signal = [];
    app_data.pitch_shifted = [];
    app_data.time_stretched = [];

    guidata(fig, app_data);

    % 更新界面
    update_file_info(fig, '录音', length(x)/fs, fs);
    update_waveform_plot(fig);
    update_spectrum_plot(fig);
    update_spectrogram_plot(fig)
    update_status(fig, sprintf('录音完成: %.1f秒', length(x)/fs));

catch ME
    update_status(fig, sprintf('录音失败: %s', ME.message));
    errordlg(sprintf('录音失败: %s', ME.message), '录音错误');
end
end

function menu_apply_filter(fig, ~)
% 应用滤波器
app_data = guidata(fig);

if isempty(app_data.original_signal)
    errordlg('请先加载音频文件', '错误');
    return;
end

update_status(fig, '正在应用滤波器...');

try
    % 获取滤波器参数
    fc_low = app_data.processing_params.fc_low;
    fc_high = app_data.processing_params.fc_high;
    filter_order = app_data.processing_params.filter_order;

    % 设计滤波器
    [b, a] = design_filter('bandpass', fc_low, fc_high, app_data.fs, filter_order);

    % 应用滤波器
    if isempty(app_data.filtered_signal)
        input_signal = app_data.original_signal;
    else
        input_signal = app_data.filtered_signal;
    end

    x_filtered = apply_filter(input_signal, b, a);

    % 保存结果
    app_data.filtered_signal = x_filtered;
    guidata(fig, app_data);

    % 更新所有可视化
    update_all_visualizations(fig);
    update_status(fig, '滤波器应用完成');

catch ME
    update_status(fig, sprintf('滤波失败: %s', ME.message));
    errordlg(sprintf('滤波处理失败: %s', ME.message), '处理错误');
end
end

function menu_pitch_shift(fig, ~)
% 变声处理
app_data = guidata(fig);

if isempty(app_data.original_signal)
    errordlg('请先加载音频文件', '错误');
    return;
end

update_status(fig, '正在进行变声处理...');

try
    % 获取变声参数
    semitones = app_data.processing_params.semitones;
    formant_correction = logical(app_data.processing_params.formant_correction);
    nfft = app_data.processing_params.nfft;

    % 选择输入信号
    if ~isempty(app_data.filtered_signal)
        input_signal = app_data.filtered_signal;
    else
        input_signal = app_data.original_signal;
    end

    % 应用变声
    y_pitch = pitch_shift(input_signal, semitones, app_data.fs,...
        'formant_correction', formant_correction, 'nfft', nfft,'method','cepstral');

    % 保存结果
    app_data.pitch_shifted = y_pitch;
    guidata(fig, app_data);

    % 更新所有可视化
    update_all_visualizations(fig);
    update_status(fig, sprintf('变声完成: %.1f半音', semitones));

catch ME
    update_status(fig, sprintf('变声失败: %s', ME.message));
    errordlg(sprintf('变声处理失败: %s', ME.message), '处理错误');
end
end

function menu_time_stretch(fig, ~)
% 时间拉伸处理
app_data = guidata(fig);

if isempty(app_data.original_signal)
    errordlg('请先加载音频文件', '错误');
    return;
end

update_status(fig, '正在进行时间拉伸...');

try
    % 获取时间拉伸参数
    time_ratio = app_data.processing_params.time_ratio;

    % 选择输入信号
    if ~isempty(app_data.pitch_shifted)
        input_signal = app_data.pitch_shifted;
    elseif ~isempty(app_data.filtered_signal)
        input_signal = app_data.filtered_signal;
    else
        input_signal = app_data.original_signal;
    end

    % 应用时间拉伸
    y_time = time_stretch(input_signal, time_ratio, app_data.fs);

    % 保存结果
    app_data.time_stretched = y_time;
    app_data.is_processed = true;
    guidata(fig, app_data);

    % 更新所有可视化
    update_all_visualizations(fig);
    update_status(fig, sprintf('时间拉伸完成: %.2fx', time_ratio));

catch ME
    update_status(fig, sprintf('时间拉伸失败: %s', ME.message));
    errordlg(sprintf('时间拉伸失败: %s', ME.message), '处理错误');
end
end

function menu_process_all(fig, ~)
% 一键全部处理
app_data = guidata(fig);

if isempty(app_data.original_signal)
    errordlg('请先加载音频文件', '错误');
    return;
end

update_status(fig, '开始批量处理...');

try
    % 依次应用所有处理
    menu_apply_filter(fig, []);
    menu_pitch_shift(fig, []);
    menu_time_stretch(fig, []);

    % 批量处理完成后更新所有可视化
    update_all_visualizations(fig);
    update_status(fig, '批量处理完成！');

catch ME
    update_status(fig, sprintf('批量处理失败: %s', ME.message));
    errordlg(sprintf('批量处理失败: %s', ME.message), '处理错误');
end
end

function menu_play_original(fig, ~)
% 播放原始音频
app_data = guidata(fig);

if isempty(app_data.original_signal)
    errordlg('没有可播放的音频', '错误');
    return;
end

update_status(fig, '播放原始音频...');
sound(app_data.original_signal, app_data.fs);
update_status(fig, '播放完成');
end

function menu_play_processed(fig, ~)
% 播放处理后的音频
app_data = guidata(fig);

if isempty(app_data.time_stretched) && isempty(app_data.pitch_shifted)
    errordlg('请先进行音频处理', '错误');
    return;
end

update_status(fig, '播放处理结果...');

% 播放最终结果
if ~isempty(app_data.time_stretched)
    sound(app_data.time_stretched, app_data.fs);
elseif ~isempty(app_data.pitch_shifted)
    sound(app_data.pitch_shifted, app_data.fs);
else
    sound(app_data.filtered_signal, app_data.fs);
end

update_status(fig, '播放完成');
end

function menu_play_comparison(fig, ~)
% 对比播放
app_data = guidata(fig);

if isempty(app_data.original_signal)
    errordlg('没有可播放的音频', '错误');
    return;
end

update_status(fig, '开始对比播放...');

% 播放原始音频
sound(app_data.original_signal, app_data.fs);
pause(length(app_data.original_signal)/app_data.fs + 1);

% 播放处理结果
if ~isempty(app_data.time_stretched)
    sound(app_data.time_stretched, app_data.fs);
elseif ~isempty(app_data.pitch_shifted)
    sound(app_data.pitch_shifted, app_data.fs);
elseif ~isempty(app_data.filtered_signal)
    sound(app_data.filtered_signal, app_data.fs);
end

update_status(fig, '对比播放完成');
end

function menu_save_result(fig, ~)
% 保存处理结果
app_data = guidata(fig);

if isempty(app_data.time_stretched) && isempty(app_data.pitch_shifted)
    errordlg('没有处理结果可保存', '错误');
    return;
end

[filename, pathname] = uiputfile('*.wav', '保存处理结果', 'processed_audio.wav');
if filename == 0
    return;
end

filepath = fullfile(pathname, filename);

try
    % 保存最终结果
    if ~isempty(app_data.time_stretched)
        audiowrite(filepath, app_data.time_stretched, app_data.fs);
    else
        audiowrite(filepath, app_data.pitch_shifted, app_data.fs);
    end

    update_status(fig, sprintf('结果已保存: %s', filename));
    msgbox(sprintf('处理结果已保存为: %s', filename), '保存成功');

catch ME
    update_status(fig, sprintf('保存失败: %s', ME.message));
    errordlg(sprintf('保存失败: %s', ME.message), '保存错误');
end
end

% ========== 参数更新回调函数 ==========

function update_filter_params(src, ~)
% 更新滤波器参数
fig = ancestor(src, 'figure');
app_data = guidata(fig);

try
    fc_low_edit = findobj(fig, 'Tag', 'fc_low_edit');
    fc_high_edit = findobj(fig, 'Tag', 'fc_high_edit');
    order_edit = findobj(fig, 'Tag', 'filter_order_edit');

    app_data.processing_params.fc_low = str2double(get(fc_low_edit, 'String'));
    app_data.processing_params.fc_high = str2double(get(fc_high_edit, 'String'));
    app_data.processing_params.filter_order = str2double(get(order_edit, 'String'));

    guidata(fig, app_data);

catch
    % 参数无效，忽略
end
end

function update_pitch_params(src, ~)
% 更新变声参数
fig = ancestor(src, 'figure');
app_data = guidata(fig);

try
    semitones_slider = findobj(fig, 'Tag', 'semitones_slider');
    semitones_text = findobj(fig, 'Tag', 'semitones_text');
    formant_check = findobj(fig, 'Tag', 'formant_correction_check');

    semitones = round(get(semitones_slider, 'Value'));
    set(semitones_text, 'String', sprintf('%d 半音', semitones));

    app_data.processing_params.semitones = semitones;
    app_data.processing_params.formant_correction = get(formant_check, 'Value');

    guidata(fig, app_data);

catch
    % 参数无效，忽略
end
end

function update_time_params(src, ~)
% 更新时间拉伸参数
fig = ancestor(src, 'figure');
app_data = guidata(fig);

try
    time_slider = findobj(fig, 'Tag', 'time_ratio_slider');
    time_text = findobj(fig, 'Tag', 'time_ratio_text');

    time_ratio = get(time_slider, 'Value');
    set(time_text, 'String', sprintf('%.2fx', time_ratio));

    app_data.processing_params.time_ratio = time_ratio;

    guidata(fig, app_data);

catch
    % 参数无效，忽略
end
end

function menu_spectrum_analysis(fig, ~)
% 频谱分析菜单回调
app_data = guidata(fig);

if isempty(app_data.original_signal)
    errordlg('请先加载音频文件', '错误');
    return;
end

update_status(fig, '正在进行频谱分析...');

try
    % 调用现有的频谱分析函数
    spectrum_analysis(app_data.original_signal, app_data.fs, '原始信号频谱分析');

    % 如果有处理结果，也分析处理后的信号
    if ~isempty(app_data.time_stretched)
        spectrum_analysis(app_data.time_stretched, app_data.fs, '处理结果频谱分析');
    elseif ~isempty(app_data.pitch_shifted)
        spectrum_analysis(app_data.pitch_shifted, app_data.fs, '处理结果频谱分析');
    elseif ~isempty(app_data.filtered_signal)
        spectrum_analysis(app_data.filtered_signal, app_data.fs, '滤波后信号频谱分析');
    end

    update_status(fig, '频谱分析完成');

catch ME
    update_status(fig, sprintf('频谱分析失败: %s', ME.message));
    errordlg(sprintf('频谱分析失败: %s', ME.message), '分析错误');
end
end

function menu_plot_time(fig, ~)
% 时域波形对比绘图
app_data = guidata(fig);

if isempty(app_data.original_signal)
    errordlg('请先加载音频文件', '错误');
    return;
end

update_status(fig, '绘制时域波形对比图...');

try
    % 准备对比信号
    signals = {app_data.original_signal};
    titles = {'原始信号'};

    if ~isempty(app_data.filtered_signal)
        signals{end+1} = app_data.filtered_signal;
        titles{end+1} = '滤波后信号';
    end

    if ~isempty(app_data.pitch_shifted)
        signals{end+1} = app_data.pitch_shifted;
        titles{end+1} = sprintf('变声信号 (%.1f半音)', app_data.processing_params.semitones);
    end

    if ~isempty(app_data.time_stretched)
        signals{end+1} = app_data.time_stretched;
        titles{end+1} = sprintf('时间拉伸 (%.2fx)', app_data.processing_params.time_ratio);
    end

    % 调用现有的绘图函数
    plot_signals(signals, app_data.fs, titles);

    update_status(fig, '时域波形对比图绘制完成');

catch ME
    update_status(fig, sprintf('时域波形绘图失败: %s', ME.message));
    errordlg(sprintf('绘图失败: %s', ME.message), '绘图错误');
end
end

function menu_plot_spectrum(fig, ~)
% 频域波形对比绘图
app_data = guidata(fig);

if isempty(app_data.original_signal)
    errordlg('请先加载音频文件', '错误');
    return;
end

update_status(fig, '绘制频域波形对比图...');

try
    % 准备对比信号
    signals = {app_data.original_signal};
    titles = {'原始信号'};

    if ~isempty(app_data.filtered_signal)
        signals{end+1} = app_data.filtered_signal;
        titles{end+1} = '滤波后信号';
    end

    if ~isempty(app_data.pitch_shifted)
        signals{end+1} = app_data.pitch_shifted;
        titles{end+1} = sprintf('变声信号 (%.1f半音)', app_data.processing_params.semitones);
    end

    if ~isempty(app_data.time_stretched)
        signals{end+1} = app_data.time_stretched;
        titles{end+1} = sprintf('时间拉伸 (%.2fx)', app_data.processing_params.time_ratio);
    end

    % 调用现有的绘图函数
    plot_signals_spectrum(signals, app_data.fs, titles);

    update_status(fig, '频域波形对比图绘制完成');

catch ME
    update_status(fig, sprintf('绘图失败: %s', ME.message));
    errordlg(sprintf('绘图失败: %s', ME.message), '绘图错误');
end
end

function menu_plot_filter_response(fig, ~)
% 滤波器响应绘图
app_data = guidata(fig);

update_status(fig, '绘制滤波器响应图...');

try
    % 获取当前滤波器参数
    fc_low = app_data.processing_params.fc_low;
    fc_high = app_data.processing_params.fc_high;
    filter_order = app_data.processing_params.filter_order;

    % 设计滤波器
    [b, a] = design_filter('bandpass', fc_low, fc_high, app_data.fs, filter_order);

    % 绘制滤波器响应
    plot_frequency_response(b, a, app_data.fs, '当前滤波器频率响应');

    update_status(fig, '滤波器响应图绘制完成');

catch ME
    update_status(fig, sprintf('滤波器响应绘图失败: %s', ME.message));
    errordlg(sprintf('滤波器响应绘图失败: %s', ME.message), '绘图错误');
end
end


% ========== 工具函数 ==========

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
% 更新波形图 - 支持原始与处理后信号对比
app_data = guidata(fig);

if isempty(app_data.original_signal)
    return;
end

% 查找坐标轴
waveform_ax = findobj(fig, 'Tag', 'waveform_ax');
if isempty(waveform_ax) && isfield(app_data, 'plot_handles') && isfield(app_data.plot_handles, 'waveform_ax')
    waveform_ax = app_data.plot_handles.waveform_ax;
end

if isempty(waveform_ax)
    fprintf('错误：未找到波形图坐标轴\n');
    return;
end

axes(waveform_ax);
cla;
hold on;

fs = app_data.fs;

% 绘制原始信号
t_orig = (0:length(app_data.original_signal)-1) / fs;
h1 = plot(t_orig, app_data.original_signal, 'b', 'LineWidth', 1, 'DisplayName', '原始信号');

% 获取最终处理结果
processed_signal = get_final_processed_signal(app_data);

% 如果有处理结果，绘制对比
if ~isempty(processed_signal)
    t_proc = (0:length(processed_signal)-1) / fs;
    h2 = plot(t_proc, processed_signal, 'r', 'LineWidth', 1, 'DisplayName', '处理后信号');
    legend([h1, h2], 'Location', 'northeast');
    title('时域波形对比');
else
    legend(h1, 'Location', 'northeast');
    title('时域波形');
end

xlabel('时间 (s)');
ylabel('幅度');
grid on;
hold off;

% 刷新显示
drawnow;
end

function update_spectrum_plot(fig)
% 更新频谱图 - 支持原始与处理后信号对比
app_data = guidata(fig);

if isempty(app_data.original_signal)
    return;
end

% 双重查找机制
spectrum_ax = findobj(fig, 'Tag', 'spectrum_ax');
if isempty(spectrum_ax) && isfield(app_data, 'plot_handles') && isfield(app_data.plot_handles, 'spectrum_ax')
    spectrum_ax = app_data.plot_handles.spectrum_ax;
end

if isempty(spectrum_ax)
    fprintf('错误：未找到频谱图坐标轴\n');
    return;
end

axes(spectrum_ax);
cla;
hold on;

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
hold off;

drawnow;
end

function update_spectrogram_plot(fig)
% 更新频谱图（修复版，采用与频谱图相同的调用方式）
app_data = guidata(fig);

if isempty(app_data.original_signal)
    return;
end

% 双重查找机制（与update_spectrum_plot保持一致）
spectrogram_ax = findobj(fig, 'Tag', 'spectrogram_ax');
if isempty(spectrogram_ax) && isfield(app_data, 'plot_handles') && isfield(app_data.plot_handles, 'spectrogram_ax')
    spectrogram_ax = app_data.plot_handles.spectrogram_ax;
    fprintf('使用plot_handles查找频谱图坐标轴\n');
end

if isempty(spectrogram_ax)
    fprintf('错误：未找到频谱图坐标轴\n');
    return;
end

axes(spectrogram_ax);
cla;

x = app_data.original_signal;
fs = app_data.fs;

% 检查信号长度
if length(x) < 512
    text(0.5, 0.5, '信号太短，无法生成频谱图', ...
        'HorizontalAlignment', 'center', 'FontSize', 12);
    title('时频分析 (频谱图)');
    xlabel('时间 (s)');
    ylabel('频率 (kHz)');
    axis off;
    return;
end

try
    % 计算频谱图
    window = min(512, floor(length(x)/8)); % 自适应窗口大小
    noverlap = floor(window * 0.5);
    nfft = max(1024, window);

    [S, F, T] = spectrogram(x, window, noverlap, nfft, fs, 'yaxis');

    % 转换为dB
    S_db = 10*log10(abs(S) + eps);

    % 绘制频谱图
    imagesc(T, F/1000, S_db);
    axis xy;
    title('时频分析 (频谱图)');
    xlabel('时间 (s)');
    ylabel('频率 (kHz)');

    % 添加颜色条
    c = colorbar;
    ylabel(c, '幅度 (dB)');

    % 设置合理的显示范围
    ylim([0, min(12000, fs/2)]); % 限制到12kHz

    % 设置颜色映射
    colormap(jet);

catch ME
    % 如果频谱图计算失败，显示错误信息
    text(0.5, 0.5, sprintf('频谱图生成失败:\n%s', ME.message), ...
        'HorizontalAlignment', 'center', 'FontSize', 10);
    title('时频分析 (频谱图)');
    axis off;
end

drawnow;
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

function update_result_plot(fig)
% 更新结果图（修复版）
app_data = guidata(fig);

% 双重查找机制
result_ax = findobj(fig, 'Tag', 'result_ax');
if isempty(result_ax) && isfield(app_data, 'plot_handles') && isfield(app_data.plot_handles, 'result_ax')
    result_ax = app_data.plot_handles.result_ax;
end

if isempty(result_ax)
    fprintf('错误：未找到结果图坐标轴\n');
    return;
end

axes(result_ax);
cla;

if isempty(app_data.original_signal)
    text(0.5, 0.5, '请加载音频文件开始处理', ...
        'HorizontalAlignment', 'center', 'FontSize', 14);
    title('处理结果');
    axis off;
    return;
end

% 显示处理结果统计信息
stats_text = generate_processing_stats(app_data);

text(0.1, 0.9, '处理结果统计', 'FontSize', 16, 'FontWeight', 'bold');
text(0.1, 0.7, stats_text, 'FontSize', 12, 'VerticalAlignment', 'top');
title('处理结果');
axis([0, 1, 0, 1]);
axis off;

drawnow;
end

function stats_text = generate_processing_stats(app_data)
% 生成处理结果统计信息
stats_text = '';

if ~isempty(app_data.original_signal)
    orig_len = length(app_data.original_signal);
    orig_duration = orig_len / app_data.fs;
    stats_text = sprintf('原始信号: %.2f秒, %d采样点\n', orig_duration, orig_len);
end

if ~isempty(app_data.filtered_signal)
    stats_text = sprintf('%s✓ 滤波器已应用\n', stats_text);
else
    stats_text = sprintf('%s✗ 滤波器未应用\n', stats_text);
end

if ~isempty(app_data.pitch_shifted)
    stats_text = sprintf('%s✓ 变声已应用 (%.1f半音)\n', ...
        stats_text, app_data.processing_params.semitones);
else
    stats_text = sprintf('%s✗ 变声未应用\n', stats_text);
end

if ~isempty(app_data.time_stretched)
    stats_text = sprintf('%s✓ 时间拉伸已应用 (%.2fx)\n', ...
        stats_text, app_data.processing_params.time_ratio);
else
    stats_text = sprintf('%s✗ 时间拉伸未应用\n', stats_text);
end

if app_data.is_processed
    stats_text = sprintf('%s\n✅ 全部处理完成', stats_text);
else
    stats_text = sprintf('%s\n⏳ 处理未完成', stats_text);
end
end

% ========== GUI创建函数（放在最后）==========

function create_main_window()
% 创建主GUI窗口

% 主窗口设置
screen_size = get(0, 'ScreenSize');
fig_width = 1200;
fig_height = 800;
fig_x = (screen_size(3) - fig_width) / 2;
fig_y = (screen_size(4) - fig_height) / 2;

% 创建主窗口
fig = figure('Name', '语音信号处理系统', ...
    'NumberTitle', 'off', ...
    'Position', [fig_x, fig_y, fig_width, fig_height], ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'Resize', 'on', ...
    'Color', [0.95, 0.95, 0.95]);

% 初始化全局数据
app_data = initialize_app_data();
guidata(fig, app_data);

% 创建界面组件
create_menu_bar(fig);
create_control_panel(fig);
create_visualization_panel(fig);
create_status_bar(fig);

% 设置窗口关闭回调（现在close_app已定义）
set(fig, 'CloseRequestFcn', @close_app);

fprintf('语音信号处理GUI启动成功！\n');
end

function app_data = initialize_app_data()
% 初始化应用程序数据
app_data = struct();

% 音频数据
app_data.original_signal = [];
app_data.filtered_signal = [];
app_data.pitch_shifted = [];
app_data.time_stretched = [];
app_data.fs = 44100;

% 处理参数
app_data.current_file = '';
app_data.is_processed = false;
app_data.processing_params = struct();

% 默认参数
app_data.processing_params.fc_low = 100;
app_data.processing_params.fc_high = 3500;
app_data.processing_params.filter_order = 4;
app_data.processing_params.semitones = 0;
app_data.processing_params.time_ratio = 1.0;
app_data.processing_params.formant_correction = true;
app_data.processing_params.nfft = 1024;

% 图形句柄
app_data.plot_handles = struct();
end

function create_menu_bar(fig)
% 创建菜单栏
% 文件菜单
file_menu = uimenu(fig, 'Label', '文件');
uimenu(file_menu, 'Label', '打开音频文件', ...
    'Callback', @menu_open_file, ...
    'Accelerator', 'O');
uimenu(file_menu, 'Label', '录制音频', ...
    'Callback', @menu_record_audio);
uimenu(file_menu, 'Label', '保存结果', ...
    'Callback', @menu_save_result, ...
    'Accelerator', 'S');
uimenu(file_menu, 'Label', '退出', ...
    'Callback', @menu_exit, ...
    'Separator', 'on', ...
    'Accelerator', 'Q');

% 处理菜单
process_menu = uimenu(fig, 'Label', '处理');
uimenu(process_menu, 'Label', '频谱分析', ...
    'Callback', @menu_spectrum_analysis);
uimenu(process_menu, 'Label', '应用滤波器', ...
    'Callback', @menu_apply_filter);
uimenu(process_menu, 'Label', '变声处理', ...
    'Callback', @menu_pitch_shift);
uimenu(process_menu, 'Label', '时间拉伸', ...
    'Callback', @menu_time_stretch);
uimenu(process_menu, 'Label', '全部处理', ...
    'Callback', @menu_process_all, ...
    'Separator', 'on');

% 查看菜单
view_menu = uimenu(fig, 'Label', '查看');
uimenu(view_menu, 'Label', '波形对比', ...
    'Callback', @menu_plot_time);
uimenu(view_menu, 'Label', '频谱对比', ...
    'Callback', @menu_plot_spectrum);
uimenu(view_menu, 'Label', '滤波器响应', ...
    'Callback', @menu_plot_filter_response);

% 工具菜单
tools_menu = uimenu(fig, 'Label', '工具');
uimenu(tools_menu, 'Label', '播放原始音频', ...
    'Callback', @menu_play_original);
uimenu(tools_menu, 'Label', '播放处理结果', ...
    'Callback', @menu_play_processed);
uimenu(tools_menu, 'Label', '播放对比', ...
    'Callback', @menu_play_comparison);
end

function create_control_panel(fig)
% 创建控制面板
app_data = guidata(fig);

% 控制面板容器
control_panel = uipanel(fig, 'Title', '处理控制', ...
    'Position', [0.02, 0.02, 0.25, 0.96], ...
    'BackgroundColor', [0.98, 0.98, 0.98], ...
    'FontSize', 12, 'FontWeight', 'bold');

% 文件操作区域
create_file_section(control_panel, fig);

% 滤波器设置区域
create_filter_section(control_panel, fig);

% 变声设置区域
create_pitch_section(control_panel, fig);

% 时间拉伸区域
create_time_section(control_panel, fig);

% 处理控制按钮
create_processing_buttons(control_panel, fig);
end

function create_file_section(parent, fig)
% 创建文件操作区域
y_pos = 0.85;
section_height = 0.12;

file_section = uipanel(parent, 'Title', '文件操作', ...
    'Position', [0.05, y_pos, 0.9, section_height], ...
    'BackgroundColor', [1, 1, 1]);

% 打开文件按钮
uicontrol(file_section, 'Style', 'pushbutton', ...
    'String', '打开音频文件', ...
    'Position', [10, 50, 120, 30], ...
    'Callback', @(~,~) menu_open_file(fig, []), ...
    'BackgroundColor', [0.2, 0.6, 1], ...
    'ForegroundColor', 'white', ...
    'FontWeight', 'bold');

% 录制音频按钮
uicontrol(file_section, 'Style', 'pushbutton', ...
    'String', '录制音频', ...
    'Position', [140, 50, 120, 30], ...
    'Callback', @(~,~) menu_record_audio(fig, []), ...
    'BackgroundColor', [0.9, 0.3, 0.3], ...
    'ForegroundColor', 'white', ...
    'FontWeight', 'bold');

% 文件信息显示
uicontrol(file_section, 'Style', 'text', ...
    'String', '文件: 未加载', ...
    'Position', [10, 20, 250, 20], ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 10, ...
    'Tag', 'file_info_text');
end


function create_filter_section(parent, fig)
% 创建滤波器设置区域
y_pos = 0.65;
section_height = 0.18;

filter_section = uipanel(parent, 'Title', '滤波器设置', ...
    'Position', [0.05, y_pos, 0.9, section_height], ...
    'BackgroundColor', [1, 1, 1]);

% 低频截止
uicontrol(filter_section, 'Style', 'text', ...
    'String', '低频截止 (Hz):', ...
    'Position', [10, 100, 100, 20], ...
    'HorizontalAlignment', 'left');
uicontrol(filter_section, 'Style', 'edit', ...
    'String', '100', ...
    'Position', [120, 100, 80, 25], ...
    'Tag', 'fc_low_edit', ...
    'Callback', @update_filter_params);

% 高频截止
uicontrol(filter_section, 'Style', 'text', ...
    'String', '高频截止 (Hz):', ...
    'Position', [10, 70, 100, 20], ...
    'HorizontalAlignment', 'left');
uicontrol(filter_section, 'Style', 'edit', ...
    'String', '3500', ...
    'Position', [120, 70, 80, 25], ...
    'Tag', 'fc_high_edit', ...
    'Callback', @update_filter_params);

% 滤波器阶数
uicontrol(filter_section, 'Style', 'text', ...
    'String', '滤波器阶数:', ...
    'Position', [10, 40, 100, 20], ...
    'HorizontalAlignment', 'left');
uicontrol(filter_section, 'Style', 'edit', ...
    'String', '4', ...
    'Position', [120, 40, 80, 25], ...
    'Tag', 'filter_order_edit', ...
    'Callback', @update_filter_params);

% 应用滤波器按钮
uicontrol(filter_section, 'Style', 'pushbutton', ...
    'String', '应用滤波器', ...
    'Position', [10, 10, 190, 25], ...
    'Callback', @(~,~) menu_apply_filter(fig, []), ...
    'BackgroundColor', [0.1, 0.7, 0.3], ...
    'ForegroundColor', 'white');
end

function create_pitch_section(parent, fig)
% 创建变声设置区域
y_pos = 0.45;
section_height = 0.18;

pitch_section = uipanel(parent, 'Title', '变声设置', ...
    'Position', [0.05, y_pos, 0.9, section_height], ...
    'BackgroundColor', [1, 1, 1]);

% 半音数滑块
uicontrol(pitch_section, 'Style', 'text', ...
    'String', '变调半音数:', ...
    'Position', [10, 100, 100, 20], ...
    'HorizontalAlignment', 'left');

semitones_slider = uicontrol(pitch_section, 'Style', 'slider', ...
    'Min', -12, 'Max', 12, 'Value', 0, ...
    'Position', [10, 80, 150, 20], ...
    'Tag', 'semitones_slider', ...
    'Callback', @update_pitch_params);

% 半音数值显示
uicontrol(pitch_section, 'Style', 'text', ...
    'String', '0 半音', ...
    'Position', [170, 80, 50, 20], ...
    'Tag', 'semitones_text', ...
    'HorizontalAlignment', 'left');

% 共振峰校正复选框
uicontrol(pitch_section, 'Style', 'checkbox', ...
    'String', '共振峰校正', ...
    'Value', 1, ...
    'Position', [10, 50, 120, 20], ...
    'Tag', 'formant_correction_check', ...
    'Callback', @update_pitch_params);

% 变声处理按钮
uicontrol(pitch_section, 'Style', 'pushbutton', ...
    'String', '应用变声', ...
    'Position', [10, 10, 190, 25], ...
    'Callback', @(~,~) menu_pitch_shift(fig, []), ...
    'BackgroundColor', [0.8, 0.5, 0.1], ...
    'ForegroundColor', 'white');
end

function create_time_section(parent, fig)
% 创建时间拉伸区域
y_pos = 0.25;
section_height = 0.18;

time_section = uipanel(parent, 'Title', '时间拉伸', ...
    'Position', [0.05, y_pos, 0.9, section_height], ...
    'BackgroundColor', [1, 1, 1]);

% 时间比例滑块
uicontrol(time_section, 'Style', 'text', ...
    'String', '时间比例:', ...
    'Position', [10, 100, 100, 20], ...
    'HorizontalAlignment', 'left');

time_slider = uicontrol(time_section, 'Style', 'slider', ...
    'Min', 0.5, 'Max', 2.0, 'Value', 1.0, ...
    'Position', [10, 80, 150, 20], ...
    'Tag', 'time_ratio_slider', ...
    'Callback', @update_time_params);

% 时间比例显示
uicontrol(time_section, 'Style', 'text', ...
    'String', '1.00x', ...
    'Position', [170, 80, 50, 20], ...
    'Tag', 'time_ratio_text', ...
    'HorizontalAlignment', 'left');

uicontrol(time_section, 'Style', 'text', ...
    'String', '0.5x (快)     1.0x (正常)     2.0x (慢)', ...
    'Position', [10, 60, 190, 15], ...
    'FontSize', 8, ...
    'HorizontalAlignment', 'center');

% 时间拉伸按钮
uicontrol(time_section, 'Style', 'pushbutton', ...
    'String', '应用时间拉伸', ...
    'Position', [10, 10, 190, 25], ...
    'Callback', @(~,~) menu_time_stretch(fig, []), ...
    'BackgroundColor', [0.6, 0.2, 0.8], ...
    'ForegroundColor', 'white');
end

function create_processing_buttons(parent, fig)
% 创建处理控制按钮
y_pos = 0.05;
section_height = 0.18;

process_section = uipanel(parent, 'Title', '批量处理', ...
    'Position', [0.05, y_pos, 0.9, section_height], ...
    'BackgroundColor', [1, 1, 1]);

% 全部处理按钮
uicontrol(process_section, 'Style', 'pushbutton', ...
    'String', '一键全部处理', ...
    'Position', [10, 80, 190, 35], ...
    'Callback', @(~,~) menu_process_all(fig, []), ...
    'BackgroundColor', [0.9, 0.6, 0.1], ...
    'ForegroundColor', 'white', ...
    'FontSize', 12, 'FontWeight', 'bold');

% 播放控制按钮
uicontrol(process_section, 'Style', 'pushbutton', ...
    'String', '播放原始', ...
    'Position', [10, 45, 60, 25], ...
    'Callback', @(~,~) menu_play_original(fig, []), ...
    'BackgroundColor', [0.3, 0.7, 0.3]);

uicontrol(process_section, 'Style', 'pushbutton', ...
    'String', '播放结果', ...
    'Position', [75, 45, 60, 25], ...
    'Callback', @(~,~) menu_play_processed(fig, []), ...
    'BackgroundColor', [0.1, 0.5, 0.8]);

uicontrol(process_section, 'Style', 'pushbutton', ...
    'String', '对比播放', ...
    'Position', [140, 45, 60, 25], ...
    'Callback', @(~,~) menu_play_comparison(fig, []), ...
    'BackgroundColor', [0.8, 0.3, 0.3]);

% 保存按钮
uicontrol(process_section, 'Style', 'pushbutton', ...
    'String', '保存结果', ...
    'Position', [10, 10, 190, 25], ...
    'Callback', @(~,~) menu_save_result(fig, []), ...
    'BackgroundColor', [0.5, 0.2, 0.7], ...
    'ForegroundColor', 'white');
end

function create_visualization_panel(fig)
% 创建可视化面板
app_data = guidata(fig);

% 可视化面板
viz_panel = uipanel(fig, 'Title', '信号可视化', ...
    'Position', [0.28, 0.02, 0.70, 0.96], ...
    'BackgroundColor', [1, 1, 1], ...
    'FontSize', 12, 'FontWeight', 'bold');

% 创建子图区域并设置Tag标签
app_data.plot_handles.waveform_ax = subplot(2, 2, 1, 'Parent', viz_panel);
set(app_data.plot_handles.waveform_ax, 'Tag', 'waveform_ax');
fprintf('设置 waveform_ax Tag: %s\n', get(app_data.plot_handles.waveform_ax, 'Tag'));

app_data.plot_handles.spectrum_ax = subplot(2, 2, 2, 'Parent', viz_panel);
set(app_data.plot_handles.spectrum_ax, 'Tag', 'spectrum_ax');
fprintf('设置 spectrum_ax Tag: %s\n', get(app_data.plot_handles.spectrum_ax, 'Tag'));

app_data.plot_handles.spectrogram_ax = subplot(2, 2, 3, 'Parent', viz_panel);
set(app_data.plot_handles.spectrogram_ax, 'Tag', 'spectrogram_ax');
fprintf('设置 spectrogram_ax Tag: %s\n', get(app_data.plot_handles.spectrogram_ax, 'Tag'));

app_data.plot_handles.result_ax = subplot(2, 2, 4, 'Parent', viz_panel);
set(app_data.plot_handles.result_ax, 'Tag', 'result_ax');
fprintf('设置 result_ax Tag: %s\n', get(app_data.plot_handles.result_ax, 'Tag'));

% 初始化图形
initialize_plots(app_data);

guidata(fig, app_data);
end

function create_status_bar(fig)
% 创建状态栏
status_bar = uipanel(fig, 'Title', '', ...
    'Position', [0.02, 0, 0.96, 0.04], ...
    'BackgroundColor', [0.8, 0.8, 0.9], ...
    'BorderType', 'none');

uicontrol(status_bar, 'Style', 'text', ...
    'String', '就绪', ...
    'Position', [10, 8,500, 20], ...
    'HorizontalAlignment', 'left', ...
    'Tag', 'status_text', ...
    'FontSize', 12, ...
    'BackgroundColor', [0.8, 0.8, 0.9]);
end

function initialize_plots(app_data)
% 初始化图形显示（修复版）
fprintf('初始化图形显示...\n');

% 检查坐标轴句柄
if ~isfield(app_data, 'plot_handles')
    fprintf('错误：plot_handles 不存在\n');
    return;
end

axes_list = {'waveform_ax', 'spectrum_ax', 'spectrogram_ax', 'result_ax'};
titles = {'时域波形', '频谱分析', '时频分析', '处理结果'};

for i = 1:length(axes_list)
    ax_name = axes_list{i};

    if isfield(app_data.plot_handles, ax_name)
        ax_handle = app_data.plot_handles.(ax_name);

        if ishandle(ax_handle)
            axes(ax_handle);
            cla;

            % 确保设置Tag
            set(ax_handle, 'Tag', ax_name);

            if i == 4 % 结果图
                text(0.5, 0.5, '请加载音频文件开始处理', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14);
                axis off;
            else
                plot(0, 0);
                xlabel('');
                ylabel('');
                grid on;
            end

            title(titles{i});
            fprintf('✅ 初始化 %s\n', ax_name);
        else
            fprintf('❌ %s 句柄无效\n', ax_name);
        end
    else
        fprintf('❌ %s 字段不存在\n', ax_name);
    end
end
end