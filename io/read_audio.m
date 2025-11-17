function [audio_data, fs] = read_audio(filename)
% 读取音频文件
% 支持格式: wav, mp3, m4a, flac, ogg

    try
        [audio_data, fs] = audioread(filename);
        
        % 转换为双精度，归一化
        if isinteger(audio_data)
            audio_data = double(audio_data) / double(intmax(class(audio_data)));
        else
            audio_data = double(audio_data);
        end
        
        fprintf('成功读取: %s\n', filename);
        fprintf('采样率: %d Hz, 通道数: %d, 时长: %.2f 秒\n', ...
                fs, size(audio_data,2), size(audio_data,1)/fs);
                
    catch ME
        error('读取音频文件失败: %s', ME.message);
    end
end