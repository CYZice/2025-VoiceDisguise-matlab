clear; clc; close all;

%% 1. 加载测试信号
fprintf('=== 语音变调质量评估测试 ===\n');

% 检查是否存在测试音频文件
if exist('test.wav', 'file')
    [x, fs] = audioread('test.wav');
    fprintf('已加载测试音频: test.wav\n');
elseif exist('../test.wav', 'file')
    [x, fs] = audioread('../test.wav');
    fprintf('已加载测试音频: ../test.wav\n');
else
    % 生成合成语音信号用于测试
    fprintf('未找到测试音频，生成合成语音信号...\n');
    fs = 16000;
    t = 0:1/fs:2; % 2秒信号
    
    % 合成包含共振峰的语音信号
    f0 = 120; % 基频
    formants = [500, 1500, 2500]; % F1, F2, F3
    
    % 生成激励信号
    excitation = sin(2*pi*f0*t) + 0.3*sin(2*pi*2*f0*t) + 0.1*sin(2*pi*3*f0*t);
    
    % 应用共振峰滤波器
    signal = excitation;
    for i = 1:length(formants)
        % 简单的共振峰模拟
        resonance = exp(-(t - 0.1*i).^2 / (0.05^2));
        signal = signal + 0.3 * resonance .* sin(2*pi*formants(i)*t);
    end
    
    % 添加噪声
    signal = signal + 0.05 * randn(size(signal));
    
    % 归一化
    x = signal / max(abs(signal));
    
    fprintf('生成合成语音信号完成\n');
    fprintf('信号长度: %d 样本 (%.1f 秒)\n', length(x), length(x)/fs);
end

if size(x, 2) > 1
    x = mean(x, 2);
    fprintf('检测到立体声，已转换为单声道\n');
end

%% 2. 应用变调处理
fprintf('\n--- 应用变调处理 ---\n');

% 设置变调参数
semitones_up = 3; % 升3个半音

fprintf('变调量: %+d 半音\n', semitones_up);

% 应用变调（无共振峰校正）
fprintf('正在应用变调（无共振峰校正）...\n');
y_ps = pitch_shift(x, semitones_up, fs, 'formant_correction', false);

% 应用变调（有共振峰校正）
fprintf('正在应用变调（有共振峰校正）...\n');
y_fc = pitch_shift(x, semitones_up, fs, 'formant_correction', true);

%% 3. 测试不同的共振峰校正方法
fprintf('\n--- 测试不同校正方法 ---\n');

results = struct();
methods = {'lpc', 'cepstral', 'spectral_tilt'};

for i = 1:length(methods)
    method = methods{i};
    fprintf('正在测试 %s 方法...\n', method);
    
    try
        % 应用变调
        y_shifted = pitch_shift(x, semitones_up, fs, 'formant_correction', false);
        
        % 应用共振峰校正
        y_corrected = formant_correction(y_shifted, semitones_up, fs, ...
                                         'method', method, 'intensity', 0.6);
        
        results(i).method = method;
        results(i).signal = y_corrected;
        results(i).time = 0; % 可以添加处理时间
        
        fprintf('  %s 方法处理完成\n', method);
    catch ME
        warning('%s 方法处理失败: %s', method, ME.message);
        results(i).method = method;
        results(i).signal = y_shifted; % 使用未校正的信号作为备用
        results(i).time = 0;
    end
end

%% 4. 执行质量评估
fprintf('\n=== 执行质量评估 ===\n');

% 调用评估函数
evaluate_metrics(x, y_ps, y_fc, results, fs, semitones_up);

fprintf('\n=== 测试完成！ ===\n');
fprintf('评估结果已保存到文件\n');



