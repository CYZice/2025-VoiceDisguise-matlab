function test_pitch_shift_formants()
% 完整的变调共振峰分析函数
% 分析并比较多种变调算法的共振峰保持效果

addpath('core')
% 1. 加载数据
S = load('mtlb.mat'); % 使用结构体加载数据
mtlb = S.mtlb;
Fs = S.Fs;
dt = 1/Fs;
I0 = round(0.1/dt);
Iend = round(0.25/dt);
x = mtlb(I0:Iend);
% 2. 变调处理 (升高 4 个半音)
shift_semitones = -3;
disp(['正在执行变调 (升调 ' num2str(shift_semitones) ' 半音)...']);

% 调用你的 pitch_shift 函数
% 注意：由于相位声码器可能会导致长度微变，我们需要对齐长度·
mtlb_shifted = pitch_shift(mtlb, shift_semitones, Fs,'formant_correction',false);
mtlb_shifted_lpc = pitch_shift(mtlb, shift_semitones, Fs,'formant_correction',true,'method','lpc');
mtlb_shifted_cepstral = pitch_shift(mtlb, shift_semitones, Fs,'formant_correction',true,'method','cepstral');
mtlb_shifted_mt = shiftPitch(x, shift_semitones,"PreserveFormants",true);

fprintf('信号长度: %d\n', length(mtlb));
fprintf('变调信号长度: %d\n', length(mtlb_shifted));
fprintf('MTL 变调信号长度: %d\n', length(mtlb_shifted_mt));
fprintf('LPC 变调信号长度: %d\n', length(mtlb_shifted_lpc));
fprintf('倒谱域 变调信号长度: %d\n', length(mtlb_shifted_cepstral));
% 简单对齐长度以便绘图 (截断或补零)
len = min([length(mtlb), length(mtlb_shifted_lpc), length(mtlb_shifted_cepstral), length(mtlb_shifted_mt)]);
mtlb = mtlb(1:len);
mtlb_shifted = mtlb_shifted(1:len);
mtlb_shifted_lpc = mtlb_shifted_lpc(1:len);
mtlb_shifted_cepstral = mtlb_shifted_cepstral(1:len);
mtlb_shifted_mt = mtlb_shifted_mt(1:len);

% 3. 提取共振峰
% 设置参数 (与之前的练习保持一致)
params.lpcOrder = 8;
params.winLen = 0.030;
params.timeStep = 0.010;
params.preemph = [1 0.63];

disp('提取原语音共振峰...');
[t_orig, f_orig] = extract_formants_doc_style(mtlb, Fs, params);

disp('提取变调语音共振峰...');
[t_shift, f_shift] = extract_formants_doc_style(mtlb_shifted, Fs, params);
disp('提取 MTL 变调语音共振峰...');
[t_shift_mt, f_shift_mt] = extract_formants_doc_style(mtlb_shifted_mt, Fs, params);
disp('提取 LPC 变调语音共振峰...');
[t_shift_lpc, f_shift_lpc] = extract_formants_doc_style(mtlb_shifted_lpc, Fs, params);
disp('提取倒谱域 变调语音共振峰...');
[t_shift_cepstral, f_shift_cepstral] = extract_formants_doc_style(mtlb_shifted_cepstral, Fs, params);

% 4. 绘制对比图
% 使用示例 - 可以修改 signals_to_plot 来选择要绘制的信号:
% 可选信号: 'original', 'shifted', 'lpc', 'cepstral', 'mtl'
% 例如:
% signals_to_plot = {'original', 'mtl'};           % 只显示原始和MTL
% signals_to_plot = {'original', 'lpc', 'cepstral'}; % 显示原始、LPC和倒谱
% signals_to_plot = {'original', 'shifted', 'lpc', 'cepstral', 'mtl'}; % 显示所有信号

signals_to_plot = {'original','mtl','cepstral'}; % 默认只显示原始和MTL
time_axis = (0:len-1)/Fs;

% 调用封装的绘图函数
plot_formant_comparison(time_axis, mtlb, mtlb_shifted, mtlb_shifted_lpc, mtlb_shifted_cepstral, mtlb_shifted_mt, ...
    t_orig, f_orig, t_shift, f_shift, t_shift_lpc, f_shift_lpc, t_shift_cepstral, f_shift_cepstral, t_shift_mt, f_shift_mt, ...
    signals_to_plot, Fs);

