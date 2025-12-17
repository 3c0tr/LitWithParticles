#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform image2D Obstacle_texture;
layout(set = 0, binding = 1, r8ui) uniform uimage2D QuickSampleObstacle_texture;
layout(set = 0, binding = 2, rgba32f) uniform image2D Velocity_texture[2];
layout(set = 0, binding = 3, rgba32f) uniform image2D Color_texture[2];

// 添加存储缓冲区来接收笔刷数据
layout(set = 0, binding = 4, std430) restrict readonly buffer BrushData {
    vec4 brush_color;      // 笔刷颜色 RGB + 预留Alpha
    vec2 brush_position_1; // 当前帧鼠标位置 (归一化坐标 0-1)
    vec2 brush_position_2; // 上一帧鼠标位置 (归一化坐标 0-1)
    vec2 brush_position_3; // 上上帧鼠标位置 (归一化坐标 0-1)
    float brush_size;      // 笔刷大小
    int draw_witch;        // 绘制哪张纹理？
    vec4 packed_material_data; // 材质数据（打包后的128位浮点数）
    vec2 direction;            // 绘制方向
    int UpdateCounter;         // 更新计数器
    int brush_shape;           // 笔刷形状
    int normal_mode;           // 法线模式 0 反转法线 2 辐射模式 4 自定义法线
    float custom_normal;        // 自定义法线角度
    vec2 portal_distance;      // 传送门距离
};

void store_uint_as_float(ivec2 pixel_coord, uvec4 data) {
    vec4 float_data = vec4(
        uintBitsToFloat(data.x),
        uintBitsToFloat(data.y),
        uintBitsToFloat(data.z),
        uintBitsToFloat(data.w)
    );
    imageStore(Obstacle_texture, pixel_coord, float_data);
}

void encode_value(float value, uint position, inout uint encoded_data) 
{
    uint int_value = uint(clamp(value, 0.0, 1.0) * 255.0);
    uint shift = position * 8;
    uint mask = ~(0xFFu << shift);
    encoded_data &= mask;
    encoded_data |= (int_value << shift);
}

// 计算点到线段的符号距离场（支持宽高比校正）
float getLInfinityDistAndT(vec2 pa, vec2 ba, out float t_out) {
    float t_best = 0.0;
    float dist_best = max(abs(pa.x), abs(pa.y)); // t=0
    
    // t=1
    vec2 d1 = pa - ba;
    float dist_1 = max(abs(d1.x), abs(d1.y));
    if (dist_1 < dist_best) {
        dist_best = dist_1;
        t_best = 1.0;
    }
    
    // Intersection 1: pa.x - t*ba.x = pa.y - t*ba.y
    if (abs(ba.y - ba.x) > 1e-5) {
        float t = (pa.y - pa.x) / (ba.y - ba.x);
        if (t > 0.0 && t < 1.0) {
            vec2 d = pa - ba * t;
            float dist = max(abs(d.x), abs(d.y));
            if (dist < dist_best) {
                dist_best = dist;
                t_best = t;
            }
        }
    }
    
    // Intersection 2: pa.x - t*ba.x = -(pa.y - t*ba.y)
    if (abs(ba.y + ba.x) > 1e-5) {
        float t = (pa.x + pa.y) / (ba.x + ba.y);
        if (t > 0.0 && t < 1.0) {
            vec2 d = pa - ba * t;
            float dist = max(abs(d.x), abs(d.y));
            if (dist < dist_best) {
                dist_best = dist;
                t_best = t;
            }
        }
    }
    
    t_out = t_best;
    return dist_best;
}

float sdSegment(vec2 p, vec2 a, vec2 b, vec2 aspect_correction) {
    // 应用宽高比校正
    vec2 corrected_p = p * aspect_correction;
    vec2 corrected_a = a * aspect_correction;
    vec2 corrected_b = b * aspect_correction;
    
    vec2 pa = corrected_p - corrected_a;
    vec2 ba = corrected_b - corrected_a;
    
    if (brush_shape == 1) {
        float t_dummy;
        return getLInfinityDistAndT(pa, ba, t_dummy);
    }
    
    float ba_len_sq = dot(ba, ba);
    float h = 0.0;
    if (ba_len_sq > 0.0) h = clamp(dot(pa, ba) / ba_len_sq, 0.0, 1.0);
    vec2 d = pa - ba * h;

    return length(d);
}