function evaluate_metrics(x, y_ps, y_fc, results, fs, semitones_up)
% 语音变调质量评估函数
% 实现四个核心评估指标：MSE、MAE、频谱相关系数、Spectral Distortion
% 
% 输入参数:
%   x - 原始信号
%   y_ps - 变调后信号（无共振峰校正）
%   y_fc - 变调后信号（有共振峰校正）
%   results - 结构体数组，包含不同方法的校正结果
%   fs - 采样率
%   semitones_up - 变调半音数
%
% 输出:
%   控制台打印评估结果和保存评估报告

    fprintf('\n=== 语音变调质量评估报告 ===\n');
    fprintf('变调量: %+d 半音\n', semitones_up);
    fprintf('采样率: %d Hz\n', fs);
    fprintf('信号长度: %d 样本 (%.2f 秒)\n\n', length(x), length(x)/fs);
    
    % 确保信号长度一致
    min_len = min([length(x), length(y_ps), length(y_fc)]);
    x = x(1:min_len);
    y_ps = y_ps(1:min_len);
    y_fc = y_fc(1:min_len);
    
    %% 1. 计算频谱包络
    fprintf('正在计算频谱包络...\n');
    
    % 原始信号包络
    [E_orig, f] = extract_spectral_envelope(x, fs);
    
    % 变调后信号包络（无校正）
    [E_ps, ~] = extract_spectral_envelope(y_ps, fs);
    
    % 变调后信号包络（有校正）
    [E_fc, ~] = extract_spectral_envelope(y_fc, fs);
    
    %% 2. 基础评估指标
    fprintf('\n--- 基础评估指标 ---\n');
    
    % 2.1 MSE (Mean Squared Error)
    mse_ps = mean((E_ps - E_orig).^2);
    mse_fc = mean((E_fc - E_orig).^2);
    
    fprintf('MSE (Mean Squared Error):\n');
    fprintf('  变调后 (无校正): %.4f\n', mse_ps);
    fprintf('  变调后 (有校正): %.4f\n', mse_fc);
    fprintf('  改善率: %.1f%%\n', (mse_ps - mse_fc) / mse_ps * 100);
    
    % 2.2 MAE (Mean Absolute Error)
    mae_ps = mean(abs(E_ps - E_orig));
    mae_fc = mean(abs(E_fc - E_orig));
    
    fprintf('\nMAE (Mean Absolute Error):\n');
    fprintf('  变调后 (无校正): %.4f\n', mae_ps);
    fprintf('  变调后 (有校正): %.4f\n', mae_fc);
    fprintf('  改善率: %.1f%%\n', (mae_ps - mae_fc) / mae_ps * 100);
    
    % 2.3 频谱相关系数
    R_ps = corrcoef(E_ps(:), E_orig(:));
    corr_ps = R_ps(1,2);
    
    R_fc = corrcoef(E_fc(:), E_orig(:));
    corr_fc = R_fc(1,2);
    
    fprintf('\n频谱相关系数 (Correlation):\n');
    fprintf('  变调后 (无校正): %.4f\n', corr_ps);
    fprintf('  变调后 (有校正): %.4f\n', corr_fc);
    fprintf('  改善: %.4f\n', corr_fc - corr_ps);
    
    % 2.4 Spectral Distortion (SD)
    sd_ps = sqrt(mean((E_ps - E_orig).^2));
    sd_fc = sqrt(mean((E_fc - E_orig).^2));
    
    fprintf('\nSpectral Distortion (SD):\n');
    fprintf('  变调后 (无校正): %.4f dB\n', sd_ps);
    fprintf('  变调后 (有校正): %.4f dB\n', sd_fc);
    fprintf('  改善率: %.1f%%\n', (sd_ps - sd_fc) / sd_ps * 100);
    
    %% 3. 不同校正方法的评估
    if ~isempty(results)
        fprintf('\n--- 不同校正方法对比 ---\n');
        
        for i = 1:length(results)
            y_method = results(i).signal;
            method_name = results(i).method;
            
            % 确保长度一致
            min_len_method = min(min_len, length(y_method));
            x_comp = x(1:min_len_method);
            y_method_comp = y_method(1:min_len_method);
            
            % 计算包络
            [E_method, ~] = extract_spectral_envelope(y_method_comp, fs);
            E_orig_comp = E_orig(1:length(E_method)); % 匹配长度
            
            % 计算指标
            mse_method = mean((E_method - E_orig_comp).^2);
            mae_method = mean(abs(E_method - E_orig_comp));
            
            R_method = corrcoef(E_method(:), E_orig_comp(:));
            corr_method = R_method(1,2);
            
            sd_method = sqrt(mean((E_method - E_orig_comp).^2));
            
            fprintf('\n%s 方法:\n', upper(method_name));
            fprintf('  MSE: %.4f\n', mse_method);
            fprintf('  MAE: %.4f\n', mae_method);
            fprintf('  相关系数: %.4f\n', corr_method);
            fprintf('  Spectral Distortion: %.4f dB\n', sd_method);
        end
    end
    
    %% 4. 生成评估图表
    fprintf('\n--- 生成评估图表 ---\n');
    plot_evaluation_metrics(E_orig, E_ps, E_fc, f, semitones_up);
    
    %% 5. 保存评估报告
    save_evaluation_report(x, y_ps, y_fc, results, fs, semitones_up, ...
                          mse_ps, mse_fc, mae_ps, mae_fc, ...
                          corr_ps, corr_fc, sd_ps, sd_fc);
    
    fprintf('\n=== 评估完成！ ===\n');
