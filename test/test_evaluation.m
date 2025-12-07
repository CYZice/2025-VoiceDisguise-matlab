%% 语音变调质量评估测试脚本
% 演示如何使用 evaluate_metrics 函数进行质量评估

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

% 应用变调
fprintf('正在应用变调（倒频谱）...\n');
y_fc = pitch_shift(x, semitones_up, fs, 'formant_correction', true);

% 应用变调
fprintf('正在应用变调（lpc）...\n');
y_lpc = pitch_shift(x, semitones_up, fs, 'formant_correction', true, 'method', 'lpc');


[X,~,~] = extract_spectral_envelope_cepstral(x, fs);
[Y_ps,~,~] = extract_spectral_envelope_cepstral(y_ps, fs);
[Y_fc,~,~] = extract_spectral_envelope_cepstral(y_fc, fs);
[Y_lpc,~,~] = extract_spectral_envelope_cepstral(y_lpc, fs);


evaluate_envelope_metrics(X, Y_ps);
evaluate_envelope_metrics(X, Y_fc);
evaluate_envelope_metrics(X, Y_lpc);
%% 3. 测试不同的共振峰校正方法

%% 4. 执行质量评估
fprintf('\n=== 执行质量评估 ===\n');    

% 调用评估函数
evaluate_metrics(x, y_ps, y_fc, y_lpc, results, fs, semitones_up);

fprintf('\n=== 测试完成！ ===\n');
fprintf('评估结果已保存到文件\n');



clear; clc; close all;


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

    % 确保列向量
    E_orig = E_orig(:);
    E_corr = E_corr(:);

    % 1. MSE
    metrics.MSE = mean((E_corr - E_orig).^2);


    % 2. MAE
    metrics.MAE = mean(abs(E_corr - E_orig));


    % 3. Correlation
    R = corrcoef(E_corr, E_orig);
    metrics.Correlation = R(1,2);
 

    % 4. Spectral Distortion（SD）
    metrics.SD = sqrt(mean((E_corr - E_orig).^2));


    fprintf("Envelope Metrics:\n");
    fprintf("  MSE: %.4f\n", metrics.MSE);
    fprintf("  MAE: %.4f\n", metrics.MAE);
    fprintf("  Correlation: %.4f\n", metrics.Correlation);
    fprintf("  SD: %.4f\n", metrics.SD);

end


function [env_db, cepstrum, cep_liftered] = extract_spectral_envelope_cepstral(x, fs, nfft, lifter_order)

    if nargin < 3, nfft = 1024; end
    if nargin < 4, lifter_order = 30; end

    x = x(:);

    % 1. FFT
    X = fft(x, nfft);
    mag = abs(X) + eps;

    % 2. log-spectrum
    logmag = log(mag);

    % 3. real cepstrum
    cepstrum = real(ifft(logmag));

    % 4. Liftering（只保留低 quefrency）
    cep_liftered = zeros(size(cepstrum));
    cep_liftered(1:lifter_order+1) = cepstrum(1:lifter_order+1);
    cep_liftered(end-lifter_order+1:end) = cepstrum(end-lifter_order+1:end);

    % 5. 回到频域
    log_env = real(fft(cep_liftered));

    % 6. 转线性与dB
    env = exp(log_env);
    env_db = 20*log10(env(1:nfft/2+1));

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