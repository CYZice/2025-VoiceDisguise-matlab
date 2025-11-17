function play_audio(audio_data, fs)
% 播放音频
% audio_data: 音频信号
% fs: 采样率

    if nargin < 2
        fs = 44100; % 默认采样率
    end
    
    if max(abs(audio_data)) > 1
        audio_data = audio_data / max(abs(audio_data));
    end
    
    sound(audio_data, fs);
    
    duration = length(audio_data) / fs;
    fprintf('播放音频: %.2f 秒\n', duration);
end