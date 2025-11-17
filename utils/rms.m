function value = rms(x)
% 计算信号的RMS值
% x: 输入信号

    value = sqrt(mean(x.^2));
end