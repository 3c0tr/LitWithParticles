#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform image2D Obstacle_texture;
// For simplicity, move the buffer to set 0, binding 1
layout(set = 0, binding = 1, std430) buffer ReadTexture_buffer {
    vec2 uv;
    float read_back_data[8];
} read_texture_buffer;

void main() {
    // Get the size of the texture
    ivec2 tex_size = imageSize(Obstacle_texture);
    
    // Convert normalized UV coordinates to integer pixel coordinates for imageLoad
    ivec2 pixel_coords = ivec2(read_texture_buffer.uv * vec2(tex_size));
    
    // Read the pixel data from the texture at the specified coordinates
    vec4 pixel_data = imageLoad(Obstacle_texture, pixel_coords);
    
    // Store the pixel data into the read_back_data array
    read_texture_buffer.read_back_data[0] = pixel_data.r;
    read_texture_buffer.read_back_data[1] = pixel_data.g;
    read_texture_buffer.read_back_data[2] = pixel_data.b;
    read_texture_buffer.read_back_data[3] = pixel_data.a;
}