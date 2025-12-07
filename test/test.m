%% 共振峰校正对比测试程序
% 用于测试和验证重构后的plot_formant_correction_comparison函数
% 支持多种测试模式：基本测试、高级参数测试、批量测试

%% 清理和初始化
clear; close all; clc;
fprintf('=== 共振峰校正对比测试程序 ===\n');

%% 1. 音频读取和预处理

% 尝试读取测试音频文件
fprintf('正在读取音频文件...\n');
load mtlb; % 得到 mtlb 和 Fs
x=mtlb;
fs=Fs;

% 如果是立体声，转换为单声道
if size(x, 2) > 1
    x = mean(x, 2);
    fprintf('检测到立体声，已转换为单声道\n');
end

% 信号基本信息
fprintf('音频文件读取成功！\n');
fprintf('信号长度: %d 样本 (%.2f 秒)\n', length(x), length(x)/fs);
fprintf('采样率: %d Hz\n', fs);

% % 信号归一化
% x = x / max(abs(x));
% fprintf('信号已归一化\n');



%% 5. 保存图表测试
fprintf('\n=== 保存图表测试 ===\n');
try
    fprintf('正在测试图表保存功能...\n');
    plot_formant_correction_comparison(x, fs, -5, ...
        'methods', {'lpc', 'cepstral','mlt'}, ...
        'intensity', 0.8, ...
        'show_plots', true, ...
        'save_figures', true);

    fprintf('图表保存测试完成！（图表已保存到当前目录）\n');

catch ME
    fprintf('图表保存测试失败: %s\n', ME.message);
end




%% 清理
clear semitones_values test_configs processing_times;
