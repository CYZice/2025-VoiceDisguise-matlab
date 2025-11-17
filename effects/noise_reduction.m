function y = noise_reduction(x, fs, method)
% 降噪处理
% x: 输入信号
% fs: 采样率
% method: 降噪方法

    if nargin < 3
        method = 'spectral';
    end
    
    switch method
        case 'spectral'
            % 谱减法降噪
            y = spectral_subtraction(x, fs);
            
        case 'wiener'
            % 维纳滤波
            y = wiener_filter(x, fs);
            
        otherwise
            y = spectral_subtraction(x, fs);
    end
end

function y = spectral_subtraction(x, fs)
% 谱减法降噪
    frame_len = round(0.03 * fs); % 30ms帧
    hop = round(frame_len / 2);
    
    % 分帧处理
    frames = buffer(x, frame_len, frame_len-hop, 'nodelay');
    noise_est = mean(abs(frames(:,1:5)), 2); % 前5帧作为噪声估计
    
    y_frames = zeros(size(frames));
    
    for i = 1:size(frames,2)
        frame = frames(:,i);
        X = fft(frame);
        
        % 谱减
        mag = max(abs(X) - noise_est, 0);
        phase = angle(X);
        
        % 重建信号
        Y = mag .* exp(1j * phase);
        y_frame = real(ifft(Y));
        
        y_frames(:,i) = y_frame;
    end
    
    % 重叠相加
    y = overlap_add(y_frames, hop);
    y = y(1:length(x));
end