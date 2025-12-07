function test_pitch_shift_formants_demo()
% 变调共振峰分析演示（简化版）

addpath('core')

% 1. 加载数据
S = load('mtlb.mat');
mtlb = S.mtlb;
Fs = S.Fs;
dt = 1/Fs;
I0 = round(0.1/dt);
Iend = round(0.25/dt);
x = mtlb(I0:Iend);

% 2. 变调处理 (升高 4 个半音)
shift_semitones = -3;
disp(['正在执行变调 (升调 ' num2str(shift_semitones) ' 半音)...']);

% 调用变调函数
mtlb_shifted = pitch_shift(mtlb, shift_semitones, Fs,'formant_correction',false);
mtlb_shifted_lpc = pitch_shift(mtlb, shift_semitones, Fs,'formant_correction',true,'method','lpc');
mtlb_shifted_cepstral = pitch_shift(mtlb, shift_semitones, Fs,'formant_correction',true,'method','cepstral');

% 对齐长度
len = min([length(mtlb), length(mtlb_shifted_lpc), length(mtlb_shifted_cepstral)]);
mtlb = mtlb(1:len);
mtlb_shifted = mtlb_shifted(1:len);
mtlb_shifted_lpc = mtlb_shifted_lpc(1:len);
mtlb_shifted_cepstral = mtlb_shifted_cepstral(1:len);

% 3. 提取共振峰
params.lpcOrder = 8;
params.winLen = 0.030;
params.timeStep = 0.010;
params.preemph = [1 0.63];

disp('提取原语音共振峰...');
[t_orig, f_orig] = extract_formants_doc_style(mtlb, Fs, params);

disp('提取变调语音共振峰...');
[t_shift, f_shift] = extract_formants_doc_style(mtlb_shifted, Fs, params);

disp('提取 LPC 变调语音共振峰...');
[t_shift_lpc, f_shift_lpc] = extract_formants_doc_style(mtlb_shifted_lpc, Fs, params);

disp('提取倒谱域 变调语音共振峰...');
[t_shift_cepstral, f_shift_cepstral] = extract_formants_doc_style(mtlb_shifted_cepstral, Fs, params);

% 4. 绘制对比图
signals_to_plot = {'original','lpc','cepstral'};
time_axis = (0:len-1)/Fs;

% 调用绘图函数
plot_formant_comparison_simple(time_axis, mtlb, mtlb_shifted, mtlb_shifted_lpc, mtlb_shifted_cepstral, ...
    t_orig, f_orig, t_shift, f_shift, t_shift_lpc, f_shift_lpc, t_shift_cepstral, f_shift_cepstral, ...
    signals_to_plot, Fs);

disp('分析完成。');

% 5. 量化评估
try
    % 数据对齐
    common_time = t_orig(t_orig <= t_shift(end));
    F1_orig_aligned = f_orig(1:length(common_time), 1);
    F2_orig_aligned = f_orig(1:length(common_time), 2);
    
    F1_shift_aligned = interp1(t_shift, f_shift_cepstral(:,1), common_time, 'linear');
    F2_shift_aligned = interp1(t_shift, f_shift_cepstral(:,2), common_time, 'linear');
    
    % 计算指标
    pitch_ratio = 2^(shift_semitones/12);
    ratio_F1 = mean(F1_shift_aligned ./ F1_orig_aligned, 'omitnan');
    ratio_F2 = mean(F2_shift_aligned ./ F2_orig_aligned, 'omitnan');
    diff_F1 = mean(F1_shift_aligned - F1_orig_aligned, 'omitnan');
    diff_F2 = mean(F2_shift_aligned - F2_orig_aligned, 'omitnan');
    
    % 打印结果
    fprintf('\n========== 变调共振峰评估报告 ==========\n');
    fprintf('变调半音数: %d\n', shift_semitones);
    fprintf('理论变调倍率: %.4f\n', pitch_ratio);
    fprintf('F1 平均实测倍率: %.4f (偏差: %.2f%%)\n', ratio_F1, abs(ratio_F1 - pitch_ratio)/pitch_ratio*100);
    fprintf('F2 平均实测倍率: %.4f (偏差: %.2f%%)\n', ratio_F2, abs(ratio_F2 - pitch_ratio)/pitch_ratio*100);
    fprintf('F1 平均频率移动: %.2f Hz\n', diff_F1);
    fprintf('F2 平均频率移动: %.2f Hz\n', diff_F2);
    fprintf('========================================\n');
    
    % 结论
    if abs(ratio_F1 - 1) < 0.05
        disp('结论: 共振峰基本未移动，音色保持良好。');
    elseif abs(ratio_F1 - pitch_ratio) < 0.05
        disp('结论: 共振峰随音高成比例移动，存在"小黄人效应"。');
    else
        disp('结论: 共振峰变化不规律。');
    end
    
catch ME
    warning('量化评估失败: %s', ME.message);