disp('分析完成。如果变调算法优秀，红点(F_shift)应尽量覆盖黑点(F_orig)。');
%% === 添加到之前的脚本通过之后 ===
% 1. 数据对齐 (使用线性插值将变调后的轨迹映射到原时间轴)
% 仅分析重叠的有效时间段
common_time = t_orig(t_orig <= t_shift(end));
% 截取原数据
F1_orig_aligned = f_orig(1:length(common_time), 1);
F2_orig_aligned = f_orig(1:length(common_time), 2);
% 插值变调数据
F1_shift_aligned = interp1(t_shift, f_shift_cepstral(:,1), common_time, 'linear');
F2_shift_aligned = interp1(t_shift, f_shift_cepstral(:,2), common_time, 'linear');
% 2. 计算指标 1: 平均偏移比率 (Shift Ratio)
% 理论目标比率 (如果音色完全未保护，比率应接近 pitch_ratio)
pitch_ratio = 2^(shift_semitones/12);
ratio_F1 = mean(F1_shift_aligned ./ F1_orig_aligned, 'omitnan');
ratio_F2 = mean(F2_shift_aligned ./ F2_orig_aligned, 'omitnan');
% 3. 计算指标 2: 平均频率误差 (Hz)
diff_F1 = mean(F1_shift_aligned - F1_orig_aligned, 'omitnan');
diff_F2 = mean(F2_shift_aligned - F2_orig_aligned, 'omitnan');
% 4. 打印量化评估结果
fprintf('\n========== 变调共振峰量化评估报告 ==========\n');
fprintf('变调半音数: %d\n', shift_semitones);
fprintf('理论变调倍率 (Pitch Ratio): %.4f\n', pitch_ratio);
fprintf('--------------------------------------------\n');
fprintf('F1 平均实测倍率: %.4f (偏差: %.2f%%)\n', ratio_F1, abs(ratio_F1 - pitch_ratio)/pitch_ratio*100);
fprintf('F2 平均实测倍率: %.4f (偏差: %.2f%%)\n', ratio_F2, abs(ratio_F2 - pitch_ratio)/pitch_ratio*100);
fprintf('--------------------------------------------\n');
fprintf('F1 平均频率移动: %.2f Hz\n', diff_F1);
fprintf('F2 平均频率移动: %.2f Hz\n', diff_F2);
fprintf('============================================\n');
% 结论生成
if abs(ratio_F1 - 1) < 0.05
    disp('结论: 共振峰基本未移动，音色保持良好 (Formant Preserved).');
elseif abs(ratio_F1 - pitch_ratio) < 0.05
    disp('结论: 共振峰随音高成比例移动，存在“小黄人效应” (Timbre Shifted).');
else
    disp('结论: 共振峰变化不规律。');
end
end

function plot_formant_comparison(time_axis, mtlb, mtlb_shifted, mtlb_shifted_lpc, mtlb_shifted_cepstral, mtlb_shifted_mt, ...
    t_orig, f_orig, t_shift, f_shift, t_shift_lpc, f_shift_lpc, t_shift_cepstral, f_shift_cepstral, t_shift_mt, f_shift_mt, ...
    signals_to_plot, fs)
% PLOT_FORMANT_COMPARISON 绘制共振峰对比图
% 输入参数:
%   time_axis - 时间轴
%   mtlb - 原始信号
%   mtlb_shifted - 基础变调信号
%   mtlb_shifted_lpc - LPC变调信号
%   mtlb_shifted_cepstral - 倒谱变调信号
%   mtlb_shifted_mt - MTL变调信号
%   t_orig, f_orig - 原始信号共振峰
%   t_shift, f_shift - 基础变调信号共振峰
%   t_shift_lpc, f_shift_lpc - LPC变调信号共振峰
%   t_shift_cepstral, f_shift_cepstral - 倒谱变调信号共振峰
%   t_shift_mt, f_shift_mt - MTL变调信号共振峰
%   signals_to_plot - 要绘制的信号列表，如 {'original', 'mtl'}
%   fs - 采样率

% 定义信号配置
signal_configs = struct(...
    'original', struct('name', 'Original', 'color', 'k', 'data', mtlb, 'time', t_orig, 'formants', f_orig), ...
    'shifted', struct('name', 'Shifted', 'color', [1 0 0 0.5], 'data', mtlb_shifted, 'time', t_shift, 'formants', f_shift), ...
    'lpc', struct('name', 'LPC Shifted', 'color', [0 0 1 0.5], 'data', mtlb_shifted_lpc, 'time', t_shift_lpc, 'formants', f_shift_lpc), ...
    'cepstral', struct('name', 'Cepstral Shifted', 'color', [0 1 0 0.5], 'data', mtlb_shifted_cepstral, 'time', t_shift_cepstral, 'formants', f_shift_cepstral), ...
    'mtl', struct('name', 'MTL Shifted', 'color', [1 0 1 0.5], 'data', mtlb_shifted_mt, 'time', t_shift_mt, 'formants', f_shift_mt) ...
    );

