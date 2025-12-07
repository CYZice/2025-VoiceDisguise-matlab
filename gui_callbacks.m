% GUI回调函数集合

function gui_callbacks()

end


function menu_open_file(fig, ~)
% 打开音频文件
    update_status(fig, '正在打开音频文件...');
    
    [filename, pathname] = uigetfile({'*.wav;*.mp3;*.m4a','音频文件'});
    if filename == 0
        update_status(fig, '用户取消选择文件');
        return;
    end
    
    filepath = fullfile(pathname, filename);
    
    try
        app_data = guidata(fig);
        
        % 读取音频文件
        [x, fs] = read_audio(filepath);
        
        % 转换为单声道
        if size(x, 2) > 1
            x = mean(x, 2);
        end
        
        % 保存到应用程序数据
        app_data.original_signal = x;
        app_data.fs = fs;
        app_data.current_file = filename;
        app_data.is_processed = false;
        
        % 重置处理结果
        app_data.filtered_signal = [];
        app_data.pitch_shifted = [];
        app_data.time_stretched = [];
        
        guidata(fig, app_data);
        
        % 更新界面
        update_file_info(fig, filename, length(x)/fs, fs);
        update_waveform_plot(fig);
        update_spectrum_plot(fig);
        update_status(fig, sprintf('成功加载: %s', filename));
        
    catch ME
        update_status(fig, sprintf('加载文件失败: %s', ME.message));
        errordlg(sprintf('无法加载文件: %s', ME.message), '文件错误');
    end
end

function menu_record_audio(fig, ~)
% 录制音频
    app_data = guidata(fig);
    
    % 录音参数对话框
    prompt = {'录音时长 (秒):', '采样率 (Hz):'};
    dlgtitle = '录音设置';
    dims = [1, 35];
    definput = {'5', num2str(app_data.fs)};
    answer = inputdlg(prompt, dlgtitle, dims, definput);
    
    if isempty(answer)
        return;
    end
    
    duration = str2double(answer{1});
    fs = str2double(answer{2});
    
    if isnan(duration) || isnan(fs) || duration <= 0 || fs <= 0
        errordlg('请输入有效的参数', '参数错误');
        return;
    end
    
    update_status(fig, sprintf('开始录音 %d 秒...', duration));
    
    try
        % 录音
        x = record_audio(duration, fs);
        
        % 保存到应用程序数据
        app_data.original_signal = x;
        app_data.fs = fs;
        app_data.current_file = sprintf('recorded_%s.wav', datestr(now, 'HHMMSS'));
        app_data.is_processed = false;
        
        % 重置处理结果
        app_data.filtered_signal = [];
        app_data.pitch_shifted = [];
        app_data.time_stretched = [];
        
        guidata(fig, app_data);
        
        % 更新界面
        update_file_info(fig, '录音', length(x)/fs, fs);
        update_waveform_plot(fig);
        update_spectrum_plot(fig);
        update_status(fig, sprintf('录音完成: %.1f秒', length(x)/fs));
        
    catch ME
        update_status(fig, sprintf('录音失败: %s', ME.message));
        errordlg(sprintf('录音失败: %s', ME.message), '录音错误');
    end
end

function menu_apply_filter(fig, ~)
% 应用滤波器
    app_data = guidata(fig);
    
    if isempty(app_data.original_signal)
        errordlg('请先加载音频文件', '错误');
        return;
    end
    
    update_status(fig, '正在应用滤波器...');
    
    try
        % 获取滤波器参数
        fc_low = app_data.processing_params.fc_low;
        fc_high = app_data.processing_params.fc_high;
        filter_order = app_data.processing_params.filter_order;
        
        % 设计滤波器
        [b, a] = design_filter('bandpass', fc_low, fc_high, app_data.fs, filter_order);
        
        % 应用滤波器
        if isempty(app_data.filtered_signal)
            input_signal = app_data.original_signal;
        else
            input_signal = app_data.filtered_signal;
        end
        
        x_filtered = apply_filter(input_signal, b, a);
        
        % 保存结果
        app_data.filtered_signal = x_filtered;
        guidata(fig, app_data);
        
        % 更新图形
        update_filter_response_plot(fig, b, a);
        update_result_plot(fig);
        update_status(fig, '滤波器应用完成');
        
    catch ME
        update_status(fig, sprintf('滤波失败: %s', ME.message));
        errordlg(sprintf('滤波处理失败: %s', ME.message), '处理错误');
    end
end

function menu_pitch_shift(fig, ~)
% 变声处理
    app_data = guidata(fig);
    
    if isempty(app_data.original_signal)
        errordlg('请先加载音频文件', '错误');
        return;
    end
    
    update_status(fig, '正在进行变声处理...');
    
    try
        % 获取变声参数
        semitones = app_data.processing_params.semitones;
        formant_correction = app_data.processing_params.formant_correction;
        nfft = app_data.processing_params.nfft;
        
        % 选择输入信号
        if ~isempty(app_data.filtered_signal)
            input_signal = app_data.filtered_signal;
        else
            input_signal = app_data.original_signal;
        end
        
        % 应用变声
        y_pitch = pitch_shift(input_signal, semitones, app_data.fs, ...
                             'formant_correction', formant_correction, 'nfft', nfft);
        
        % 保存结果
        app_data.pitch_shifted = y_pitch;
        guidata(fig, app_data);
        
        % 更新图形
        update_result_plot(fig);
        update_status(fig, sprintf('变声完成: %.1f半音', semitones));
        
    catch ME
        update_status(fig, sprintf('变声失败: %s', ME.message));
        errordlg(sprintf('变声处理失败: %s', ME.message), '处理错误');
    end
