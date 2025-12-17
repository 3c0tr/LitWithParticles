#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform image2D Velocity_texture[2];
layout(set = 0, binding = 1, r8ui) uniform readonly uimage2D QuickSampleObstacle_texture;

layout(set = 0, binding = 2, std430) buffer FluidSim {
    ivec4 temp0;
    vec4 temp1;
};

// Function to perform manual bilinear sampling on an image2D
vec4 bilinear_sample(int read_channel, vec2 coord) {
    vec2 floor_coord = floor(coord);
    vec2 fract_coord = fract(coord);

    ivec2 p00 = ivec2(floor_coord);
    
    // Sample the four nearest neighbors, clamping to avoid out-of-bounds access
    ivec2 tex_size = imageSize(Velocity_texture[read_channel]);
    vec4 v00 = imageLoad(Velocity_texture[read_channel], clamp(p00 + ivec2(0, 0), ivec2(0), tex_size - 1));
    vec4 v10 = imageLoad(Velocity_texture[read_channel], clamp(p00 + ivec2(1, 0), ivec2(0), tex_size - 1));
    vec4 v01 = imageLoad(Velocity_texture[read_channel], clamp(p00 + ivec2(0, 1), ivec2(0), tex_size - 1));
    vec4 v11 = imageLoad(Velocity_texture[read_channel], clamp(p00 + ivec2(1, 1), ivec2(0), tex_size - 1));

    // Interpolate horizontally, then vertically
    return mix(mix(v00, v10, fract_coord.x), mix(v01, v11, fract_coord.x), fract_coord.y);
}

void main() {
    int read_channel = temp0.x % 2;
    int write_channel = (temp0.x + 1) % 2;
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

    if (pixel_coords.x == 0 || pixel_coords.x == imageSize(Velocity_texture[0]).x - 1 ||
        pixel_coords.y == 0 || pixel_coords.y == imageSize(Velocity_texture[0]).y - 1) {
        imageStore(Velocity_texture[write_channel], pixel_coords, vec4(0.0, 0.0, 0.5, 0.0));
        return;
    } // boundary condition

    bool O_obstacle = (imageLoad(QuickSampleObstacle_texture, pixel_coords).x & 2u) != 0u;
    if (O_obstacle) {
        imageStore(Velocity_texture[write_channel], pixel_coords, vec4(0.0, 0.0, 0.5, 0.0));
        return;
    }
    bool O_up = (imageLoad(QuickSampleObstacle_texture, pixel_coords + ivec2(0, 1)).x & 2u) != 0u;
    bool O_down = (imageLoad(QuickSampleObstacle_texture, pixel_coords - ivec2(0, 1)).x & 2u) != 0u;
    bool O_left = (imageLoad(QuickSampleObstacle_texture, pixel_coords - ivec2(1, 0)).x & 2u) != 0u;
    bool O_right = (imageLoad(QuickSampleObstacle_texture, pixel_coords + ivec2(1, 0)).x & 2u) != 0u;   

    vec2 uv = gl_GlobalInvocationID.xy / vec2(imageSize(Velocity_texture[0]));
    const float dt = 0.15;
    const float v = 0.55;
    const float K = 0.3;
    const float VORTICTY_AMOUNT = 0.11;
    const float Cscale = 0.5;

    vec4 mid = imageLoad(Velocity_texture[read_channel], pixel_coords);
    vec4 left = imageLoad(Velocity_texture[read_channel], pixel_coords - ivec2(1, 0));
    vec4 right = imageLoad(Velocity_texture[read_channel], pixel_coords + ivec2(1, 0));
    vec4 up = imageLoad(Velocity_texture[read_channel], pixel_coords + ivec2(0, 1));
    vec4 down = imageLoad(Velocity_texture[read_channel], pixel_coords - ivec2(0, 1));

    if (O_up) up.xy = -mid.xy;
    if (O_down) down.xy = -mid.xy;
    if (O_left) left.xy = -mid.xy;
    if (O_right) right.xy = -mid.xy;

    // Gradient
    vec3 dx = (right.xyz - left.xyz) * Cscale;
    vec3 dy = (up.xyz - down.xyz) * Cscale;
    vec2 densDiff = vec2(dx.z, dy.z);

    // Solve for density
    mid.z -= dt * dot(vec3(densDiff, dx.x + dy.y), mid.xyz);

    // Solve for velocity
    vec2 laplacian = up.xy + down.xy + left.xy + right.xy - 4 * mid.xy;
    vec2 viscForce = laplacian * v;

    // Advection (Semi-Lagrangian with manual Bilinear Interpolation)
    // Trace back in time to find the departure point
    vec2 advection_coord = vec2(pixel_coords) - mid.xy * dt * 10.0;
    mid.xyw = bilinear_sample(read_channel, advection_coord).xyw;

    mid.xy += dt * (viscForce.xy - K / dt * densDiff);
    mid.xy = max(vec2(0.0), abs(mid.xy) - 1e-4) * sign(mid.xy);

    // Vort
    mid.w = right.y - left.y - up.x + down.x;
    vec2 vort = vec2(abs(up.w) - abs(down.w), abs(left.w) - abs(right.w));
    vort *= VORTICTY_AMOUNT / length(vort + 1e-9) * mid.w;
    mid.xy += vort;

    mid = clamp(mid, vec4(-10, -10, 0.5, -10), vec4(10, 10, 3, 10));
    imageStore(Velocity_texture[write_channel], pixel_coords, mid);
    return;
}