% 创建图形
figure('Color', 'w', 'Position', [100, 100, 1000, 600]);

% (1) 波形对比
subplot(4,1,1);
for i = 1:length(signals_to_plot)
    sig_name = signals_to_plot{i};
    if isfield(signal_configs, sig_name)
        config = signal_configs.(sig_name);
        plot(time_axis, config.data, 'Color', config.color, 'DisplayName', config.name);
        hold on;
    end
end
title('Waveform Comparison');
legend('Location', 'best');
grid on;
axis tight;

% (2) F1 共振峰对比
subplot(4,1,2);
plot_formant_tracks(signals_to_plot, signal_configs, 1, 'F1 Formant Comparison', fs, false);  % 不显示图例

% (3) F2 共振峰对比
subplot(4,1,3);
plot_formant_tracks(signals_to_plot, signal_configs, 2, 'F2 Formant Comparison', fs, false);  % 不显示图例

% (4) F3 共振峰对比
subplot(4,1,4);
plot_formant_tracks(signals_to_plot, signal_configs, 3, 'F3 Formant Comparison', fs, false);  % 不显示图例

end

function plot_formant_tracks(signals_to_plot, signal_configs, formant_idx, title_str, fs, show_legend)
% 绘制单个共振峰的对比图
% show_legend: 是否显示图例，默认为true
if nargin < 6
    show_legend = true;
end

for i = 1:length(signals_to_plot)
    sig_name = signals_to_plot{i};
    if isfield(signal_configs, sig_name)
        config = signal_configs.(sig_name);
        % 获取颜色值，处理不同颜色格式
        if ischar(config.color)
            color_val = config.color;  % 字符颜色如 'k'
        else
            color_val = config.color(1:3);  % RGB/RGBA数组
        end
        if strcmp(sig_name, 'original')
            % 原始信号用较大的点
            plot(config.time, config.formants(:,formant_idx), '.', ...
                'Color', color_val, 'MarkerSize', 8);
        else
            % 其他信号用较小的点
            plot(config.time, config.formants(:,formant_idx), '.', ...
                'Color', color_val, 'MarkerSize', 8);
        end
        hold on;
    end
end

% 只在需要时生成图例
if show_legend
    legend_names = {};
    for i = 1:length(signals_to_plot)
        sig_name = signals_to_plot{i};
        if isfield(signal_configs, sig_name)
            config = signal_configs.(sig_name);
            legend_names{end+1} = [config.name ' F' num2str(formant_idx)];
        end
    end
    legend(legend_names, 'Location', 'best');
end
title(title_str);
ylabel('Frequency (Hz)');
if formant_idx == 3
    xlabel('Time (s)');
end
grid on;
xlim([0, signal_configs.original.time(end)]);

end

function plot_formant_comparison_simple(time_axis, signal_configs, signals_to_plot, fs)
% 简化的共振峰对比绘图函数
% 只绘制选定的信号，适合快速比较

figure('Color', 'w', 'Position', [100, 100, 1000, 600]);

% (1) 波形对比
subplot(4,1,1);
for i = 1:length(signals_to_plot)
    sig_name = signals_to_plot{i};
    if isfield(signal_configs, sig_name)
        config = signal_configs.(sig_name);
        plot(time_axis, config.data, 'Color', config.color, 'DisplayName', config.name);
        hold on;
    end
end
title('Waveform Comparison');
legend('Location', 'best');
grid on;
axis tight;

% (2) F1 共振峰对比
subplot(4,1,2);
plot_formant_tracks_simple(signals_to_plot, signal_configs, 1, 'F1 Formant Comparison', fs, false);  % 不显示图例

% (3) F2 共振峰对比
subplot(4,1,3);
plot_formant_tracks_simple(signals_to_plot, signal_configs, 2, 'F2 Formant Comparison', fs, false);  % 不显示图例

% (4) F3 共振峰对比
subplot(4,1,4);
plot_formant_tracks_simple(signals_to_plot, signal_configs, 3, 'F3 Formant Comparison', fs, false);  % 不显示图例

end

function plot_formant_tracks_simple(signals_to_plot, signal_configs, formant_idx, title_str, fs, show_legend)
% 绘制单个共振峰的对比图（简化版）
% show_legend: 是否显示图例，默认为true
if nargin < 6
    show_legend = true;