// Helper function to calculate brush normal
bool getBrushNormal(vec2 p, vec2 p1, vec2 p2, vec2 aspect_correction, out vec2 n_out) {
    vec2 pa1 = (p - p1) * aspect_correction;
    vec2 ba1 = (p2 - p1) * aspect_correction;
    float ba1_len_sq = dot(ba1, ba1);
    float t1 = 0.0;
    if (ba1_len_sq > 0.0) t1 = dot(pa1, ba1) / ba1_len_sq;
    float h1 = clamp(t1, 0.0, 1.0);
    vec2 v_to_line1 = pa1 - ba1 * h1;
    float dist1 = length(v_to_line1);
    vec2 n1 = (dist1 > 0.0) ? (v_to_line1 / dist1) : vec2(1.0, 0.0);

    if (t1 > 0.0) 
    {
        vec2 perp = pa1 - ba1 * t1;
        if (length(perp) > 1e-6)
        {
            n1 = normalize(perp);
        }
    }

    if (brush_shape == 0 && t1 > 1.0 && ba1_len_sq > 0.0)
    {
        return false;
    }

    if (brush_shape == 1)
    {
        vec2 dir = (p - p1) * aspect_correction;
        vec2 draw_dir = p1 - p2;
        dir.y = -dir.y;
        draw_dir.y = -draw_dir.y;
        if (dir.y > dir.x && dir.y > -dir.x && (draw_dir.y > 0.0 || length(draw_dir) < 0.0001))
        {
            n1 = vec2(0.0, 1.0);
        }
        if (dir.x > dir.y && dir.x > -dir.y && (draw_dir.x > 0.0 || length(draw_dir) < 0.0001))
        {
            n1 = vec2(1.0, 0.0);
        }
        if (-dir.y > -dir.x && -dir.y > dir.x && (draw_dir.y < 0.0 || length(draw_dir) < 0.0001))
        {
            n1 = vec2(0.0, -1.0);
        }
        if (-dir.x > -dir.y && -dir.x > dir.y && (draw_dir.x < 0.0 || length(draw_dir) < 0.0001))
        {
            n1 = vec2(-1.0, 0.0);
        }

        if (length(draw_dir) > 0.0001)
        {
            vec2 dir2 = (p - p2) * aspect_correction;
            dir2.y = -dir2.y;
            if (dir2.y < dir2.x && dir2.y < -dir2.x && draw_dir.y > 0.0)
                return false;
            if (dir2.x < dir2.y && dir2.x < -dir2.y && draw_dir.x > 0.0)
                return false;
            if (-dir2.y < -dir2.x && -dir2.y < dir2.x && draw_dir.y < 0.0)
                return false;
            if (-dir2.x < -dir2.y && -dir2.x < dir2.y && draw_dir.x < 0.0)
                return false;
        }
    }
    n_out = n1;
    return true;
}

