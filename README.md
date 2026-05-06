# 2025-VoiceDisguise-matlab

华中科技大学 光学与电子信息学院 信号与系统课程作业：MATLAB 语音伪装器/变声器，覆盖录音读入、频谱分析、数字滤波降噪、变调、共振峰校正与时间尺度修改，并提供可视化 GUI。

## 仓库描述

华中科技大学 光学与电子信息学院 信号与系统课程作业：MATLAB 语音伪装器，基于 Phase Vocoder 实现变调变速与共振峰校正，含 GUI、分析与测试脚本。

## 功能概览

- 输入：录音或读取音频文件，支持 wav、mp3、m4a 格式
- 分析：时域波形、幅度谱/相位谱、时频谱
- 预处理：带通滤波及滤波器频响可视化
- 变声：基于相位声码器的变调，以半音为单位精确控制
- 音色保持：共振峰校正，支持 LPC 和倒谱域两种方法
- 变速：时间拉伸与压缩，支持慢录快放和快录慢放
- 输出：播放对比与导出处理后的音频文件

## 效果预览

![语音伪装器 GUI 界面截图](essay/image.png)

## 运行环境

- MATLAB R2021b 及以上版本，作者环境为 R2024b
- 推荐安装 Audio Toolbox 以确保音频处理与播放流程稳定
- 支持 Windows、macOS、Linux 操作系统

## 快速开始

将 MATLAB 当前工作目录切换到仓库根目录，运行入口脚本。

### GUI 方式

```matlab
main_gui
```

GUI 支持打开文件/录音、频谱分析、滤波、变声、时间拉伸、对比播放与可视化。

入口文件：[main_gui.m](main_gui.m)

### 命令行方式

```matlab
main
```

按提示选择输入方式并输入参数：
- 变调半音数：正数升调使声音更尖，负数降调使声音更沉
- 时间拉伸比例：大于 1 变慢，小于 1 变快

入口文件：[main.m](main.m)

## 工程结构

- [core/](core) 变调、相位声码器、共振峰校正等核心算法
- [effects/](effects) 时间拉伸、降噪、实时效果封装
- [filters/](filters) 滤波器设计、应用与频响绘图
- [analysis/](analysis) 频谱与时域绘图分析工具
- [io/](io) 录音、读写与播放
- [realtime/](realtime) 实时处理的类与实验性代码
- [test/](test) 指标评估与对比实验脚本
- [essay/](essay) 报告模板、参考文献与写作素材
- [show/](show) 课堂演示脚本

## 常用脚本索引

- GUI：[main_gui.m](main_gui.m)
- 命令行主流程：[main.m](main.m)
- 变调对外主函数：[pitch_shift.m](core/pitch_shift.m)
- 相位声码器：[pvoc.m](core/pvoc.m)
- 时间拉伸：[time_stretch.m](effects/time_stretch.m)
- 读音频与录音：[read_audio.m](io/read_audio.m)、[record_audio.m](io/record_audio.m)

## 输出文件

运行后可能在根目录生成或覆盖以下文件：
- `processed_audio.wav`：默认导出的处理结果
- `result_*.wav`、`test_*.wav`：各实验与对比脚本的输出

## 检索关键词

华中科技大学、光学与电子信息学院、信号与系统、课程设计、MATLAB、语音伪装器、变声器、Phase Vocoder、相位声码器、Pitch Shift、Time Stretch、共振峰校正、Formant、LPC、倒谱、Cepstrum、滤波器设计、频谱分析、时频谱、GUI

## 版权

见 [LICENSE.md](LICENSE.md)。
