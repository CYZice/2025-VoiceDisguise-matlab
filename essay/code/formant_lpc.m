function [F, B, A] = formant_lpc(x, fs, order, winlen, preemph)
% LPC 共振峰估计（简化版）

if nargin < 3, order = 12; end
if nargin < 4, winlen = 0.025; end
if nargin < 5, preemph = 0.63; end

% 1. 预处理
x = x(:);  % 转为列向量
if preemph > 0
    x = filter([1 -preemph], 1, x);
end

% 2. 分帧加窗
nwin = round(winlen * fs);
w = hamming(nwin);
if length(x) < nwin
    x = [x; zeros(nwin - length(x), 1)];
end

% 3. LPC 分析
[a, e] = lpc(x, order);

% 4. 求根
rts = roots(a);
rts = rts(imag(rts) > 0);  % 只保留上半平面

% 5. 计算频率和带宽
ang = angle(rts);
freqs = ang * fs / (2 * pi);
bws = -0.5 * fs * log(abs(rts)) / (2 * pi);

% 6. 筛选有效共振峰
valid_idx = (freqs > 90) & (freqs < 4000) & (bws < 700);
F = freqs(valid_idx);
B = bws(valid_idx);

% 7. 排序
[sorted_freqs, idx] = sort(F);
F = sorted_freqs;
B = B(idx);

% 8. 返回 LPC 系数
A = a;

end