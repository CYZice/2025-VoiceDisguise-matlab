function main_voice_processing()
% 语音信号处理系统

    clc; clear; close all;
    addpath("io"); addpath("analysis"); addpath("core"); addpath("effects"); addpath("filters"); addpath("utils");
    
    fprintf('=== 语音信号处理系统 ===\n');
    fprintf('1. 录音与读取\n');
    fprintf('2. 频谱分析\n');
    fprintf('3. 滤波器设计与应用\n');
    fprintf('4. 变声处理\n');
    fprintf('5. 时间拉伸\n');
    fprintf('6. 结果播放与保存\n\n');
    
    fs = 44100;  % 采样率
    duration = 5; % 录音时长
    
    try
        %% 1. 录音或读取音频文件
        choice = input('选择输入方式 (1-录音, 2-读取文件): ');
        
        if choice == 1
            fprintf('开始录音 %d 秒...\n', duration);
            x = record_audio(duration, fs);
            filename = 'recorded_audio.wav';
            audiowrite(filename, x, fs);
            fprintf('录音已保存为: %s\n', filename);
        else
            [filename, pathname] = uigetfile({'*.wav;*.mp3;*.m4a','音频文件'});
            if filename == 0
                error('未选择文件');
            end
            filepath = fullfile(pathname, filename);
            [x, fs] = read_audio(filepath);
            fprintf('读取文件: %s, 采样率: %d Hz, 时长: %.2f 秒\n', ...
                    filename, fs, length(x)/fs);
        end
        
        % 转换为单声道
        if size(x, 2) > 1
            x = mean(x, 2);
        end
        
        %% 2. 频谱分析
        fprintf('\n=== 频谱分析 ===\n');
        spectrum_analysis(x, fs, '原始信号分析');
        
       %% 3. 滤波器设计与应用
        fprintf('\n=== 滤波器设计 ===\n');
        
        fc_low = 100;   % 低频截止
        fc_high = 3500; % 高频截止
        filter_order = 4;
        
        try
            [b, a] = design_filter('bandpass', fc_low, fc_high, fs, filter_order);
            plot_frequency_response(b, a, fs, '带通滤波器频响');
            
            x_filtered = apply_filter(x, b, a);
            spectrum_analysis(x_filtered, fs, '滤波后信号分析');
            
        catch ME
            fprintf('滤波器处理失败: %s\n', ME.message);
            fprintf('使用原始信号继续处理\n');
            x_filtered = x;
        end
        
        %% 4. 变声处理
        fprintf('\n=== 变声处理 ===\n');
        semitones = input('输入变调半音数（正数升调，负数降调）: ');
        
        y_pitch = pitch_shift(x_filtered, semitones, fs, ...
                             'formant_correction', true, 'nfft', 1024,'method','cepstral','beta',1.15);
        spectrum_analysis(y_pitch, fs, '变调后信号分析');

        
        %% 5. 时间拉伸
        fprintf('\n=== 时间拉伸 ===\n');
        time_ratio = input('输入时间拉伸比例（>1变慢，<1变快）: ');
        
        y_time = time_stretch(x_filtered, time_ratio, fs);
        
        spectrum_analysis(y_time, fs, '变速后信号分析');

        
        %% 6. 结果显示与播放
        fprintf('\n=== 结果显示 ===\n');
            
        plot_signals({x, x_filtered, y_pitch, y_time}, fs, ...
                  {'原始信号', '滤波后信号', '变调信号', '时间拉伸信号'});
        
        % 播放结果对比
        play_comparison(x, y_pitch,y_time, fs);
        
        % 保存结果
        output_file = 'processed_audio.wav';
        audiowrite(output_file,y_pitch, fs);
        fprintf('处理结果已保存为: %s\n', output_file);
        
        fprintf('\n=== 处理完成 ===\n');
        
    catch ME
        fprintf('错误: %s\n', ME.message);
    end
end

function play_comparison(original, pitch,time, fs)
% 播放原始和处理后的音频对比
    fprintf('播放原始音频...\n');
    sound(original, fs);
    pause(length(original)/fs + 1);

    sound(pitch, fs);
    pause(length(pitch)/fs + 1);
    
    fprintf('播放处理后的音频...\n');
    sound(time, fs);
end