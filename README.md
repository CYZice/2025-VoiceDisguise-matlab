# 2025-VoiceDisguise-matlab

MATLAB 语音伪装器/变声器（信号与系统/语音信号处理课程作业参考）：覆盖录音/读入、频谱分析、数字滤波降噪、变调（Pitch Shift）、共振峰校正（Formant Correction）与时间尺度修改（Time Stretch），并提供可视化 GUI。

## 仓库描述（用于 GitHub About/Description）

信号与系统课程作业：MATLAB 语音伪装器（Phase Vocoder 变调/变速 + 共振峰校正），含 GUI、分析与测试脚本。

## 功能概览

- 输入：录音或读取音频文件（wav/mp3/m4a）
- 分析：时域波形、幅度谱/相位谱、时频谱（spectrogram）
- 预处理：带通滤波/滤波器频响可视化
- 变声：基于相位声码器（Phase Vocoder）的变调（半音控制）
- 音色保持：共振峰校正（支持倒谱/包络相关方法，见 core/）
- 变速：时间拉伸/压缩（慢录快放、快录慢放）
- 输出：播放对比与导出处理后的音频文件

## 效果预览

![附件截图 1](essay/image.png)

## 运行环境

- MATLAB（建议 R2021b+；作者报告环境为 R2024b）
- 推荐安装：Audio Toolbox（涉及部分音频处理/播放流程时更稳妥）
- 操作系统：Windows/macOS/Linux 均可（以 MATLAB 支持为准）

## 快速开始

把 MATLAB 当前工作目录切到仓库根目录（本 README 所在目录），再运行入口脚本。

### 方式 1：GUI（推荐）

```matlab
main_gui
```

GUI 支持：打开文件/录音、频谱分析、滤波、变声、时间拉伸、对比播放与可视化。

入口文件：[main_gui.m](main_gui.m)

### 方式 2：命令行流程（交互式）

```matlab
main
```

按提示选择输入方式并输入参数：
- 变调半音数：正数升调（更“尖”），负数降调（更“沉”）
- 时间拉伸比例：>1 变慢，<1 变快

入口文件：[main.m](main.m)

## 工程结构

- [core/](core) 变调、相位声码器、共振峰校正等核心算法
- [effects/](effects) 时间拉伸、降噪、实时效果封装
- [filters/](filters) 滤波器设计/应用/频响绘图
- [analysis/](analysis) 频谱/时域绘图与分析工具
- [io/](io) 录音/读写/播放相关
- [realtime/](realtime) 实时处理的类与实验性代码
- [test/](test) 指标评估与对比实验脚本
- [essay/](essay) 报告模板、参考文献与写作素材
- [show/](show) 演示/重复脚本（便于课堂展示）

## 常用脚本索引

- GUI： [main_gui.m](main_gui.m)
- 命令行主流程： [main.m](main.m)
- 变调（对外主函数）： [pitch_shift.m](core/pitch_shift.m)
- 相位声码器： [pvoc.m](core/pvoc.m)
- 时间拉伸： [time_stretch.m](effects/time_stretch.m)
- 读音频/录音： [read_audio.m](io/read_audio.m)、[record_audio.m](io/record_audio.m)

## 输出文件

运行后可能在根目录生成/覆盖：
- processed_audio.wav：默认导出的处理结果（见 [main.m](main.m)）
- 以及若干 result_*.wav、test_*.wav：不同实验/对比脚本的输出

## 检索关键词

信号与系统、课程设计、MATLAB、语音伪装器、变声器、Phase Vocoder、相位声码器、Pitch Shift、Time Stretch、共振峰校正、Formant、LPC、倒谱（Cepstrum）、滤波器设计、频谱分析、时频谱、GUI

## 版权

见 [LICENSE.md](LICENSE.md)。
