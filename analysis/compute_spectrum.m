function [f, mag_dB] = compute_spectrum(x, fs, fft_size)
% 通用频谱计算函数（优化版）
% 输入：
%   x: 输入信号（实信号或复信号），向量或矩阵（每列为一个通道）
%   fs: 采样率 (Hz)
%   fft_size: FFT点数（可选）。如果提供，将进行指定点数的FFT；如果未提供或为空，则使用信号x的长度。
% 输出：
%   f: 频率轴 (Hz)，范围从直流(0 Hz)到奈奎斯特频率(fs/2)
%   mag_dB: 归一化的幅度谱 (dB)，已归一化到最大值0 dB

    % 1. 参数验证与设置FFT点数 N
    if nargin < 3 || isempty(fft_size)
        % 如果未提供fft_size参数，则使用信号x的长度
        N = length(x);
    else
        % 如果提供了fft_size参数，则使用该值
        N = fft_size;
    end

    % 2. 执行FFT。使用N点FFT。如果x长度小于N，会自动补零；如果大于N，会被截断。
    X = fft(x, N);
    
    % 3. 计算单边频谱（仅取正频率部分，包括直流分量和奈奎斯特频率）
    % 确定单边谱的长度。对于实数信号，频谱关于中点共轭对称，只需取前一半（+1以确保包含奈奎斯特频率点）。
    num_unique_pts = floor(N/2) + 1; % 单边谱的点数
    
    % 提取单边频谱的幅度。除以N是为了进行幅值校正，得到真实的幅度值。
    mag_spectrum = abs(X(1:num_unique_pts)) / N;
    % 对于非直流分量，由于舍弃了负频率部分，其能量减半，因此幅度需要乘以2进行补偿（直流分量和奈奎斯特频率点不乘2）
    if mod(N, 2) % 如果N是奇数，没有独立的奈奎斯特频率点
        mag_spectrum(2:end) = 2 * mag_spectrum(2:end);
    else % 如果N是偶数，最后一个点是奈奎斯特频率点，不乘2
        mag_spectrum(2:end-1) = 2 * mag_spectrum(2:end-1);
    end
    
    % 4. 构建对应的正频率轴 (Hz)
    f = (0:(num_unique_pts-1)) * fs / N;
    
    % 5. 将幅度转换为分贝 (dB)，并进行归一化（使最大值变为0 dB）
    mag_dB = 20 * log10(mag_spectrum + eps); % 加eps防止对0取对数
    mag_dB = mag_dB - max(mag_dB); % 归一化到0 dB

end