end

%% 辅助函数：提取频谱包络
function [envelope, freq] = extract_spectral_envelope(signal, fs)
    % 使用倒谱法提取频谱包络
    
    % 参数设置
    nfft = 2048;
    frame_size = round(0.03 * fs);  % 30ms帧长
    hop_size = round(frame_size / 4); % 25%重叠
    
    % 分帧处理
    signal = signal(:);
    if length(signal) < nfft
        signal = [signal; zeros(nfft - length(signal), 1)];
    end
    
    % 计算频谱
    Y = fft(signal, nfft);
    magnitude_spectrum = abs(Y(1:nfft/2+1));
    freq = (0:nfft/2) * fs / nfft;
    
    % 取对数
    log_spectrum = log(magnitude_spectrum + eps);
    
    % 逆FFT得到倒谱
    cepstrum = real(ifft(log_spectrum));
    
    % 倒谱滤波（低通滤波器，保留低频包络信息）
    max_quefrency = round(0.003 * fs); % 3ms倒频率截止
    lifter = zeros(nfft/2+1, 1);
    lifter(1:max_quefrency) = 1;
    
    filtered_cepstrum = cepstrum .* lifter;
    
    % 转换回频域得到包络
    envelope = real(fft(filtered_cepstrum));
    envelope = exp(envelope); % 转换回线性幅度
end

%% 辅助函数：绘制评估指标图表
function plot_evaluation_metrics(E_orig, E_ps, E_fc, freq, semitones_up)
    figure('Name', sprintf('频谱包络评估指标 (变调: %+d 半音)', semitones_up), ...
           'Position', [100, 100, 1200, 800], 'NumberTitle', 'off');
    
    % 子图1: 频谱包络对比
    subplot(2, 2, 1);
    semilogx(freq, 20*log10(E_orig + eps), 'k-', 'LineWidth', 2); hold on;
    semilogx(freq, 20*log10(E_ps + eps), 'r--', 'LineWidth', 1.5);
    semilogx(freq, 20*log10(E_fc + eps), 'b-', 'LineWidth', 2);
    xlabel('频率 (Hz)');
    ylabel('幅度 (dB)');
    title('频谱包络对比');
    legend('原始', '变调后(无校正)', '变调后(有校正)', 'Location', 'best');
    grid on;
    xlim([50, 8000]);
    
    % 子图2: 误差对比
    subplot(2, 2, 2);
    error_ps = abs(E_ps - E_orig);
    error_fc = abs(E_fc - E_orig);
    semilogx(freq, error_ps, 'r--', 'LineWidth', 1.5); hold on;
    semilogx(freq, error_fc, 'b-', 'LineWidth', 2);
    xlabel('频率 (Hz)');
    ylabel('绝对误差');
    title('频谱包络误差对比');
    legend('无校正', '有校正', 'Location', 'best');
    grid on;
    xlim([50, 8000]);
    
    % 子图3: 指标汇总条形图
    subplot(2, 2, 3);
    metrics_ps = [mean((E_ps - E_orig).^2), mean(abs(E_ps - E_orig)), ...
                  sqrt(mean((E_ps - E_orig).^2))];
    metrics_fc = [mean((E_fc - E_orig).^2), mean(abs(E_fc - E_orig)), ...
                  sqrt(mean((E_fc - E_orig).^2))];
    
    categories = {'MSE', 'MAE', 'SD'};
    bar_data = [metrics_ps', metrics_fc'];
    bar(bar_data, 'FaceColor', [0.8, 0.2, 0.2; 0.2, 0.2, 0.8]);
    set(gca, 'XTickLabel', categories);
    ylabel('误差值');
    title('评估指标对比');
    legend('无校正', '有校正', 'Location', 'best');
    
    % 子图4: 相关系数
    subplot(2, 2, 4);
    % 计算不同频率段的相关系数
    freq_bands = [0, 500, 1000, 2000, 4000, 8000];
    band_names = {'0-500', '500-1k', '1k-2k', '2k-4k', '4k-8k'};
    
    corr_ps_bands = zeros(1, length(band_names));
    corr_fc_bands = zeros(1, length(band_names));
    
    for i = 1:length(band_names)
        band_idx = (freq >= freq_bands(i)) & (freq < freq_bands(i+1));
        if sum(band_idx) > 1
            R_ps = corrcoef(E_ps(band_idx), E_orig(band_idx));
            corr_ps_bands(i) = R_ps(1,2);
            
            R_fc = corrcoef(E_fc(band_idx), E_orig(band_idx));
            corr_fc_bands(i) = R_fc(1,2);
        end
    end
    
    bar_data = [corr_ps_bands; corr_fc_bands];
    bar(bar_data', 'FaceColor', [0.8, 0.2, 0.2; 0.2, 0.2, 0.8]');
    set(gca, 'XTickLabel', band_names);
    ylabel('相关系数');
    title('不同频段相关系数');
    legend('无校正', '有校正', 'Location', 'best');
    ylim([0, 1]);
    
    % 保存图表
    saveas(gcf, sprintf('evaluation_metrics_%dsemitones.png', semitones_up));
