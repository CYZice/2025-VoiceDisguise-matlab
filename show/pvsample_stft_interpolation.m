function c = pvsample(b, t, hop)
% STFT数组插值 - 相位声码器核心
% b: STFT数组, t: 时间采样点, hop: 帧移

[rows,cols] = size(b);
N = 2*(rows-1);

if hop == 0
  hop = N/2;
end

c = zeros(rows, length(t));

% 计算每个频段的相位增量
dphi = zeros(1,N/2+1);
dphi(2:(1 + N/2)) = (2*pi*hop)./(N./(1:(N/2)));

ph = angle(b(:,1));

b = [b,zeros(rows,1)];

ocol = 1;
for tt = t
  % 获取两个STFT列
  bcols = b(:,floor(tt)+[1 2]);
  tf = tt - floor(tt);
  
  % 幅度插值
  bmag = (1-tf)*abs(bcols(:,1)) + tf*(abs(bcols(:,2)));
  
  % 计算相位差
  dp = angle(bcols(:,2)) - angle(bcols(:,1)) - dphi';
  dp = dp - 2 * pi * round(dp/(2*pi));
  
  % 保存处理后的列
  c(:,ocol) = bmag .* exp(j*ph);
  
  % 累积相位
  ph = ph + dphi' + dp;
  ocol = ocol+1;
end

% ... 省略相位展开和边界处理细节