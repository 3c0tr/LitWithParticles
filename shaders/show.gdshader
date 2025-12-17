shader_type canvas_item;

uniform sampler2D Obstacle_texture : source_color, filter_nearest;
uniform sampler2D LightPartical_texture : source_color, filter_nearest;

uniform sampler2D FluidColor_texture0 : source_color, filter_nearest;
uniform sampler2D FluidColor_texture1 : source_color, filter_nearest;

uniform sampler2D FluidVelocity_texture0 : source_color, filter_nearest;
uniform sampler2D FluidVelocity_texture1 : source_color, filter_nearest;

uniform int UpdateCounter = 0;
uniform float color_scale = 1.0;
uniform vec2 mouse_position = vec2(0.0);
uniform float brush_size = 10.0;
uniform vec4 ambient = vec4(0.0, 0.0, 0.0, 1.0);
uniform int brush_shape = 0;
uniform float sun_angle = 0.0;
uniform bool outline = true;
uniform bool show_particle = false;
uniform bool show_normal = false;

vec3 chessboard(vec2 uv, ivec2 texture_size, vec3 col1, vec3 col2)
{
    float dim = 1.0;
    vec2 scale = vec2(texture_size) / 1024.0;
    vec2 line1 = fract((uv) * 16.0 * scale - vec2(0.01));
    if (line1.x > 0.99 || line1.y > 0.99)
    {
        dim *= 0.5;
    }

    vec2 line2 = fract((uv) * 64.0 * scale - vec2(0.01));
    if (line2.x > 0.90 || line2.y > 0.90)
    {
        dim *= 0.9;
    }

    vec2 cell = floor(uv * 16.0 * scale);
    if (mod(cell.x + cell.y, 2.0) == 0.0)
    {
        return col1 * dim;
    }
    else
    {
        return col2 * dim;
    }
}

vec4 get_color(uint color_data_uint)
{
    vec4 col = vec4(
        float((color_data_uint >> 16u) & 0xFFu) / 255.0f,// R
        float((color_data_uint >> 8u) & 0xFFu) / 255.0f, // G
        float(color_data_uint & 0xFFu) / 255.0f,        // B
        float((color_data_uint >> 24u) & 0xFFu) / 255.0f // A
    );
    return col;
}

vec2 rotate_around_point(vec2 point, vec2 center, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    mat2 rotation_matrix = mat2(vec2(c, s), vec2(-s, c));
    return rotation_matrix * (point - center) + center;
}

void fragment() {

    vec4 light = texture(TEXTURE, UV) * color_scale;
    ivec2 texture_size = textureSize(TEXTURE, 0);
    float color_data = texture(Obstacle_texture, UV).r;
    vec4 obstacle_color = get_color(floatBitsToUint(color_data));

    float color_data_left = texture(Obstacle_texture, UV + vec2(1.0, 0.0) / vec2(texture_size)).r;
    float color_data_right = texture(Obstacle_texture, UV + vec2(-1.0, 0.0) / vec2(texture_size)).r;
    float color_data_up = texture(Obstacle_texture, UV + vec2(0.0, 1.0) / vec2(texture_size)).r;
    float color_data_down = texture(Obstacle_texture, UV + vec2(0.0, -1.0) / vec2(texture_size)).r;

    if (color_data != 0.0 && (color_data_left == 0.0 || color_data_right == 0.0 || color_data_up == 0.0 || color_data_down == 0.0) && outline)
    {
        obstacle_color.rgb += vec3(0.1);
        obstacle_color.a = min(obstacle_color.a + 0.2, 1.0);
    }

    vec4 fluid_color;
    if (UpdateCounter % 2 == 1)
        fluid_color = get_color(floatBitsToUint(texture(FluidColor_texture0, UV).r));
    else
        fluid_color = get_color(floatBitsToUint(texture(FluidColor_texture1, UV).r));

    vec3 background = chessboard(UV, texture_size, vec3(0.9, 0.9, 0.9), vec3(0.7, 0.7, 0.7));
    vec3 fin = mix(background, obstacle_color.rgb, obstacle_color.a);
    fin = mix(fin, fluid_color.rgb, sqrt(fluid_color.a));
    COLOR = vec4(fin * (light.rgb + ambient.rgb), 1.0); //0.06

    float aspect_correction = float(texture_size.x) / float(texture_size.y);
    float distance_to_center = distance(UV * vec2(aspect_correction, 1.0), mouse_position * vec2(aspect_correction, 1.0));
    if (brush_shape == 0)
    {
        if (distance_to_center < brush_size / float(texture_size.y) && distance_to_center > (brush_size / float(texture_size.y) - 0.001))
        {
            vec3 inverse_color = vec3(1.0) - COLOR.rgb;
            COLOR = vec4(inverse_color, 1.0);
        }
    }
    else if (brush_shape == 1)
    {
        vec2 diff = abs((UV - mouse_position) * vec2(aspect_correction, 1.0));
        float dist_square = max(diff.x, diff.y);
        if (dist_square < brush_size / float(texture_size.y) && dist_square > (brush_size / float(texture_size.y) - 0.001))
        {
            vec3 inverse_color = vec3(1.0) - COLOR.rgb;
            COLOR = vec4(inverse_color, 1.0);
        }
    }

    if (show_particle)
    {
        vec4 light_partical = texture(LightPartical_texture, UV);
        if (light_partical.r != 0.0 || light_partical.g != 0.0)
        {
            COLOR = vec4(1.0, 0.0, 0.0, 1.0);
        }
    }

    if (show_normal)
    {
        float normal_data = texture(Obstacle_texture, UV).b;
        uint normal_uint = floatBitsToUint(normal_data);
        normal_uint = (normal_uint >> 16u) & 0xFFFFu;
        float angle = float(normal_uint) / 65535.0 * 2.0 * PI - PI;
        vec2 normal_dir = vec2(cos(angle), sin(angle));
        if (color_data != 0.0)
            COLOR = vec4(normal_dir * 0.5 + 0.5, 0.0, 1.0);
    }
}