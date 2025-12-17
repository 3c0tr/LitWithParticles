#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform image2D Velocity_texture[2];
layout(set = 0, binding = 1, r32f) uniform image2D Color_texture[2];

layout(set = 0, binding = 2, std430) buffer FluidSim {
    ivec4 temp0;
    vec4 temp1;
};

// Unpacks a uint (BGRA8) to a vec4 color (0.0-1.0)
vec4 unpack_bgra(uint packed_color) {
    float b = float((packed_color >> 0) & 0xFFu) / 255.0;
    float g = float((packed_color >> 8) & 0xFFu) / 255.0;
    float r = float((packed_color >> 16) & 0xFFu) / 255.0;
    float a = float((packed_color >> 24) & 0xFFu) / 255.0;
    return vec4(r, g, b, a);
}

// Packs a vec4 color (0.0-1.0) into a uint (BGRA8)
uint pack_bgra(vec4 color) {
    uint r = uint(clamp(color.r, 0.0, 1.0) * 255.0);
    uint g = uint(clamp(color.g, 0.0, 1.0) * 255.0);
    uint b = uint(clamp(color.b, 0.0, 1.0) * 255.0);
    uint a = uint(clamp(color.a, 0.0, 1.0) * 255.0);
    return (a << 24) | (r << 16) | (g << 8) | b;
}

// Function to perform manual bilinear sampling on an image2D
vec4 bilinear_sample(int read_channel, vec2 coord) {
    vec2 floor_coord = floor(coord);
    vec2 fract_coord = fract(coord);

    ivec2 p00 = ivec2(floor_coord);
    
    // Sample the four nearest neighbors, clamping to avoid out-of-bounds access
    ivec2 tex_size = imageSize(Color_texture[read_channel]);
    
    // Load float, convert to uint, then unpack
    uint packed00 = floatBitsToUint(imageLoad(Color_texture[read_channel], clamp(p00 + ivec2(0, 0), ivec2(0), tex_size - 1)).r);
    uint packed10 = floatBitsToUint(imageLoad(Color_texture[read_channel], clamp(p00 + ivec2(1, 0), ivec2(0), tex_size - 1)).r);
    uint packed01 = floatBitsToUint(imageLoad(Color_texture[read_channel], clamp(p00 + ivec2(0, 1), ivec2(0), tex_size - 1)).r);
    uint packed11 = floatBitsToUint(imageLoad(Color_texture[read_channel], clamp(p00 + ivec2(1, 1), ivec2(0), tex_size - 1)).r);

    vec4 v00 = unpack_bgra(packed00);
    vec4 v10 = unpack_bgra(packed10);
    vec4 v01 = unpack_bgra(packed01);
    vec4 v11 = unpack_bgra(packed11);

    // Interpolate horizontally, then vertically
    return mix(mix(v00, v10, fract_coord.x), mix(v01, v11, fract_coord.x), fract_coord.y);
}

void main() {
    int read_channel = (temp0.x) % 2;
    int write_channel = (temp0.x + 1) % 2;
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    const float dt = 0.15;

    vec2 velocity = imageLoad(Velocity_texture[read_channel], pixel_coords).xy;
    vec2 advection_coord = vec2(pixel_coords) - velocity * dt * 30.0;
    vec4 col = bilinear_sample(read_channel, advection_coord);
    col.a = max(0.0, abs(col.a) - 1e-4);
    col.rgb = mix(col.rgb, vec3(1.0), 1e-2);
    
    // Pack color to uint, then convert to float for storage
    uint packed_col = pack_bgra(col);
    float float_col = uintBitsToFloat(packed_col);
    
    imageStore(Color_texture[write_channel], pixel_coords, vec4(float_col, 0, 0, 0));
    return;
}