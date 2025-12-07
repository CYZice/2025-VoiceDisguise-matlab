function y = pvoc(x, r, n)
% 相位声码器时间拉伸
% x: 输入信号, r: 时间比例因子, n: FFT大小

if nargin < 3
  n = 1024;
end  

% 25%重叠的STFT
hop = n/4;
scf = 1.0;  

X = scf * my_stft(x', n, n, hop);  

[rows, cols] = size(X);
t = 0:r:(cols-2);

X2 = pvsample(X, t, hop);  

% 逆变换回波形
y = my_istft(X2, n, n, hop)';

% ... 省略相位计算和插值细节