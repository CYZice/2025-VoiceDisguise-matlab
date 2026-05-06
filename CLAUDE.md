# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MATLAB 语音伪装器/变声器 — 信号与系统课程作业。基于 Phase Vocoder 实现变调不变速、共振峰校正和时间拉伸，提供 GUI 和命令行两种交互方式。

## Running

```matlab
% GUI (推荐)
main_gui

% 命令行交互式流程
main
```

运行前需将 MATLAB 工作目录切换到仓库根目录。需要 MATLAB R2021b+ (作者环境 R2024b)，推荐安装 Audio Toolbox。

## Architecture

### Data Flow Pipeline

```
输入 (录音/文件) → 带通滤波 → 变调(Pitch Shift) → 共振峰校正 → 时间拉伸 → 输出/播放
```

信号在 GUI 中以 `guidata` 结构体 `app_data` 流转，按优先级链选择输入：`time_stretched` → `pitch_shifted` → `filtered_signal` → `original_signal`。

### Core Algorithm (`core/`)

变调链路基于 **Dan Ellis 的 Phase Vocoder** (`pvoc.m`, `pvsample.m`, `my_stft.m`, `my_istft.m` — 来自 Columbia EE dept)：

1. `pitch_shift.m` — 对外主入口。升调：PVOC 时间拉伸 → `resample` 压缩采样率升调。降调：PVOC 时间压缩 → `resample` 扩张采样率降调。最终调用 `formant_correction`。
2. `pvoc.m` → `my_stft` (25% overlap Hann window) → `pvsample` (相位插值，保持水平相位连续性) → `my_istft` (overlap-add 重建)
3. `resample_pitch.m` — 用 `rat()` 有理逼近 + Kaiser 窗 `resample()` 做高质量重采样

**共振峰校正** (`formant_correction.m`) 支持三种方法：
- `lpc` — 分帧 LPC 分析，缩放极点角度改变共振峰，再 LPC 合成
- `cepstral` — 迭代倒谱域频谱包络估计：DFT → 对数功率谱 → IFFT 得倒谱 → 低通 lifter → 包络估计（迭代至收敛）→ 对比原信号包络进行频率轴缩放 → 校正目标信号频谱
- `spectral_tilt` — 简单 Butterworth 频谱倾斜滤波

### Module Map

| 目录 | 职责 |
|------|------|
| `core/` | Phase Vocoder、变调、共振峰校正 — 核心算法 |
| `effects/` | `time_stretch.m` (对 PVOC 的薄封装)、`noise_reduction.m` (谱减法/维纳滤波)、`realtime_effects.m` |
| `filters/` | Butterworth 滤波器设计 (`design_filter.m`)、应用 (`apply_filter.m`)、频响绘图 |
| `analysis/` | 频谱分析 (`spectrum_analysis.m`)、相位谱、时域/频域对比绘图 |
| `io/` | `read_audio.m` (支持 wav/mp3/m4a)、`record_audio.m`、`play_audio.m` |
| `realtime/` | `EffectChain` 类 (效果器链)、`RealTimeVoiceProcessor` — 实验性实时处理 |
| `test/` | 指标评估、共振峰校正对比测试 (`test.m` 用 MATLAB 内置 `mtlb` 音频) |
| `show/` | 课堂演示脚本 (与 `essay/code/` 内容镜像) |
| `essay/` | 报告模板、参考文献、示例代码 |

### GUI Structure

`main_gui.m` 是单一巨型文件 (~1350 行)，包含所有回调函数和 UI 创建逻辑。分为四个区域：
- 文件操作 (打开/录音)
- 滤波器设置 (低/高频截止、阶数)
- 变声设置 (半音滑块 -12~+12、共振峰校正开关)
- 时间拉伸 (比例 0.5x~2.0x)

可视化面板：2×2 子图布局 (波形、频谱、时频谱、结果统计)。`gui_callbacks.m`、`gui_utils.m`、`parameter_callbacks.m` 是分离出的辅助 GUI 函数文件。

### Key Parameters

- 默认采样率: 44100 Hz
- 默认带通滤波: 100–3500 Hz, 4 阶 Butterworth
- 变调范围: -12 到 +12 半音
- 时间拉伸: 0.5x (快) ~ 2.0x (慢)
- STFT: NFFT=1024, 25% overlap Hann window
- 倒谱阶数: `round(fs/1000)` (~44 at 44.1kHz), 对应 ~1ms 倒频率

## Testing

```matlab
% 共振峰校正对比测试 (使用内置 mtlb 音频)
test
```

测试文件将打开图表窗口，运行三种共振峰校正方法的对比。

## Notes

- 所有 `.m` 函数文件通过 `addpath` 加载子目录，不依赖 MATLAB 项目文件
- GUI 使用 `guidata`/`guidata` 传递状态，组件通过 `Tag` 属性查找
- `pvoc` 系列（STFT/ISTFT/pvsample）是 Dan Ellis 2000–2011 年的原始实现，非本项目原创
- 音频输出文件（`processed_audio.wav`、`result_*.wav`）生成在仓库根目录