// The code we want to execute in each invocation
void main() {
    // 写入纹理数据
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    // 获取纹理尺寸
    ivec2 texture_size = imageSize(Obstacle_texture);
    vec2 aspect_correction = vec2(1.0, float(texture_size.y) / float(texture_size.x));
    
    // 将像素坐标转换为归一化坐标
    vec2 normalized_coord = vec2(pixel_coord) / vec2(texture_size);
    
    // 计算当前像素到线段的距离（使用符号距离场）
    float distance = sdSegment(normalized_coord, brush_position_1, brush_position_2, aspect_correction);
    
    // 将笔刷大小转换为归一化距离
    float normalized_brush_size = brush_size / texture_size.x;
    
    // 如果在笔刷范围内，应用笔刷效果
    if (distance < normalized_brush_size) {
        if (draw_witch == 0)
        {
            // 获取一个本地、可变的材质数据副本
            uvec4 local_packed_data = floatBitsToUint(packed_material_data);

            // 计算从笔刷路径指向当前像素的法线向量
            vec2 n1;
            if (!getBrushNormal(normalized_coord, brush_position_1, brush_position_2, aspect_correction, n1))
            {
                return;
            }

            vec2 normal = n1;

            if ((normal_mode & 0x04) > 0)
            {
                normal = -normal;
            }

            // 将法线向量转换为角度，并编码为16位无符号整数
            float angle_rad = atan(normal.y, normal.x);
            float angle_normalized = (angle_rad + 3.14159265359) / (2.0 * 3.14159265359);
            uint angle_encoded = uint(angle_normalized * 65535.0);

            if(local_packed_data == uvec4(0, 0, 0, 0))
            {
                angle_encoded = 0;
            }

            if ((normal_mode & 0x02) > 0)
            {
                float scale = clamp(1.0 - distance / normalized_brush_size, 0.0, 1.0);
                vec2 scaled_normal = normal * scale * 0.1;
                
                // 量化为8位：0.0 -> 127, -1.0 -> 0, 1.0 -> 254
                uint x_encoded = uint(clamp(scaled_normal.x * 127.0 + 127.0, 0.0, 255.0));
                uint y_encoded = uint(clamp(scaled_normal.y * 127.0 + 127.0, 0.0, 255.0));
                
                // 将X存入第9字节(低8位)，Y存入第10字节(次低8位)
                // 先清除低16位，然后写入新数据
                local_packed_data.z = (local_packed_data.z & 0xFFFF0000u) | (y_encoded << 8) | x_encoded;
            }

            // 将16位角度存入第11和12字节 (即 .z 分量的高16位)
            local_packed_data.z = (local_packed_data.z & 0x0000FFFFu) | (angle_encoded << 16);

            // 将修改后的128位材质数据写入主纹理
            imageStore(Obstacle_texture, pixel_coord, uintBitsToFloat(local_packed_data));

            // 材质标志位写入快速采样纹理
            // 修改逻辑：读取原纹理保留高4位（第5-8位），仅更新低4位（第1-4位）
            uint old_val = imageLoad(QuickSampleObstacle_texture, pixel_coord).r;
            uint flag_byte_val = (local_packed_data.g) & 0x0Fu;
            uint final_val = (old_val & 0xF0u) | flag_byte_val;
            imageStore(QuickSampleObstacle_texture, pixel_coord, uvec4(final_val, 0, 0, 0));
        }
        else if (draw_witch == 1)
        {
            vec4 pixel_data = imageLoad(Velocity_texture[UpdateCounter % 2], pixel_coord);
            // 写入速度纹理
            imageStore(Velocity_texture[(UpdateCounter + 1) % 2], pixel_coord, vec4(direction, pixel_data.zw));
            // 写入颜色纹理
            imageStore(Color_texture[(UpdateCounter + 1) % 2], pixel_coord, vec4(packed_material_data.r, 0.0, 0.0, 0.0));
        }
    }
    else if (draw_witch == 0 && packed_material_data == vec4(0.0))
    {
        // 橡皮擦外扩区域处理
        float extended_radius = normalized_brush_size + 4.0 / float(texture_size.x); // 外扩4个像素
        if (distance < extended_radius)
        {
            vec4 current_data = imageLoad(Obstacle_texture, pixel_coord);
            if (current_data.r != 0.0) // 如果该位置有材质
            {
                // 计算法线
                vec2 n1;
                if (!getBrushNormal(normalized_coord, brush_position_1, brush_position_2, aspect_correction, n1))
                {
                    return;
                }
                
                vec2 normal = -n1; // 取反

                // 更新法线
                uvec4 local_packed_data = floatBitsToUint(current_data);
                float angle_rad = atan(normal.y, normal.x);
                float angle_normalized = (angle_rad + 3.14159265359) / (2.0 * 3.14159265359);
                uint angle_encoded = uint(angle_normalized * 65535.0);
                
                local_packed_data.z = (local_packed_data.z & 0x0000FFFFu) | (angle_encoded << 16);
                imageStore(Obstacle_texture, pixel_coord, uintBitsToFloat(local_packed_data));
            }
        }
    }
    return;
}