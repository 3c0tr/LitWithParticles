[English](Readme.md)

# Lit With Particles😢

**Lit With Particles** 是一个基于 **Godot 4.4** 构建的独特实验性 2D 光照系统。

与传统的射线投射或基于 SDF 的 2D 光照不同，本项目通过模拟从光源直接发射的**光子（粒子）**来计算亮度。它大量使用了 **Compute Shaders（计算着色器）**，以实现光线传播、反射、折射甚至流体动力学的高性能实时模拟。

## ✨ 主要特性

- **基于粒子的光照**：在 GPU 上使用海量粒子系统模拟光线行为。
- **高级材质系统**：
  - 支持多种物理属性：**粗糙度、折射率 (IOR)、散射率、透明度、金属度**。
  - 预设材质：陶瓷、玻璃、毛玻璃、镜面、黑体等。
  - 支持自定义定向发射器（发射角度/范围）。
- **流体模拟**：集成了与光照交互的实时流体动力学（基于 Navier-Stokes）。
- **高性能**：完全由 Godot 的 `RenderingDevice` API 和 Compute Shaders 驱动。

## 🎮 操作指南

| 输入 | 动作 |
| :--- | :--- |
| **鼠标左键** | 绘制材质 / 发射光线 |
| **鼠标右键** | 擦除 / 清除 |
| **Ctrl + 拖动** | 绘制直线 |
| **Alt + 绘制** | 流体交互 / 绘制流体 |
| **按住 X** | 锁定鼠标在 X 轴移动 |
| **按住 Y** | 锁定鼠标在 Y 轴移动 |
| **按 Q 键** | 切换笔刷形状（圆形/方形） |

## 🛠️ 技术栈

- **引擎**: Godot 4.4
- **语言**: GDScript & GLSL (Compute Shaders)
- **渲染**: Vulkan (via Godot RD API)

<p align="center">
  <img src="./images/colors.png" alt="preview">
</p>

<p align="center">
  <img src="./images/obstacle.png" alt="preview">
</p>

<p align="center">
  <img src="./images/light.png" alt="preview">
</p>