end

end

function plot_formant_comparison_simple(time_axis, mtlb, mtlb_shifted, mtlb_shifted_lpc, mtlb_shifted_cepstral, ...
    t_orig, f_orig, t_shift, f_shift, t_shift_lpc, f_shift_lpc, t_shift_cepstral, f_shift_cepstral, ...
    signals_to_plot, fs)
% 简化共振峰对比绘图

signal_configs = struct(...
    'original', struct('name', '原始', 'color', 'k', 'data', mtlb, 'time', t_orig, 'formants', f_orig), ...
    'shifted', struct('name', '变调', 'color', [1 0 0], 'data', mtlb_shifted, 'time', t_shift, 'formants', f_shift), ...
    'lpc', struct('name', 'LPC校正', 'color', [0 0 1], 'data', mtlb_shifted_lpc, 'time', t_shift_lpc, 'formants', f_shift_lpc), ...
    'cepstral', struct('name', '倒谱校正', 'color', [0 1 0], 'data', mtlb_shifted_cepstral, 'time', t_shift_cepstral, 'formants', f_shift_cepstral) ...
    );

figure('Color', 'w', 'Position', [100, 100, 1000, 600]);

% 波形对比
subplot(3,1,1);
for i = 1:length(signals_to_plot)
    sig_name = signals_to_plot{i};
    if isfield(signal_configs, sig_name)
        config = signal_configs.(sig_name);
        plot(time_axis, config.data, 'Color', config.color, 'DisplayName', config.name);
        hold on;
    end
end
title('波形对比');
legend('Location', 'best');
grid on; axis tight;

% F1 共振峰对比
subplot(3,1,2);
plot_formant_tracks_simple(signals_to_plot, signal_configs, 1, 'F1 共振峰对比', fs);

% F2 共振峰对比
subplot(3,1,3);
plot_formant_tracks_simple(signals_to_plot, signal_configs, 2, 'F2 共振峰对比', fs);

end

function plot_formant_tracks_simple(signals_to_plot, signal_configs, formant_idx, title_str, fs)
% 简化共振峰轨迹绘制

for i = 1:length(signals_to_plot)
    sig_name = signals_to_plot{i};
    if isfield(signal_configs, sig_name)
        config = signal_configs.(sig_name);
        if ischar(config.color)
            color_val = config.color;
        else
            color_val = config.color(1:3);
        end
        plot(config.time, config.formants(:,formant_idx), '.', ...
            'Color', color_val, 'MarkerSize', 6);
        hold on;
    end
end

legend_names = {};
for i = 1:length(signals_to_plot)
    sig_name = signals_to_plot{i};
    if isfield(signal_configs, sig_name)
        config = signal_configs.(sig_name);
        legend_names{end+1} = [config.name ' F' num2str(formant_idx)];
    end
end
legend(legend_names, 'Location', 'best');
title(title_str);
ylabel('频率 (Hz)');
if formant_idx == 2
    xlabel('时间 (s)');
end
grid on;
xlim([0, signal_configs.original.time(end)]);

end

function [t, f_tracks, b_tracks] = extract_formants_doc_style(x, fs, p)
% 提取共振峰（简化版）
N = length(x);
nWin = round(p.winLen * fs);
nStep = round(p.timeStep * fs);
nFrames = floor((N - nWin) / nStep) + 1;

f_tracks = nan(nFrames, 3);
b_tracks = nan(nFrames, 3);
t = ((0:nFrames-1) * nStep + nWin/2) / fs;

w = hamming(nWin);

for i = 1:nFrames
    idx_start = (i-1)*nStep + 1;
    segment = x(idx_start : idx_start + nWin - 1);
    
    if mean(segment.^2) < 1e-5
        continue;
    end
    
    % 加窗和预加重
    x1 = segment .* w;
    x1 = filter(1, p.preemph, x1);
    
    % LPC分析
    [A, E] = lpc(x1, p.lpcOrder);
    if any(isnan(A))
        continue;
    end
    
    % 求根和频率转换
    rts = roots(A);
    rts = rts(imag(rts) >= 0);
    angz = atan2(imag(rts), real(rts));
    [frqs, indices] = sort(angz .* (fs / (2*pi)));
    bw = -1/2 * (fs / (2*pi)) * log(abs(rts(indices)));
    
    % 筛选共振峰
    candidates_f = [];
    candidates_b = [];
    
    for k = 1:length(frqs)
        if (frqs(k) > 90 && bw(k) < 400)
            candidates_f = [candidates_f; frqs(k)];
            candidates_b = [candidates_b; bw(k)];
        end
    end
    
    % 保存前三个结果
    num_found = length(candidates_f);
    if num_found > 0
        f_tracks(i, 1:min(3, num_found)) = candidates_f(1:min(3, num_found));
        b_tracks(i, 1:min(3, num_found)) = candidates_b(1:min(3, num_found));
    end
end

end