end

for i = 1:length(signals_to_plot)
    sig_name = signals_to_plot{i};
    if isfield(signal_configs, sig_name)
        config = signal_configs.(sig_name);
        % 获取颜色值，处理不同颜色格式
        if ischar(config.color)
            color_val = config.color;  % 字符颜色如 'k'
        else
            color_val = config.color(1:3);  % RGB/RGBA数组
        end
        if strcmp(sig_name, 'original')
            % 原始信号用较大的点
            plot(config.time, config.formants(:,formant_idx), '.', ...
                'Color', color_val, 'MarkerSize', 8);
        else
            % 其他信号用较小的点
            plot(config.time, config.formants(:,formant_idx), '.', ...
                'Color', color_val, 'MarkerSize', 8);
        end
        hold on;
    end
end

% 只在需要时生成图例
if show_legend
    legend_names = {};
    for i = 1:length(signals_to_plot)
        sig_name = signals_to_plot{i};
        if isfield(signal_configs, sig_name)
            config = signal_configs.(sig_name);
            legend_names{end+1} = [config.name ' F' num2str(formant_idx)];
        end
    end
    legend(legend_names, 'Location', 'best');
end
title(title_str);
ylabel('Frequency (Hz)');
if formant_idx == 3
    xlabel('Time (s)');
end
grid on;
xlim([0, signal_configs.original.time(end)]);

end

function [t, f_tracks, b_tracks] = extract_formants_doc_style(x, fs, p)
% 帧参数计算
N = length(x);
nWin = round(p.winLen * fs);
nStep = round(p.timeStep * fs);
nFrames = floor((N - nWin) / nStep) + 1;

% 初始化输出
f_tracks = nan(nFrames, 3); % 存储前3个共振峰
b_tracks = nan(nFrames, 3); % 存储对应的带宽
t = ((0:nFrames-1) * nStep + nWin/2) / fs;

% 汉明窗
w = hamming(nWin);

for i = 1:nFrames
    % --- 1. 提取分帧 ---
    idx_start = (i-1)*nStep + 1;
    segment = x(idx_start : idx_start + nWin - 1);

    % 简单静音检测 (防止处理纯静音段报错)
    if mean(segment.^2) < 1e-5
        continue;
    end

    % --- 2. 加窗 (参考文档步骤) ---
    % "使用汉明窗对语音段加窗。"
    x1 = segment .* w;

    % --- 3. 预加重 (参考文档步骤) ---
    % "应用预加重滤波器...全极点高通 (AR(1))... filter(1, preemph, x1)"
    % 注意：这里是 IIR 滤波器
    x1 = filter(1, p.preemph, x1);

    % --- 4. LPC 分析 (参考文档步骤) ---
    % "获得线性预测系数...阶数设置为 8"
    % 为了稳健性，如果 lpc 报错或返回 NaN，需要跳过
    [A, E] = lpc(x1, p.lpcOrder);
    if any(isnan(A))
        continue;
    end

    % --- 5. 求根 (Root Finding) ---
    % "求 lpc 返回的预测多项式的根"
    rts = roots(A);

    % --- 6. 根的处理 ---
    % "只保留虚部具有同一符号的根" (取上半平面)
    rts = rts(imag(rts) >= 0);

    % "确定与这些根对应的角"
    angz = atan2(imag(rts), real(rts));

    % --- 7. 频率和带宽转换 (公式完全参考文档) ---
    % "将用角表示的角频率转换为赫兹"
    [frqs, indices] = sort(angz .* (fs / (2*pi)));

    % "共振峰的带宽由预测多项式零点到单位圆的距离表示"
    % 注意：文档用的公式是 -1/2 * ...
    bw = -1/2 * (fs / (2*pi)) * log(abs(rts(indices)));

    % --- 8. 筛选共振峰 ---
    % "以频率大于 90 Hz 且带宽小于 400 Hz 为标准"
    candidates_f = [];
    candidates_b = [];

    for k = 1:length(frqs)
        if (frqs(k) > 90 && bw(k) < 400)
            candidates_f = [candidates_f; frqs(k)];
            candidates_b = [candidates_b; bw(k)];
        end
    end

    % --- 9. 保存前三个结果 ---
    num_found = length(candidates_f);
    if num_found > 0
        f_tracks(i, 1:min(3, num_found)) = candidates_f(1:min(3, num_found));
        b_tracks(i, 1:min(3, num_found)) = candidates_b(1:min(3, num_found));
    end
end
end