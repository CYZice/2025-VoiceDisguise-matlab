classdef RealTimeVoiceProcessor < handle
    % 实时语音处理器 - 直接调用现有高质量函数
    
    properties
        SampleRate
        FrameSize
        HopSize
        BufferSize
        % 效果参数
        PitchSemitones
        TimeRatio
        % 缓冲区
        InputBuffer
        OutputBuffer
        ProcessedBuffer
        % 状态变量
        IsProcessing
        ProcessingDelay
        FrameCounter
    end
    
    methods
        function obj = RealTimeVoiceProcessor(fs, frameSize, hopSize)
            % 构造函数
            obj.SampleRate = fs;
            obj.FrameSize = frameSize;
            obj.HopSize = hopSize;
            obj.BufferSize = frameSize * 8; % 8帧缓冲区
            
            % 初始化缓冲区
            obj.InputBuffer = zeros(obj.BufferSize, 1);
            obj.OutputBuffer = zeros(obj.BufferSize, 1);
            obj.ProcessedBuffer = zeros(obj.BufferSize, 1);
            
            % 初始化状态
            obj.IsProcessing = false;
            obj.ProcessingDelay = 0;
            obj.FrameCounter = 0;
            
            fprintf('实时处理器初始化: 帧大小=%d, 跳跃=%d, 采样率=%dHz\n', ...
                frameSize, hopSize, fs);
        end
        
        function setEffects(obj, pitchSemitones, timeRatio)
            % 设置效果参数
            obj.PitchSemitones = pitchSemitones;
            obj.TimeRatio = timeRatio;
            fprintf('效果设置: 变调=%.1f半音, 变速=%.2fx\n', pitchSemitones, timeRatio);
        end
        
        function startProcessing(obj)
            % 开始处理
            obj.IsProcessing = true;
            obj.FrameCounter = 0;
            fprintf('开始实时处理\n');
        end
        
        function stopProcessing(obj)
            % 停止处理
            obj.IsProcessing = false;
            fprintf('停止实时处理\n');
        end
        
        function outputFrame = processFrame(obj, inputFrame)
            % 处理单帧输入，返回输出帧
            if ~obj.IsProcessing
                outputFrame = inputFrame;
                return;
            end
            
            obj.FrameCounter = obj.FrameCounter + 1;
            
            % 1. 更新输入缓冲区
            obj.updateInputBuffer(inputFrame);
            
            % 2. 检查是否有足够数据进行处理
            if obj.hasEnoughDataForProcessing()
                % 3. 处理缓冲区中的数据
                processedData = obj.processBuffer();
                
                % 4. 更新输出缓冲区
                obj.updateOutputBuffer(processedData);
            end
            
            % 5. 从输出缓冲区取出一帧
            outputFrame = obj.getOutputFrame();
            
            % 6. 显示处理状态（每10帧）
            if mod(obj.FrameCounter, 10) == 0
                obj.displayProcessingStatus();
            end
        end
        
        function updateInputBuffer(obj, inputFrame)
            % 更新输入缓冲区（FIFO）
            obj.InputBuffer = [obj.InputBuffer(obj.FrameSize+1:end); inputFrame];
        end
        
        function hasEnough = hasEnoughDataForProcessing(obj)
            % 检查是否有足够数据用于处理
            % 需要至少2倍帧大小来保证处理质量
            minRequired = obj.FrameSize * 2;
            hasEnough = length(obj.InputBuffer) >= minRequired;
        end
        
        function processedData = processBuffer(obj)
            % 处理缓冲区中的数据（调用现有高质量函数）
            
            % 取足够的数据进行处理（避免边界效应）
            processSize = min(length(obj.InputBuffer), obj.FrameSize * 4);
            inputData = obj.InputBuffer(1:processSize);
            
            fprintf('处理帧 %d: 处理 %d 采样点\n', obj.FrameCounter, processSize);
            
            % 应用效果器链
            processedData = inputData;
            
            % 1. 先变调
            if obj.PitchSemitones ~= 0
                tic;
                processedData = pitch_shift(processedData, obj.PitchSemitones, ...
                    obj.SampleRate, 'formant_correction', true, 'nfft', 1024);
                pitch_time = toc * 1000;
                fprintf('  变调处理: %.1fms\n', pitch_time);
            end
            
            % 2. 再变速
            if obj.TimeRatio ~= 1
                tic;
                processedData = time_stretch(processedData, obj.TimeRatio, obj.SampleRate);
                time_time = toc * 1000;
                fprintf('  变速处理: %.1fms\n', time_time);
            end
            
            % 3. 调整长度匹配
            if length(processedData) > processSize
                processedData = processedData(1:processSize);
            elseif length(processedData) < processSize
                processedData = [processedData; zeros(processSize - length(processedData), 1)];
            end
        end
        
        function updateOutputBuffer(obj, processedData)
            % 更新输出缓冲区
            obj.OutputBuffer = [obj.OutputBuffer; processedData];
        end
        
        function outputFrame = getOutputFrame(obj)
            % 从输出缓冲区取出一帧
            if length(obj.OutputBuffer) >= obj.FrameSize
                outputFrame = obj.OutputBuffer(1:obj.FrameSize);
                obj.OutputBuffer = obj.OutputBuffer(obj.FrameSize+1:end);
            else
                % 输出缓冲区不足，返回零帧
                outputFrame = zeros(obj.FrameSize, 1);
            end
        end
        
        function displayProcessingStatus(obj)
            % 显示处理状态
            input_buffer_usage = length(obj.InputBuffer) / obj.BufferSize * 100;
            output_buffer_usage = length(obj.OutputBuffer) / obj.BufferSize * 100;
            
            fprintf('状态: 输入缓冲%.1f%%, 输出缓冲%.1f%%, 帧计数%d\n', ...
                input_buffer_usage, output_buffer_usage, obj.FrameCounter);
        end
        
        function latency = getCurrentLatency(obj)
            % 获取当前处理延迟（毫秒）
            latency = (length(obj.InputBuffer) + length(obj.OutputBuffer)) / obj.SampleRate * 1000;
        end
    end
end