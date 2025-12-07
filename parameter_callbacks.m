% 参数更新回调函数

function update_filter_params(src, ~)
% 更新滤波器参数
    fig = ancestor(src, 'figure');
    app_data = guidata(fig);
    
    try
        fc_low_edit = findobj(fig, 'Tag', 'fc_low_edit');
        fc_high_edit = findobj(fig, 'Tag', 'fc_high_edit');
        order_edit = findobj(fig, 'Tag', 'filter_order_edit');
        
        app_data.processing_params.fc_low = str2double(get(fc_low_edit, 'String'));
        app_data.processing_params.fc_high = str2double(get(fc_high_edit, 'String'));
        app_data.processing_params.filter_order = str2double(get(order_edit, 'String'));
        
        guidata(fig, app_data);
        
    catch
        % 参数无效，忽略
    end
end

function update_pitch_params(src, ~)
% 更新变声参数
    fig = ancestor(src, 'figure');
    app_data = guidata(fig);
    
    try
        semitones_slider = findobj(fig, 'Tag', 'semitones_slider');
        semitones_text = findobj(fig, 'Tag', 'semitones_text');
        formant_check = findobj(fig, 'Tag', 'formant_correction_check');
        
        semitones = round(get(semitones_slider, 'Value'));
        set(semitones_text, 'String', sprintf('%d 半音', semitones));
        
        app_data.processing_params.semitones = semitones;
        app_data.processing_params.formant_correction = get(formant_check, 'Value');
        
        guidata(fig, app_data);
        
    catch
        % 参数无效，忽略
    end
end

function update_time_params(src, ~)
% 更新时间拉伸参数
    fig = ancestor(src, 'figure');
    app_data = guidata(fig);
    
    try
        time_slider = findobj(fig, 'Tag', 'time_ratio_slider');
        time_text = findobj(fig, 'Tag', 'time_ratio_text');
        
        time_ratio = get(time_slider, 'Value');
        set(time_text, 'String', sprintf('%.2fx', time_ratio));
        
        app_data.processing_params.time_ratio = time_ratio;
        
        guidata(fig, app_data);
        
    catch
        % 参数无效，忽略
    end
end