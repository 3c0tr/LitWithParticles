#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform image2D input_texture;
layout(set = 0, binding = 1, rgba32f) uniform image2D output_texture;
layout(set = 0, binding = 2, r8ui) uniform uimage2D QuickSampleObstacle_texture_rd;
layout(set = 0, binding = 3, std430) buffer Brightness_Diffuse_buffer {
    float read_back_data[4];
};

// Use shared memory to cache a tile of the input texture.
// Workgroup size is 8x8, kernel is 3x3, so we need a halo of 1 pixel.
// Shared memory tile size = (8 + 2) x (8 + 2) = 10x10.
#define TILE_WIDTH 10
#define WORKGROUP_DIM 8
shared vec4 shared_tile[TILE_WIDTH * TILE_WIDTH];

// The code we want to execute in each invocation
void main() {
    ivec2 global_coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 local_coord = ivec2(gl_LocalInvocationID.xy);
    ivec2 texture_size = imageSize(input_texture);

    // Calculate the top-left corner of the tile to load.
    ivec2 tile_origin = ivec2(gl_WorkGroupID.xy * gl_WorkGroupSize.xy) - ivec2(1, 1);

    // Each thread loads a portion of the texture into shared memory.
    // 64 threads (8x8) load a 10x10 tile (100 pixels).
    uint flat_local_id = gl_LocalInvocationIndex; // Same as local_coord.y * 8 + local_coord.x

    for (uint i = flat_local_id; i < TILE_WIDTH * TILE_WIDTH; i += (WORKGROUP_DIM * WORKGROUP_DIM)) {
        ivec2 load_coord_in_tile = ivec2(i % TILE_WIDTH, i / TILE_WIDTH);
        ivec2 load_coord_global = tile_origin + load_coord_in_tile;

        // Clamp coordinates to avoid reading out of bounds. The calculation logic
        // will handle the boundary conditions correctly, so this just prevents hardware errors.
        vec4 pixel = imageLoad(input_texture, clamp(load_coord_global, ivec2(0), texture_size - 1));
        
        shared_tile[load_coord_in_tile.y * TILE_WIDTH + load_coord_in_tile.x] = pixel;
    }

    // Synchronize to ensure all threads have finished loading into shared memory.
    barrier();

    // Main thread execution: boundary check before writing.
    if (global_coord.x >= texture_size.x || global_coord.y >= texture_size.y) {
        return;
    }

    // The local coordinate corresponds to the center of the 3x3 kernel in the shared tile.
    // The tile has a 1-pixel border, so the center pixel for this thread is at local_coord + 1.
    ivec2 shared_center_coord = local_coord + ivec2(1, 1);
    vec4 center_color = shared_tile[shared_center_coord.y * TILE_WIDTH + shared_center_coord.x];
    
    // Define the 8 neighbor offsets.
    ivec2 offsets[8] = ivec2[](
        ivec2(-1, -1), ivec2(0, -1), ivec2(1, -1),
        ivec2(-1,  0),               ivec2(1,  0),
        ivec2(-1,  1), ivec2(0,  1), ivec2(1,  1)
    );
    
    // Accumulate valid neighboring pixels from shared memory.
    vec4 accumulated_color = vec4(0.0);
    int valid_samples = 0;
    
    for (int i = 0; i < 8; i++) {
        ivec2 sample_coord_global = global_coord + offsets[i];
        
        // Check if the original sample coordinate was within texture bounds.
        if (sample_coord_global.x >= 0 && sample_coord_global.x < texture_size.x && 
            sample_coord_global.y >= 0 && sample_coord_global.y < texture_size.y) {
            
            // If valid, read the pre-fetched value from shared memory.
            ivec2 sample_coord_in_tile = shared_center_coord + offsets[i];
            accumulated_color += shared_tile[sample_coord_in_tile.y * TILE_WIDTH + sample_coord_in_tile.x];
            valid_samples++;
        }
    }
    
    // Calculate the blurred color, preserving energy.
    vec4 blurred_color;
    if (valid_samples > 0) {
        // 使用加权平均：中心像素权重为1，周围像素总权重为1
        // 这样确保总权重为2，然后除以2来保持能量守恒
        float center_weight = 1.0;
        float neighbor_weight = 1.0 / float(valid_samples);
        
        blurred_color = (center_color * center_weight + accumulated_color * neighbor_weight) / 2.0;
    } else {
        // 如果没有有效的邻居像素（边界情况），保持原色
        blurred_color = center_color;
    }
    
    // 定义模糊强度，0.0为原图，1.0为完全模糊
    float blur_strength = 1.0;
    
    // 根据模糊强度混合原图和模糊后的颜色
    vec4 final_color = mix(center_color, blurred_color, blur_strength);

    if (read_back_data[0] > 0.1)
    {
        // 反馈算法：基于最终输出亮度计算抑制写入级别
        // 我们需要逆向映射ToneMapping：mapped = 2 * L / (L + 1) => L = mapped / (2 - mapped)
        vec3 c = final_color.rgb;
        float mapped_lum = max(c.r, max(c.g, c.b));
        // 防止除零，并限制最大值略小于2.0以避免L爆炸（因为ToneMapping极限是2.0）
        float safe_mapped = min(mapped_lum, 1.999); 
        float true_lum = safe_mapped / (2.0 - safe_mapped);

        // 目标亮度和增益参数
        // target_lum: 希望将亮度控制在什么数值附近
        // feedback_gain: 对过曝的敏感程度，值越大，抑制等级提升越快
        float target_lum = 1.0;
        float feedback_gain = 12.0;

        uint suppression_level = 0;
        if (true_lum > target_lum) {
            suppression_level = clamp(uint((true_lum - target_lum) * feedback_gain), 0u, 15u);
        }
        // suppression_level = 0u;

        // 读取并更新障碍物纹理，使用第5-8位 (Mask 0xF0)
        uint obs_data = imageLoad(QuickSampleObstacle_texture_rd, global_coord).r;
        obs_data = (obs_data & ~0xF0u) | (suppression_level << 4);
        imageStore(QuickSampleObstacle_texture_rd, global_coord, uvec4(obs_data, 0, 0, 0));
    }
    
    // 写入模糊后的颜色
    imageStore(output_texture, global_coord, vec4(final_color.rgb, 1.0));
}