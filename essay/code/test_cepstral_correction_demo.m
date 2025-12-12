function test_cepstral_correction_demo()
% 倒谱域共振峰校正演示（简化版）

addpath('core')

% 1. 加载数据
S = load('mtlb.mat');
mtlb = S.mtlb;
Fs = S.Fs;

% 2. 参数设置
shift_semitones = -3;  % 降低 3 个半音

% 3. 变调处理
disp('正在执行变调处理...');
mtlb_shifted = pitch_shift(mtlb, shift_semitones, Fs, 'formant_correction', false);
mtlb_corrected = pitch_shift(mtlb, shift_semitones, Fs, 'formant_correction', true, 'method', 'cepstral');

% 4. 对齐长度
len = min([length(mtlb), length(mtlb_shifted), length(mtlb_corrected)]);
mtlb = mtlb(1:len);
mtlb_shifted = mtlb_shifted(1:len);
mtlb_corrected = mtlb_corrected(1:len);

% 5. 绘制对比图
time_axis = (0:len-1)/Fs;

figure('Color', 'w', 'Position', [100, 100, 800, 600]);

% 波形对比
subplot(3,1,1);
plot(time_axis, mtlb, 'k', 'DisplayName', '原始');
hold on;
plot(time_axis, mtlb_shifted, 'r', 'DisplayName', '变调');
plot(time_axis, mtlb_corrected, 'g', 'DisplayName', '倒谱校正');
title('波形对比');
legend('Location', 'best');
grid on;

% 频谱对比（取中间段）
mid_start = round(len/3);
mid_end = round(2*len/3);

% 原始信号频谱
subplot(3,1,2);
[P1, f1] = pwelch(mtlb(mid_start:mid_end), [], [], [], Fs);
semilogx(f1, 10*log10(P1), 'k', 'DisplayName', '原始');
hold on;
[P2, f2] = pwelch(mtlb_shifted(mid_start:mid_end), [], [], [], Fs);
semilogx(f2, 10*log10(P2), 'r', 'DisplayName', '变调');
[P3, f3] = pwelch(mtlb_corrected(mid_start:mid_end), [], [], [], Fs);
semilogx(f3, 10*log10(P3), 'g', 'DisplayName', '倒谱校正');
xlim([100 4000]);
title('频谱对比');
legend('Location', 'best');
grid on;

% 共振峰对比
subplot(3,1,3);
% 提取共振峰（简化版）
[F_orig, ~] = formant_lpc(mtlb, Fs);
[F_shift, ~] = formant_lpc(mtlb_shifted, Fs);
[F_corr, ~] = formant_lpc(mtlb_corrected, Fs);

% 绘制前三个共振峰
bar([F_orig(1:3), F_shift(1:3), F_corr(1:3)]);
set(gca, 'XTickLabel', {'F1', 'F2', 'F3'});
legend('原始', '变调', '倒谱校正');
title('共振峰频率对比');
grid on;

% 6. 结果分析
disp('倒谱域共振峰校正演示完成。');
disp(['原始 F1: ' num2str(F_orig(1)) ' Hz']);
disp(['变调 F1: ' num2str(F_shift(1)) ' Hz']);
disp(['校正 F1: ' num2str(F_corr(1)) ' Hz']);

end