end

%% 辅助函数：保存评估报告
function save_evaluation_report(x, y_ps, y_fc, results, fs, semitones_up, ...
                               mse_ps, mse_fc, mae_ps, mae_fc, ...
                               corr_ps, corr_fc, sd_ps, sd_fc)
    
    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    filename = sprintf('evaluation_report_%dsemitones_%s.txt', semitones_up, timestamp);
    
    fid = fopen(filename, 'w');
    if fid == -1
        warning('无法保存评估报告');
        return;
    end
    
    fprintf(fid, '===========================================\n');
    fprintf(fid, '语音变调质量评估报告\n');
    fprintf(fid, '===========================================\n');
    fprintf(fid, '评估时间: %s\n', timestamp);
    fprintf(fid, '变调量: %+d 半音\n', semitones_up);
    fprintf(fid, '采样率: %d Hz\n', fs);
    fprintf(fid, '信号长度: %d 样本 (%.2f 秒)\n\n', length(x), length(x)/fs);
    
    fprintf(fid, '--- 基础评估指标 ---\n');
    fprintf(fid, 'MSE (Mean Squared Error):\n');
    fprintf(fid, '  变调后 (无校正): %.6f\n', mse_ps);
    fprintf(fid, '  变调后 (有校正): %.6f\n', mse_fc);
    fprintf(fid, '  改善率: %.1f%%\n\n', (mse_ps - mse_fc) / mse_ps * 100);
    
    fprintf(fid, 'MAE (Mean Absolute Error):\n');
    fprintf(fid, '  变调后 (无校正): %.6f\n', mae_ps);
    fprintf(fid, '  变调后 (有校正): %.6f\n', mae_fc);
    fprintf(fid, '  改善率: %.1f%%\n\n', (mae_ps - mae_fc) / mae_ps * 100);
    
    fprintf(fid, '频谱相关系数 (Correlation):\n');
    fprintf(fid, '  变调后 (无校正): %.4f\n', corr_ps);
    fprintf(fid, '  变调后 (有校正): %.4f\n', corr_fc);
    fprintf(fid, '  改善: %.4f\n\n', corr_fc - corr_ps);
    
    fprintf(fid, 'Spectral Distortion (SD):\n');
    fprintf(fid, '  变调后 (无校正): %.6f dB\n', sd_ps);
    fprintf(fid, '  变调后 (有校正): %.6f dB\n', sd_fc);
    fprintf(fid, '  改善率: %.1f%%\n', (sd_ps - sd_fc) / sd_ps * 100);
    
    if ~isempty(results)
        fprintf(fid, '\n--- 不同校正方法对比 ---\n');
        
        for i = 1:length(results)
            y_method = results(i).signal;
            method_name = results(i).method;
            
            % 确保长度一致
            min_len_method = min(length(x), length(y_method));
            x_comp = x(1:min_len_method);
            y_method_comp = y_method(1:min_len_method);
            
            % 计算包络和指标
            [E_method, ~] = extract_spectral_envelope(y_method_comp, fs);
            [E_orig_comp, ~] = extract_spectral_envelope(x_comp, fs);
            
            mse_method = mean((E_method - E_orig_comp).^2);
            mae_method = mean(abs(E_method - E_orig_comp));
            
            R_method = corrcoef(E_method(:), E_orig_comp(:));
            corr_method = R_method(1,2);
            
            sd_method = sqrt(mean((E_method - E_orig_comp).^2));
            
            fprintf(fid, '\n%s 方法:\n', upper(method_name));
            fprintf(fid, '  MSE: %.6f\n', mse_method);
            fprintf(fid, '  MAE: %.6f\n', mae_method);
            fprintf(fid, '  相关系数: %.4f\n', corr_method);
            fprintf(fid, '  Spectral Distortion: %.6f dB\n', sd_method);
        end
    end
    
    fprintf(fid, '\n===========================================\n');
    fclose(fid);
    
    fprintf('评估报告已保存: %s\n', filename);
end