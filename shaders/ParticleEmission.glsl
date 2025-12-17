#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// 添加纹理绑定
layout(set = 0, binding = 0, rgba32f) uniform image2D output_texture;

// 添加浮点数 uniform 缓冲区
layout(set = 0, binding = 1, std430) restrict readonly buffer FloatBuffer {
    int cnt;
    int jump_times;
    float input_value;
    int flag;
    float z_order_offset;
    float sun_light_dir;
    float jump_length;
    float light_penetration;
    float emit_material_decay;
    vec3 sun_light_color;
};

layout(set = 0, binding = 2, r32i) uniform iimage2D output_int_texture_div1;
layout(set = 0, binding = 3, r32i) uniform iimage2D output_int_texture_div2;
layout(set = 0, binding = 4, r32i) uniform iimage2D output_int_texture_div4;
layout(set = 0, binding = 5, r32i) uniform iimage2D output_int_texture_div8;

layout(set = 0, binding = 6, rgba32f) uniform readonly image2D Obstacle_texture;
layout(set = 0, binding = 7, r8ui) uniform readonly uimage2D QuickSampleObstacle_texture;
layout(set = 0, binding = 8, rg32f) uniform writeonly image2D LightPartical_texture[2];
layout(set = 0, binding = 9, r32f) uniform readonly image2D FluidColor_texture[2];
#define PI 3.14159265359
float hash1(float p) {
    return fract(sin(p) * 7581.5453);
}

