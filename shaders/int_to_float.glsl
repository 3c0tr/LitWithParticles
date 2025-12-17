#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32i) uniform iimage2D input_int_texture_div1;
layout(set = 0, binding = 1, r32i) uniform iimage2D input_int_texture_div2;
layout(set = 0, binding = 2, r32i) uniform iimage2D input_int_texture_div4;
layout(set = 0, binding = 3, r32i) uniform iimage2D input_int_texture_div8;
layout(set = 0, binding = 4, rgba32f) uniform image2D output_texture;

layout(set = 0, binding = 5, std430) buffer Develop_film_buffer {
    vec4 film_params;
};

layout(set = 0, binding = 6, r8ui) uniform uimage2D QuickSampleObstacle_texture_rd;

uvec3 DecodeRGBIntoUint(uint encoded_color)
{
    uint r = encoded_color & 0x3FFu;
    uint g = (encoded_color >> 11) & 0x3FFu;
    uint b = (encoded_color >> 22) & 0x3FFu;
    return uvec3(r, g, b);
}
// 所以有人知道到底该怎样在godot-glsl中制作带纹理参数的函数吗？
#define DEFINE_BILINEAR_SAMPLE(FUNC_NAME, TEXTURE_NAME) \
vec3 FUNC_NAME(ivec2 target_coord, ivec2 target_size) { \
    ivec2 source_size = imageSize(TEXTURE_NAME); \
    vec2 uv = (vec2(target_coord) + 0.5) / vec2(target_size); \
    vec2 source_coord = uv * vec2(source_size) - 0.5; \
    ivec2 coord00 = ivec2(floor(source_coord)); \
    ivec2 coord10 = coord00 + ivec2(1, 0); \
    ivec2 coord01 = coord00 + ivec2(0, 1); \
    ivec2 coord11 = coord00 + ivec2(1, 1); \
    coord00 = clamp(coord00, ivec2(0), source_size - 1); \
    coord10 = clamp(coord10, ivec2(0), source_size - 1); \
    coord01 = clamp(coord01, ivec2(0), source_size - 1); \
    coord11 = clamp(coord11, ivec2(0), source_size - 1); \
    vec2 fract_coord = fract(source_coord); \
    float w00 = (1.0 - fract_coord.x) * (1.0 - fract_coord.y); \
    float w10 = fract_coord.x * (1.0 - fract_coord.y); \
    float w01 = (1.0 - fract_coord.x) * fract_coord.y; \
    float w11 = fract_coord.x * fract_coord.y; \
    uint sample00 = uint(imageLoad(TEXTURE_NAME, coord00).r); \
    uint sample10 = uint(imageLoad(TEXTURE_NAME, coord10).r); \
    uint sample01 = uint(imageLoad(TEXTURE_NAME, coord01).r); \
    uint sample11 = uint(imageLoad(TEXTURE_NAME, coord11).r); \
    uvec3 decoded_sample00 = DecodeRGBIntoUint(sample00); \
    uvec3 decoded_sample10 = DecodeRGBIntoUint(sample10); \
    uvec3 decoded_sample01 = DecodeRGBIntoUint(sample01); \
    uvec3 decoded_sample11 = DecodeRGBIntoUint(sample11); \
    vec3 interpolated = vec3(decoded_sample00) * w00 + \
                       vec3(decoded_sample10) * w10 + \
                       vec3(decoded_sample01) * w01 + \
                       vec3(decoded_sample11) * w11; \
    return interpolated; \
}

// Instantiate the function for the texture we need
DEFINE_BILINEAR_SAMPLE(bilinearSample_div2, input_int_texture_div2)
DEFINE_BILINEAR_SAMPLE(bilinearSample_div4, input_int_texture_div4)
DEFINE_BILINEAR_SAMPLE(bilinearSample_div8, input_int_texture_div8)


// The code we want to execute in each invocation
void main() {
    // Get pixel coordinates
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    // Get texture dimensions
    ivec2 texture_size = imageSize(output_texture);
    
    // Ensure we are within texture boundaries
    if (pixel_coord.x >= texture_size.x || pixel_coord.y >= texture_size.y) {
        return;
    }

    uint raw_data = uint(imageLoad(input_int_texture_div1, pixel_coord).r);
    uvec3 uint_color = DecodeRGBIntoUint(raw_data);

    vec3 color_div2 = bilinearSample_div2(pixel_coord, texture_size);
    vec3 color_div4 = bilinearSample_div4(pixel_coord, texture_size);
    vec3 color_div8 = bilinearSample_div8(pixel_coord, texture_size);
    
    // Convert integer color from 0-255 to float color from 0-1
    vec3 raw_float_color = vec3(uint_color) / 128.0;
    raw_float_color += color_div2 / 256.0;
    raw_float_color += color_div4 / 512.0;
    raw_float_color += color_div8 / 1024.0;
    // raw_float_color = vec3(1.2);

    // Tonemapping to allow limited overexposure while preserving color ratio
    const float max_brightness = 2.0;
    float luminance = max(max(raw_float_color.r, raw_float_color.g), raw_float_color.b);
    float mapped_luminance = max_brightness * luminance / (luminance + 1.0);
    vec3 float_color = raw_float_color * (mapped_luminance / max(luminance, 0.0001));

    vec4 output_texture_color = imageLoad(output_texture, pixel_coord);
    vec4 fin = vec4(mix(output_texture_color.rgb, float_color.rgb, film_params[2]), 1.0);   

    // Write to the output texture
    imageStore(output_texture, pixel_coord, fin);//vec4(corrected_color, 1.0));
}