function audio_data = record_audio(duration, fs)
% 录音功能
% duration: 录音时长（秒）
% fs: 采样率

    if nargin < 2
        fs = 44100; % 默认采样率
    end
    if nargin < 1
        duration = 5; % 默认5秒
    end
    
    fprintf('准备录音...\n');
    pause(1);
    
    % 创建录音对象
    recorder = audiorecorder(fs, 16, 1); % 16位，单声道
    
    fprintf('开始录音 %d 秒...\n', duration);
    recordblocking(recorder, duration);
    fprintf('录音结束\n');
    
    % 获取录音数据
    audio_data = getaudiodata(recorder);
    
    % 归一化
    audio_data = audio_data / max(abs(audio_data));
end