float hash2(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 rotate2(vec2 v, float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat2(c, s, -s, c) * v;
}

uint part1by1(uint n) {
    n &= 0x0000FFFF;
    n = (n | (n << 8)) & 0x00FF00FF;
    n = (n | (n << 4)) & 0x0F0F0F0F;
    n = (n | (n << 2)) & 0x33333333;
    n = (n | (n << 1)) & 0x55555555;
    return n;
}

uint remap_z_order(ivec2 logical_coord) {
    uint z_index = part1by1(uint(logical_coord.y)) | (part1by1(uint(logical_coord.x)) << 1);
    return z_index;//ivec2(int(z_index % uint(texture_width)), int(z_index / uint(texture_width)));
}

vec4 get_color(float color_data)
{
    uint color_data_uint = floatBitsToUint(color_data);
    vec4 col = vec4(
        float((color_data_uint >> 16) & 0xFFu) / 255.0f,// R
        float((color_data_uint >> 8) & 0xFFu) / 255.0f, // G
        float(color_data_uint & 0xFFu) / 255.0f,        // B
        float((color_data_uint >> 24) & 0xFFu) / 255.0f // A
    );
    return col;
}

vec4 get_color(uint color_data_uint)
{
    vec4 col = vec4(
        float((color_data_uint >> 16) & 0xFFu) / 255.0f,// R
        float((color_data_uint >> 8) & 0xFFu) / 255.0f, // G
        float(color_data_uint & 0xFFu) / 255.0f,        // B
        float((color_data_uint >> 24) & 0xFFu) / 255.0f // A
    );
    return col;
}

float encode_color(vec4 color)
{
    uint r = uint(color.r * 255.0) & 0xFFu;
    uint g = uint(color.g * 255.0) & 0xFFu;
    uint b = uint(color.b * 255.0) & 0xFFu;
    uint a = uint(color.a * 255.0) & 0xFFu;
    return uintBitsToFloat((a << 24) | (r << 16) | (g << 8) | b);
}

float get_value(uint data, uint position)
{
	return float((data >> (position * 8u)) & 0xFFu) / 255.0;
}

float GetLinearSpreadAngle(ivec2 pixel_coord, vec2 linear_offset, float rotation)
{
    vec2 pixel_coord_float = vec2(pixel_coord);
    pixel_coord_float = rotate2(pixel_coord_float, rotation);
    float angle = dot(pixel_coord_float, linear_offset);
    return angle;
}

float GetZOrderSpreadAngle(ivec2 pixel_coord, float offset)
{
    uint z_index = remap_z_order(pixel_coord);
    float angle = float(z_index) * offset;
    return angle;
}

uvec3 MapFloatToUint(vec3 color, uint max_value)
{
    uvec3 color_uint = uvec3(color * float(max_value));
    return color_uint;
}

uvec3 MapFloatToUintDrift(vec3 color, float random_noise, uint max_value)
{
    uvec3 color_uint = uvec3(color * float(max_value) + vec3(random_noise - 0.5));
    return color_uint;
}

uint EncodeRGBIntoUint(uvec3 accumulated_light)
{
    uint r = accumulated_light.r & 0xFFu;
    uint g = accumulated_light.g & 0xFFu;
    uint b = accumulated_light.b & 0xFFu;
    return (b << 22) | (g << 11) | r;
}

void StoreLightPartical(ivec2 pixel_coord, int texture_index, float direction, int max_range, float life, float packed_color, float traveled_distance)
{
    uint life_uint = uint(clamp(life, 0.0, 1.0) * 255.0) & 0xFFu;
    uint max_range_uint = uint(max_range) & 0xFFu;
    uint direction_uint = uint(clamp(direction, 0.0, 1.0) * 65535.0);
    uint packed_data = (direction_uint << 16) | (max_range_uint << 8) | life_uint;

    // Pack traveled distance into the Alpha channel of the color
    vec4 color = get_color(packed_color);
    float pixel_max_range = float(max_range << 3);
    color.a = clamp(traveled_distance / (pixel_max_range + 0.001), 0.0, 1.0);
    float new_packed_color = encode_color(color);

    imageStore(LightPartical_texture[texture_index], pixel_coord, vec4(new_packed_color, uintBitsToFloat(packed_data), 0.0, 0.0));
}

vec2 rotate_around_point(vec2 point, vec2 center, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    mat2 rotation_matrix = mat2(vec2(c, s), vec2(-s, c));
    return rotation_matrix * (point - center) + center;
}

void PropagationParticleOptimized(ivec2 pixel_coord, vec2 uv, ivec2 texture_size, float direction, vec2 advance, float packed_color, int max_range, float life, float jump_length, int jump_times, float start_distance)
{
    ivec2 current_pixel_position = pixel_coord;
    ivec2 last_pixel_position = ivec2(-1, -1);
    vec2 current_uv_position = uv;
    vec2 last_uv_position = uv;
    float Particlelife = life;
    float pixel_max_range = float(max_range << 3);
    float decay = jump_length / (pixel_max_range + 0.001);
    vec4 color = get_color(packed_color);
    
    float current_distance = start_distance;
    
    float spectral_balance = (color.b - color.r) / (color.r + color.g + color.b + 0.001);
    float ior_offset = spectral_balance * 0.2; 
    vec3 accumulated_light = vec3(0.0);

    uvec4 obstacle_data = floatBitsToUint(imageLoad(Obstacle_texture, current_pixel_position));
    float current_IOR = 1.0 + get_value(obstacle_data.g, 3) * 1.5;
    float last_IOR = current_IOR;
    uint material_type;

    // Shared temporary variables to reduce stack pressure
    uvec4 physics_data;
    float normal_angle, roughness, metallic, seed;
    vec2 normal_vec, incident_vec, new_dir_vec;
    float n1, n2, n_ratio, cos_i, sin_t2, r0, reflectance, cos_t;
    bool reflected, is_vacuum, is_penetrating;
    is_penetrating = false;

    // Dither the LOD transition threshold to prevent banding artifacts
    //float transition_noise = hash1(float(gl_GlobalInvocationID.x * 133.92) + float(gl_GlobalInvocationID.y * 321.173) + input_value);
    //int(162.0 * (0.85 + 0.3 * transition_noise));

    int last_div_resolution = 1;

    for (int i = 0; i < jump_times; i++)
    {  
        material_type = uint(imageLoad(QuickSampleObstacle_texture, current_pixel_position).r) & 0xFFu;
        last_IOR = current_IOR;
        is_vacuum = (material_type & 0x02u) == 0u;
        reflected = false;

        if (is_vacuum)
        {
            if (is_penetrating)
                return;
            current_IOR = 1.0;
        }
        else
        {
            obstacle_data = floatBitsToUint(imageLoad(Obstacle_texture, current_pixel_position));
            current_IOR = 1.0 + get_value(obstacle_data.g, 3) * 1.5;
        }

        if (abs(current_IOR - last_IOR) > 0.01)
        {
            if (is_vacuum)
                physics_data = floatBitsToUint(imageLoad(Obstacle_texture, last_pixel_position));
            else
                physics_data = obstacle_data;

            normal_angle = float((physics_data.b >> 16) & 0xFFFFu) / 65535.0 * 2.0 * PI - PI;
            roughness = get_value(physics_data.g, 0);
            metallic = get_value(physics_data.a, 0);

            seed = float(i) + current_uv_position.x * 13.92 + current_uv_position.y * 25.84 + input_value * 134.915;
            normal_angle += (hash1(seed) - 0.5) * roughness * PI;

            normal_vec = vec2(cos(normal_angle), sin(normal_angle));
            incident_vec = vec2(cos(direction * 2.0 * PI - PI), sin(direction * 2.0 * PI - PI));

            if (dot(incident_vec, normal_vec) > 0.0) 
                normal_vec = -normal_vec;

            n1 = last_IOR;
            if (n1 > 1.01) n1 += ior_offset;
            n2 = current_IOR;
            if (n2 > 1.01) n2 += ior_offset;
            n_ratio = n1 / n2;

            cos_i = -dot(normal_vec, incident_vec);
            sin_t2 = n_ratio * n_ratio * (1.0 - cos_i * cos_i);

            r0 = (n1 - n2) / (n1 + n2);
            r0 = r0 * r0;
            r0 = mix(r0, 1.0, metallic);
            reflectance = r0 + (1.0 - r0) * pow(1.0 - cos_i, 5.0);

            if (sin_t2 > 1.0 || hash1(seed) < reflectance) 
            {
                new_dir_vec = reflect(incident_vec, normal_vec);
                direction = (atan(new_dir_vec.y, new_dir_vec.x) + PI) / (2.0 * PI);
                advance = rotate2(vec2(1.0, 0.0), (direction) * PI * 2.0) / vec2(texture_size);
                current_uv_position = last_uv_position;
                current_pixel_position = ivec2(current_uv_position * vec2(texture_size) + vec2(0.5));
                current_IOR = last_IOR; 
                reflected = true;
                vec4 obstacle_color = get_color(obstacle_data.r);
                color = vec4(mix(color.rgb, vec3(0.0), (vec3(1.0) - obstacle_color.rgb) * 3.0 * (1.0 - metallic)), color.a);
            } 
            else 
            {
                cos_t = sqrt(1.0 - sin_t2);
                new_dir_vec = n_ratio * incident_vec + (n_ratio * cos_i - cos_t) * normal_vec;
                direction = (atan(new_dir_vec.y, new_dir_vec.x) + PI) / (2.0 * PI);
                advance = rotate2(vec2(1.0, 0.0), (direction) * PI * 2.0) / vec2(texture_size);
            }
        }

        if (!is_vacuum)
        {
            if (!reflected)
            {
                vec4 obstacle_color = get_color(obstacle_data.r);
                float opacity = get_value(obstacle_data.r, 3);
                float scatter_rate = get_value(obstacle_data.g, 2);

                if (scatter_rate > 0.0)
                {
                    float seed = float(i) + current_uv_position.x * 67.21 + current_uv_position.y * 11.56 + input_value * 421.42;
                    float random_angle_change = (hash1(seed) - 0.5) * scatter_rate; 
                    direction = fract(direction + random_angle_change);
                    advance = rotate2(vec2(1.0, 0.0), direction * 2.0 * PI) / vec2(texture_size);
                }

                if (opacity > 0.99)
                {
                    is_penetrating = true;
                }
                if (is_penetrating && opacity <= 0.99)
                {
                    return;
                }
                Particlelife *= (1.0 - opacity * light_penetration);
                // 物理正确的吸收模型（Beer-Lambert近似）：互补色会被完全吸收（如红光穿过绿玻璃变黑）。
                // 使用max防止不透明度过高导致光照强度变为负数。
                // 注意：这里假设obstacle_color是透射颜色（白=全透，黑=全吸）。
                vec3 absorption_factor = (vec3(1.0) - obstacle_color.rgb) * opacity * 2.0;
                color.rgb *= max(vec3(0.01), vec3(1.0) - absorption_factor);
            }
            if ((material_type & 0x04u) > 0u)
            {
                vec2 gravity = vec2(get_value(obstacle_data.b, 0), get_value(obstacle_data.b, 1)) - vec2(0.5);
                if (length(gravity) > 0.001)
                {
                    float gravity_strength = get_value(obstacle_data.b, 2) * 0.1;
                    
                    float current_angle = direction * 2.0 * PI;
                    vec2 current_dir = vec2(cos(current_angle), sin(current_angle));
                    vec2 gravity_dir = normalize(gravity);
                    vec2 new_dir = normalize(mix(current_dir, gravity_dir, gravity_strength));
                    
                    float new_angle = atan(new_dir.y, new_dir.x);
                    direction = fract(new_angle / (2.0 * PI));
                    advance = rotate2(vec2(1.0, 0.0), direction * 2.0 * PI) / vec2(texture_size);
                }
            }
            if ((material_type & 0x08u) > 0u)
            {
                vec2 portal_distance = vec2(get_value(obstacle_data.b, 0), get_value(obstacle_data.b, 1));
                portal_distance = (portal_distance - 0.5) * 2048.0;
                current_uv_position += portal_distance / texture_size;
            }
        }
        else if ((flag & 0x02u) > 0u)
        {
            vec4 fluid_color = get_color(imageLoad(FluidColor_texture[cnt % 2], current_pixel_position).r);
            float opacity = fluid_color.a;
            Particlelife *= (1.0 - opacity * 0.05);
            // color = min(mix(color, fluid_color, opacity * 0.01), color);
        }

        Particlelife -= decay;
        if (Particlelife <= 0.0 && i != 0)
            return;
        
        // 这一步其实是非物理的，主要目的是防止你在区域中涂抹大量完全透明发光体造成性能崩溃...
        if ((material_type & 0x01u) == 1u && i > 24)
            Particlelife -= emit_material_decay;

        accumulated_light += color.rgb * Particlelife;
        // int travel_pixels = int(pixel_max_range * (1 - Particlelife));
        int travel_pixels = int(current_distance);
        int level = clamp(travel_pixels / 162, 0, 3);
        int div_resolution = 1 << level;
        
        if (div_resolution != last_div_resolution || current_pixel_position / div_resolution != last_pixel_position / div_resolution)
        {
            last_div_resolution = div_resolution;
            last_pixel_position = current_pixel_position;
            float random_noise = hash2(vec2(gl_GlobalInvocationID.xy) + vec2(input_value));
            uint skip_level = (flag & 0x08u) > 0u ? material_type >> 4 & 0xFu : 0u;
            
            float rnd = random_noise;
            float threshold = float(skip_level) / (float(skip_level) + 5.0);
            
            if (rnd > threshold) // 跳过一些像素，以减少写入量
            {
                uvec3 Uint_Color = MapFloatToUintDrift(accumulated_light, random_noise, 16u / div_resolution);
                int encoded_color = int(EncodeRGBIntoUint(Uint_Color));
                if (div_resolution == 1)
                    imageAtomicAdd(output_int_texture_div1, current_pixel_position / div_resolution, encoded_color);
                else if (div_resolution == 2)
                    imageAtomicAdd(output_int_texture_div2, current_pixel_position / div_resolution, encoded_color);
                else if (div_resolution == 4)
                    imageAtomicAdd(output_int_texture_div4, current_pixel_position / div_resolution, encoded_color);
                else if (div_resolution == 8)
                    imageAtomicAdd(output_int_texture_div8, current_pixel_position / div_resolution, encoded_color);
            }

            accumulated_light = ivec3(0);
        }

        last_uv_position = current_uv_position;
        current_uv_position += advance * jump_length;
        current_distance += jump_length;

        if (current_uv_position.x < 0.0 || current_uv_position.x > 1.0 || current_uv_position.y < 0.0 || current_uv_position.y > 1.0)
            return;
            
        current_pixel_position = ivec2(current_uv_position * vec2(texture_size) + vec2(0.5));
    }
    
    if (Particlelife >= 0.01 && (flag & 0x01u) > 0u)
    {
        StoreLightPartical(current_pixel_position, cnt % 2, direction, max_range, Particlelife, encode_color(color), current_distance);
    }
}

bool sun_light(ivec2 pixel_coord, float sun_light_dir, ivec2 texture_size)
{
    return  (pixel_coord.y < 3 && sun_light_dir > 0.0 && sun_light_dir < 0.5) ||
            (pixel_coord.y > texture_size.y - 4 && sun_light_dir > 0.5 && sun_light_dir < 1.0) ||
            (pixel_coord.x > texture_size.x - 4 && sun_light_dir > 0.25 && sun_light_dir < 0.75) || 
            (pixel_coord.x < 3 && (sun_light_dir > 0.75 || sun_light_dir < 0.25));
}

void main()
{
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 texture_size = imageSize(output_texture);
    vec2 uv = vec2(pixel_coord) / vec2(imageSize(output_texture));

    vec4 root_obstacle_data;
    int max_range = 324 >> 4;
    float scatterL;
    float scatterR;
    float life;
    float angle;

    uint root_material_type = imageLoad(QuickSampleObstacle_texture, pixel_coord).r;
    float color_data;

    // if (length(uv - vec2(0.5)) < 0.3)
    if ((root_material_type & 0x01u) == 1u) // 当前像素存在发光体
    {
        // angle = fract(GetLinearSpreadAngle(pixel_coord, vec2(0.038, 0.168), 0.0) + input_value);
        angle = fract(GetZOrderSpreadAngle(pixel_coord, z_order_offset) + input_value);

        // angle = fract(hash1(float(pixel_coord.x) * 6.98 + float(pixel_coord.y) * 19.33) + input_value);
        // angle = 0.0;

        root_obstacle_data = imageLoad(Obstacle_texture, pixel_coord);
        color_data = root_obstacle_data.r;
        max_range = int((floatBitsToUint(root_obstacle_data.a) >> 8u) & 0xFFu);
        scatterL = get_value(floatBitsToUint(root_obstacle_data.a), 2u);
        scatterR = get_value(floatBitsToUint(root_obstacle_data.a), 3u);
        bool in_range = (scatterL <= scatterR) ? (angle > scatterL && angle < scatterR) : (angle > scatterL || angle < scatterR);
        if (!in_range) return;
        life = 1.0;
    }
    else
    {
        return;
    }

    for(int i = 0; i < 1; i++)
    {
        // --- Stochastic Dispersion Tinting ---
        float dispersion_seed = float(pixel_coord.x) * 6.98 + float(pixel_coord.y) * 19.33 + angle * 43758.5453 + uv.x * 12.9898 + float(i) * 0.1 + input_value * 2124.76;
        float dispersion_bias = hash1(dispersion_seed) * 2.0 - 1.0; 

        vec4 col_vec = get_color(color_data);
        vec3 spectral_tint = vec3(1.0);
        
        if ((flag & 0x04u) > 0u) // 开启了色散
        {
            // Use subtractive tinting to avoid RGB overflow (which causes wrapping artifacts like green tint)
            // Bias -1.0 (Red): Keeps Red, reduces Blue completely, reduces Green partially
            // Bias +1.0 (Blue): Keeps Blue, reduces Red completely, reduces Green partially
            // Bias  0.0 (White): Keeps all channels
            spectral_tint.r = 1.0 - max(0.0, dispersion_bias);      // Reduce Red if bias is Blue (>0)
            spectral_tint.b = 1.0 - max(0.0, -dispersion_bias);     // Reduce Blue if bias is Red (<0)
            spectral_tint.g = 1.0 - abs(dispersion_bias) * 0.5;     // Reduce Green moderately on both sides to balance energy

            col_vec.rgb *= spectral_tint;
            col_vec = clamp(col_vec, 0.0, 1.0); // Safety clamp
            float modified_packed_color = encode_color(col_vec);
            color_data = modified_packed_color;
            // -------------------------------------
        }

        vec2 advance = rotate2(vec2(1.0, 0.0), (angle) * PI * 2.0) / vec2(texture_size);
        PropagationParticleOptimized(pixel_coord, uv, texture_size, angle, advance, color_data, max_range, life, jump_length, jump_times, 0.0);
    }
}