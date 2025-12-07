classdef EffectChain < handle
    % 效果器链管理 - 支持实时参数调节
    
    properties
        Effects
        SampleRate
        BufferSize
    end
    
    methods
        function obj = EffectChain(fs, bufferSize)
            obj.SampleRate = fs;
            obj.BufferSize = bufferSize;
            obj.Effects = {};
        end
        
        function addPitchShift(obj, semitones, formantCorrection)
            % 添加实时变调效果器
            effect = struct();
            effect.Type = 'pitch_shift';
            effect.Semitones = semitones;
            effect.FormantCorrection = formantCorrection;
            effect.Enabled = true;
            
            obj.Effects{end+1} = effect;
        end
        
        function addTimeStretch(obj, ratio)
            % 添加实时时间拉伸
            effect = struct();
            effect.Type = 'time_stretch';
            effect.Ratio = ratio;
            effect.Enabled = true;
            
            obj.Effects{end+1} = effect;
        end
        
        function addFilter(obj, filterType, frequencies)
            % 添加实时滤波器
            effect = struct();
            effect.Type = 'filter';
            effect.FilterType = filterType;
            effect.Frequencies = frequencies;
            effect.Enabled = true;
            
            obj.Effects{end+1} = effect;
        end
        
        function output = process(obj, input)
            % 处理音频（实时优化版本）
            output = input;
            
            for i = 1:length(obj.Effects)
                if obj.Effects{i}.Enabled
                    output = obj.applySingleEffect(output, obj.Effects{i});
                end
            end
        end
        
        function output = applySingleEffect(obj, input, effect)
            % 应用单个效果器（实时优化）
            switch effect.Type
                case 'pitch_shift'
                    % 实时变调（使用优化的相位声码器）
                    output = realtime_pitch_shift(input, ...
                        effect.Semitones, obj.SampleRate, ...
                        'formant_correction', effect.FormantCorrection);
                    
                case 'time_stretch'
                    % 实时时间拉伸
                    output = realtime_time_stretch(input, ...
                        effect.Ratio, obj.SampleRate);
                    
                case 'filter'
                    % 实时滤波（使用FIR滤波器避免相位问题）
                    output = realtime_filter(input, ...
                        effect.FilterType, effect.Frequencies, obj.SampleRate);
                    
                otherwise
                    output = input;
            end
        end
        
        function setEffectParameter(obj, effectIndex, paramName, value)
            % 设置效果器参数
            if effectIndex <= length(obj.Effects)
                obj.Effects{effectIndex}.(paramName) = value;
            end
        end
    end
end