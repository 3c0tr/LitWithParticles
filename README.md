[中文](Readme_CN.md)

# Lit With Particles😢

**Lit With Particles** is a unique experimental 2D lighting system built with **Godot 4.4**.

Unlike traditional ray-casting or SDF-based 2D lighting, this project evaluates brightness by simulating **photons (particles)** emitted directly from light sources. It leverages **Compute Shaders** heavily to achieve high-performance, real-time simulation of light propagation, reflection, refraction, and even fluid dynamics.

## ✨ Key Features

- **Particle-Based Lighting**: Simulates light behavior using massive particle systems on the GPU.
- **Advanced Material System**:
  - Support for various physical properties: **Roughness, IOR, Scatter Rate, Opacity, Metallic**.
  - Preset materials: Ceramic, Glass, Frosted Glass, Mirror, Black Body, etc.
  - Custom emitters with directional control (Emit Angle/Range).
- **Fluid Simulation**: Integrated real-time fluid dynamics (Navier-Stokes based) interacting with the lighting.
- **High Performance**: Fully powered by Godot's `RenderingDevice` API and Compute Shaders.

## 🎮 Controls

| Input | Action |
| :--- | :--- |
| **Left Mouse** | Draw Material / Emit Light |
| **Right Mouse** | Erase / Clear |
| **Ctrl + Drag** | Draw Straight Lines |
| **Alt + Draw** | Interact with Fluid / Draw Fluid |
| **Hold X** | Lock Mouse Movement to X-Axis |
| **Hold Y** | Lock Mouse Movement to Y-Axis |
| **Press Q** | Toggle Brush Shape (Circle / Square) |

## 🛠️ Technology Stack

- **Engine**: Godot 4.4
- **Language**: GDScript & GLSL (Compute Shaders)
- **Rendering**: Vulkan (via Godot RD API)
  
<p align="center">
  <img src="./images/colors.png" alt="preview">
</p>

<p align="center">
  <img src="./images/fluid_supported.png" alt="preview">
</p>

<p align="center">
  <img src="./images/mirror_room.png" alt="preview">
</p>