end

function menu_time_stretch(fig, ~)
% 时间拉伸处理
    app_data = guidata(fig);
    
    if isempty(app_data.original_signal)
        errordlg('请先加载音频文件', '错误');
        return;
    end
    
    update_status(fig, '正在进行时间拉伸...');
    
    try
        % 获取时间拉伸参数
        time_ratio = app_data.processing_params.time_ratio;
        
        % 选择输入信号
        if ~isempty(app_data.pitch_shifted)
            input_signal = app_data.pitch_shifted;
        elseif ~isempty(app_data.filtered_signal)
            input_signal = app_data.filtered_signal;
        else
            input_signal = app_data.original_signal;
        end
        
        % 应用时间拉伸
        y_time = time_stretch(input_signal, time_ratio, app_data.fs);
        
        % 保存结果
        app_data.time_stretched = y_time;
        app_data.is_processed = true;
        guidata(fig, app_data);
        
        % 更新图形
        update_result_plot(fig);
        update_status(fig, sprintf('时间拉伸完成: %.2fx', time_ratio));
        
    catch ME
        update_status(fig, sprintf('时间拉伸失败: %s', ME.message));
        errordlg(sprintf('时间拉伸失败: %s', ME.message), '处理错误');
    end
end

function menu_process_all(fig, ~)
% 一键全部处理
    app_data = guidata(fig);
    
    if isempty(app_data.original_signal)
        errordlg('请先加载音频文件', '错误');
        return;
    end
    
    update_status(fig, '开始批量处理...');
    
    try
        % 依次应用所有处理
        menu_apply_filter(fig, []);
        menu_pitch_shift(fig, []);
        menu_time_stretch(fig, []);
        
        update_status(fig, '批量处理完成！');
        
    catch ME
        update_status(fig, sprintf('批量处理失败: %s', ME.message));
        errordlg(sprintf('批量处理失败: %s', ME.message), '处理错误');
    end
end

function menu_play_original(fig, ~)
% 播放原始音频
    app_data = guidata(fig);
    
    if isempty(app_data.original_signal)
        errordlg('没有可播放的音频', '错误');
        return;
    end
    
    update_status(fig, '播放原始音频...');
    sound(app_data.original_signal, app_data.fs);
    update_status(fig, '播放完成');
end

function menu_play_processed(fig, ~)
% 播放处理后的音频
    app_data = guidata(fig);
    
    if isempty(app_data.time_stretched) && isempty(app_data.pitch_shifted)
        errordlg('请先进行音频处理', '错误');
        return;
    end
    
    update_status(fig, '播放处理结果...');
    
    % 播放最终结果
    if ~isempty(app_data.time_stretched)
        sound(app_data.time_stretched, app_data.fs);
    elseif ~isempty(app_data.pitch_shifted)
        sound(app_data.pitch_shifted, app_data.fs);
    else
        sound(app_data.filtered_signal, app_data.fs);
    end
    
    update_status(fig, '播放完成');
end

function menu_play_comparison(fig, ~)
% 对比播放
    app_data = guidata(fig);
    
    if isempty(app_data.original_signal)
        errordlg('没有可播放的音频', '错误');
        return;
    end
    
    update_status(fig, '开始对比播放...');
    
    % 播放原始音频
    sound(app_data.original_signal, app_data.fs);
    pause(length(app_data.original_signal)/app_data.fs + 1);
    
    % 播放处理结果
    if ~isempty(app_data.time_stretched)
        sound(app_data.time_stretched, app_data.fs);
    elseif ~isempty(app_data.pitch_shifted)
        sound(app_data.pitch_shifted, app_data.fs);
    elseif ~isempty(app_data.filtered_signal)
        sound(app_data.filtered_signal, app_data.fs);
    end
    
    update_status(fig, '对比播放完成');
end

function menu_save_result(fig, ~)
% 保存处理结果
    app_data = guidata(fig);
    
    if isempty(app_data.time_stretched) && isempty(app_data.pitch_shifted)
        errordlg('没有处理结果可保存', '错误');
        return;
    end
    
    [filename, pathname] = uiputfile('*.wav', '保存处理结果', 'processed_audio.wav');
    if filename == 0
        return;
    end
    
    filepath = fullfile(pathname, filename);
    
    try
        % 保存最终结果
        if ~isempty(app_data.time_stretched)
            audiowrite(filepath, app_data.time_stretched, app_data.fs);
        else
            audiowrite(filepath, app_data.pitch_shifted, app_data.fs);
        end
        
        update_status(fig, sprintf('结果已保存: %s', filename));
        msgbox(sprintf('处理结果已保存为: %s', filename), '保存成功');
        
    catch ME
        update_status(fig, sprintf('保存失败: %s', ME.message));
        errordlg(sprintf('保存失败: %s', ME.message), '保存错误');
    end
end