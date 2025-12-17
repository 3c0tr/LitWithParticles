extends Node

@onready var debug_ui = get_node("../UI")  # 根据实际节点路径调整

@export var texture_2drd: Texture2DRD  # 在编辑器中可以拖拽赋值
@export var texture_2drd_blur: Texture2DRD  # 在编辑器中可以拖拽赋值
@export var texture2d_size: Vector2i = Vector2i(1600, 900)
@export var sprite: Sprite2D
@export var FPSlabel: Label
@export var MaterialLabel: RichTextLabel

# 这些参数是光照系统的全局参数
var iteration_mode: int = 0;
var time_cost_goal: float = 4.5
var fixed_iteration_time: int = 1
var RPM: float = 10.0
var jump_deg: int = 4
var rotation_rate: float = 0.0
var z_order_offset: float = 0.0
var draw_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var rotation_timer: float = 0.0 # private
var particle_jump_length: float = 3.0
var particle_jump_times: int = 108
var kalman_process_noise: float = 0.01 # unused
var kalman_measurement_noise: float = 0.1 # unused
var is_particle_transit_on: bool = true
var is_fluid_simulation_on: bool = false
var sun_angle: float = 0.0
var ambient_strength: float = 0.06
var ambient_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var show_outline: bool = true
var show_normal: bool = false
var show_particle: bool = false
var chromatic_dispersion: bool = true
var brghtnegative_feedback: bool = true
var light_penetration: float = 0.333
var emit_material_decay: float = 0.0333
var brightness_diffuse_times: int = 2
var particle_simulation_times: int = 1
var brightness_blend_ratio: float = 0.05


# 这些参数是选择的材质的参数
var roughness: float = 0.5;
var IOR: float = 0.1;
var scatterRate: float = 0.0;
var opacity: float = 0.05;
var metallic: float = 0.0;
var emit_strength: float = 1.0;
var emit_range: float = 0.07;
var emit_scatterL: float = 0.0;
var emit_scatterR: float = 1.0;
var gravityX: float = 0.0;
var gravityY: float = 0.0;
var unique_material: int = 0;

# 画笔的参数
var canvas_brush_size: float = 25
var brush_shape: int = 0
var normal_mode: int = 0
var custom_normal: float = 0.0
var portal_distance: Vector2 = Vector2.ZERO

var rd: RenderingDevice

var DrawLight_shader: RID
var ParticleTransition_shader: RID
var Dim_shader: RID
var Blur_shader: RID
var BrushDraw_shader: RID
var int_to_float_shader: RID
var ReadTexture_shader: RID
var FluidVelocity_shader: RID
var FluidColor_shader: RID

var DrawLight_pipeline: RID
var ParticleTransition_pipeline: RID
var Dim_pipeline: RID
var Blur_pipeline: RID
var BrushDraw_pipeline: RID
var int_to_float_pipeline: RID
var ReadTexture_pipeline: RID
var FluidVelocity_pipeline: RID
var FluidColor_pipeline: RID

var Draw_texture_rd: RID
var Blur_texture_rd: RID
var LightSource_texture_rd: RID
var LightPartical_textures_rd: Array[RID]
var Obstacle_texture_rd: RID
var QuickSampleObstacle_texture_rd: RID
var FluidVelocity_texture_rd: Array[RID]
var FluidColor_texture_rd: Array[RID]

var Draw_int_texture_div1_rd: RID # 全分辨率曝光纹理
var Draw_int_texture_div2_rd: RID # 二分之一分辨率曝光纹理
var Draw_int_texture_div4_rd: RID # 四分之一分辨率曝光纹理
var Draw_int_texture_div8_rd: RID # 八分之一分辨率曝光纹理

var texture_set_for_DrawLight: RID
var texture_set_for_ParticleTransition: RID
var texture_set_for_Dim: RID
var texture_set_for_Blur: RID
var texture_set_for_BrushDraw: RID
var texture_set_for_int_to_float: RID
var texture_set_for_ReadTexture: RID
var texture_set_for_FluidVelocity: RID
var texture_set_for_FluidColor: RID

var Time_buffer: RID  # 添加时间缓冲区
var BrushDraw_buffer: RID  # 添加绘制缓冲区
var ReadTexture_buffer: RID  # 添加读取纹理缓冲区
var FluidSim_buffer: RID  # 添加流体模拟缓冲区
var Brightness_Diffuse_buffer: RID  # 添加亮度扩散缓冲区
var Develop_film_buffer: RID  # 添加胶片缓冲区

var UpdateCounter: int = 0
var current_uv: Vector2 = Vector2.ZERO  # 当前鼠标位置的UV坐标
var last_mouse_uv: Vector2 = Vector2.ZERO  # 存储上一帧鼠标位置
var last_last_mouse_uv: Vector2 = Vector2.ZERO  # 存储上一帧的上一帧鼠标位置
var is_mouse_pressed: bool = false  # 跟踪鼠标按下状态
var is_drawing_line: bool = false
var straight_line_start_uv: Vector2 = Vector2.ZERO
var drawing_line_visualizer: Line2D
var line_brush_color: Color
var line_material_data: int
var line_is_clear: bool

var time_accumulator: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    # 使用主渲染设备而不是本地渲染设备
    rd = RenderingServer.get_rendering_device()
    # rd = RenderingServer.create_local_rendering_device()
    # var test_int: int = 5
    if not rd:
        print("无法获取主渲染设备")
        return
    
    # 加载并编译shader
    var DrawLight_shader_resource := load("res://shaders/ParticleEmission.glsl")
    var ParticleTransition_shader_resource := load("res://shaders/ParticleTransition.glsl")
    # var Dim_shader_resource := load("res://Dim.glsl")
    var Blur_shader_resource := load("res://shaders/BrightnessDiffuse.glsl")
    var BrushDraw_shader_resource := load("res://shaders/BrushDraw.glsl")
    var int_to_float_shader_resource := load("res://shaders/int_to_float.glsl")
    var ReadTexture_shader_resource := load("res://shaders/ReadTexture.glsl")

    var FluidVelocity_shader_resource := load("res://shaders/FluidVelocityField.glsl")
    var FluidColorField_shader_resource := load("res://shaders/FluidColorField.glsl")

    DrawLight_shader = rd.shader_create_from_spirv(DrawLight_shader_resource.get_spirv())
    ParticleTransition_shader = rd.shader_create_from_spirv(ParticleTransition_shader_resource.get_spirv())
    # Dim_shader = rd.shader_create_from_spirv(Dim_shader_resource.get_spirv())
    Blur_shader = rd.shader_create_from_spirv(Blur_shader_resource.get_spirv())
    BrushDraw_shader = rd.shader_create_from_spirv(BrushDraw_shader_resource.get_spirv())
    int_to_float_shader = rd.shader_create_from_spirv(int_to_float_shader_resource.get_spirv())
    ReadTexture_shader = rd.shader_create_from_spirv(ReadTexture_shader_resource.get_spirv())
    FluidVelocity_shader = rd.shader_create_from_spirv(FluidVelocity_shader_resource.get_spirv())
    FluidColor_shader = rd.shader_create_from_spirv(FluidColorField_shader_resource.get_spirv())

    DrawLight_pipeline = rd.compute_pipeline_create(DrawLight_shader)
    ParticleTransition_pipeline = rd.compute_pipeline_create(ParticleTransition_shader)
    # Dim_pipeline = rd.compute_pipeline_create(Dim_shader)
    Blur_pipeline = rd.compute_pipeline_create(Blur_shader)
    BrushDraw_pipeline = rd.compute_pipeline_create(BrushDraw_shader)
    int_to_float_pipeline = rd.compute_pipeline_create(int_to_float_shader)
    ReadTexture_pipeline = rd.compute_pipeline_create(ReadTexture_shader)
    FluidVelocity_pipeline = rd.compute_pipeline_create(FluidVelocity_shader)
    FluidColor_pipeline = rd.compute_pipeline_create(FluidColor_shader)

    init_Time_buffer()
    init_BrushDraw_buffer()
    init_ReadTexture_buffer()
    init_FluidSim_buffer()
    init_Brightness_Diffuse_buffer()
    init_Develop_film_buffer()

    Draw_texture_rd = init_textureRD(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT)
    Blur_texture_rd = init_textureRD(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT)

    #Texture[127:0] = [127:96][95:64][63:32][31:0]
    #光粒子图 64位x2 交替读写 包含光照的颜色信息以及光照角度与发射体类型[方向 方向 发光距离 生命][保留 R G B]
    #如果发光材质发出的光粒子未能在一帧之内结束生命，将被暂存到这张纹理中，后续帧将继续模拟其生命
    LightPartical_textures_rd = []
    for i in range(2):
        LightPartical_textures_rd.append(init_textureRD(RenderingDevice.DATA_FORMAT_R32G32_SFLOAT))
    #障碍物图 128位 包含材质的详细信息 [右散射角度 左散射角度 发光距离 金属度][法向 法向 保留 保留][折射率 散射率 粗糙度 材质标志位][透明度 R G B] 
    #因为gdshader的奇怪设计, isampler2D与usampler2D有诡异的问题, Texture2DRD也不支持整数纹理，所以格式选择浮点
    Obstacle_texture_rd = init_textureRD(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT)    
    #快速采样障碍物图 8位 仅包含材质标志位
    QuickSampleObstacle_texture_rd = init_textureRD(RenderingDevice.DATA_FORMAT_R8_UINT)  
    #流体速度图 128位x2 交替读写 包含流体的速度信息 [vortex][density][Y][X]
    for i in range(2):
        FluidVelocity_texture_rd.append(init_textureRD(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT))
    #流体颜色图 128位x2 交替读写 包含流体的颜色信息 [A][B][G][R]
    for i in range(2):
        FluidColor_texture_rd.append(init_textureRD(RenderingDevice.DATA_FORMAT_R32_SFLOAT))

    Draw_int_texture_div1_rd = init_int_textureRD(texture2d_size)
    Draw_int_texture_div2_rd = init_int_textureRD(texture2d_size / 2)
    Draw_int_texture_div4_rd = init_int_textureRD(texture2d_size / 4)
    Draw_int_texture_div8_rd = init_int_textureRD(texture2d_size / 8)

    texture_set_for_DrawLight = _create_DrawLight_uniform_set(DrawLight_shader)
    texture_set_for_ParticleTransition = _create_ParticleTransition_uniform_set(ParticleTransition_shader)
    # texture_set_for_Dim = _create_dim_uniform_set(Dim_shader)
    texture_set_for_Blur = _create_blur_uniform_set(Blur_shader)
    texture_set_for_BrushDraw = _create_brushdraw_uniform_set(BrushDraw_shader)
    texture_set_for_int_to_float = _create_int_to_float_uniform_set(int_to_float_shader)
    texture_set_for_ReadTexture = _create_ReadTexture_uniform_set(ReadTexture_shader)
    texture_set_for_FluidVelocity = _create_FluidVelocity_uniform_set(FluidVelocity_shader)
    texture_set_for_FluidColor = _create_FluidColor_uniform_set(FluidColor_shader)

    texture_2drd.texture_rd_rid = Draw_texture_rd
    # texture_2drd_blur.texture_rd_rid = Obstacle_texture_rd

    # rd.texture_clear(FluidVelocity_texture_rd[0], Color(1, 0, 0, 0), 0, 1, 0, 1)
    # rd.texture_clear(FluidVelocity_texture_rd[1], Color(1, 0, 0, 0), 0, 1, 0, 1)

    if (sprite):
        # print("sprite.material:", sprite.material)
        var material := sprite.material
        material.set_shader_parameter("color_scale", 1.0)

        var obstacle_texture_res := Texture2DRD.new()
        obstacle_texture_res.texture_rd_rid = Obstacle_texture_rd
        material.set_shader_parameter("Obstacle_texture", obstacle_texture_res)
        # 光粒子图
        var light_partical_texture_res := Texture2DRD.new()
        light_partical_texture_res.texture_rd_rid = LightPartical_textures_rd[0]
        material.set_shader_parameter("LightPartical_texture", light_partical_texture_res)
        # 流体颜色图
        var fluid_color0_texture_res := Texture2DRD.new()
        fluid_color0_texture_res.texture_rd_rid = FluidColor_texture_rd[0]
        material.set_shader_parameter("FluidColor_texture0", fluid_color0_texture_res)
        # 流体颜色图
        var fluid_color1_texture_res := Texture2DRD.new()
        fluid_color1_texture_res.texture_rd_rid = FluidColor_texture_rd[1]
        material.set_shader_parameter("FluidColor_texture1", fluid_color1_texture_res)
    # simple_test()

func init_textureRD(DataFormat: RenderingDevice.DataFormat) -> RID:
    var tf : RDTextureFormat = RDTextureFormat.new()
    tf.format = DataFormat
    tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
    tf.width = texture2d_size.x
    tf.height = texture2d_size.y
    tf.depth = 1
    tf.array_layers = 1
    tf.mipmaps = 1
    tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
    
    var texture_rd = rd.texture_create(tf, RDTextureView.new(), [])
    rd.texture_clear(texture_rd, Color(0, 0, 0, 0), 0, 1, 0, 1)
    return texture_rd

func init_int_textureRD(size: Vector2i) -> RID:
    var tf : RDTextureFormat = RDTextureFormat.new()
    tf.format = RenderingDevice.DATA_FORMAT_R32_SINT
    tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
    tf.width = size.x
    tf.height = size.y
    tf.depth = 1
    tf.array_layers = 1
    tf.mipmaps = 1
    tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
    
    var texture_rd = rd.texture_create(tf, RDTextureView.new(), [])
    rd.texture_clear(texture_rd, Color(0, 0, 0, 65535), 0, 1, 0, 1)
    return texture_rd

# 添加浮点数缓冲区初始化函数
func init_Time_buffer():
    # Data structure must match DrawLight(): int, float, int, float, float, vec3
    var int_data := PackedInt32Array([0]) # UpdateCounter
    var jump_times := PackedInt32Array([108]) # jump_times
    var float_data := PackedFloat32Array([0.0]) # rotation_timer
    var flag_data := PackedInt32Array([0]) # flag
    
    var z := 0.0
    var sun_light_dir := 0.3
    var jump_length := 3.0
    var light_penetration := 0.333
    var emit_material_decay := 0.0111
    var sun_light_color := [1.0, 1.0, 1.0]
    var other_floats := PackedFloat32Array([z, sun_light_dir, jump_length, light_penetration, emit_material_decay] + sun_light_color)
    
    # Combine byte arrays
    var combined_data := int_data.to_byte_array() \
    + jump_times.to_byte_array() \
    + float_data.to_byte_array() \
    + flag_data.to_byte_array() \
    + other_floats.to_byte_array()
    
    Time_buffer = rd.storage_buffer_create(combined_data.size())
    rd.buffer_update(Time_buffer, 0, combined_data.size(), combined_data)

func init_BrushDraw_buffer():
    # 创建包含 vec4(颜色) + vec2(位置) + float(大小) 的数据
    # vec4: 4个float, vec2: 2个float, float: 1个float = 总共7个float
    
    # 将整数转换为浮点数（保持位模式不变）
    # var alpha_as_float = int_to_float_bits(integer_data)
    
    var brush_color = [1.0, 0.0, 0.0, 0.0]  # 红色 RGB + 整数数据作为Alpha
    var brush_position_1 = [0.5, 0.5]         # 归一化位置 (0-1)
    var brush_position_2 = [0.5, 0.5]         # 归一化位置 (0-1)
    var brush_position_3 = [0.5, 0.5]         # 归一化位置 (0-1)
    var brush_size = 50.0                   # 笔刷大小
    
    var input_data := PackedFloat32Array(brush_color + brush_position_1 + brush_position_2 + brush_position_3 + [brush_size])
    var direction_data = PackedFloat32Array([0.0, 0.0]).to_byte_array()
    var UpdateCounter_data = PackedInt32Array([UpdateCounter]).to_byte_array()
    
    var brush_shape_data = PackedInt32Array([0]).to_byte_array()
    var normal_mode_data = PackedInt32Array([0]).to_byte_array()
    var custom_normal_data = PackedFloat32Array([0.0]).to_byte_array()
    var portal_distance_data = PackedFloat32Array([0.0, 0.0]).to_byte_array()

    # 要传递的32位整数数据
    var integer_data: int = 12345678  # 你的整数数据
    var material_bytes = PackedInt32Array([integer_data])
    var encoded_data: PackedByteArray = EncodeMaterialData()
    
    # 移除 padding，因为加入 brush_position_3 后，数据已经对齐到 16 字节
    # vec4(16) + vec2(8) + vec2(8) + vec2(8) + float(4) + int(4) = 48 bytes (16 * 3)
    # padding.resize(8) 
    var combined_data = input_data.to_byte_array() + material_bytes.to_byte_array() + encoded_data + direction_data + UpdateCounter_data + brush_shape_data + normal_mode_data + custom_normal_data + portal_distance_data
    BrushDraw_buffer = rd.storage_buffer_create(combined_data.size())
    rd.buffer_update(BrushDraw_buffer, 0, combined_data.size(), combined_data)

func init_FluidSim_buffer():
    var combined_data := PackedInt32Array([0, 0, 0, 0]).to_byte_array() + PackedFloat32Array([0.0, 0.0, 0.0, 0.0]).to_byte_array()
    FluidSim_buffer = rd.storage_buffer_create(combined_data.size())
    rd.buffer_update(FluidSim_buffer, 0, combined_data.size(), combined_data)

func init_Develop_film_buffer():
    var combined_data := PackedFloat32Array([kalman_process_noise, kalman_measurement_noise, 0.0, 0.0]).to_byte_array()
    Develop_film_buffer = rd.storage_buffer_create(combined_data.size())
    rd.buffer_update(Develop_film_buffer, 0, combined_data.size(), combined_data)

func init_Brightness_Diffuse_buffer():
    var combined_data := PackedFloat32Array([0.0, 0.0, 0.0, 0.0]).to_byte_array()
    Brightness_Diffuse_buffer = rd.storage_buffer_create(combined_data.size())
    rd.buffer_update(Brightness_Diffuse_buffer, 0, combined_data.size(), combined_data)

func init_ReadTexture_buffer():
    var uv = [0.5, 0.5]
    var read_back_data = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    var combined_data := PackedFloat32Array(uv + read_back_data).to_byte_array()
    ReadTexture_buffer = rd.storage_buffer_create(combined_data.size())
    rd.buffer_update(ReadTexture_buffer, 0, combined_data.size(), combined_data)

# 将32位整数转换为浮点数（保持位模式）
func int_to_float_bits(value: int) -> float:
    var bytes = PackedByteArray()
    bytes.resize(4)
    bytes.encode_s32(0, value)
    return bytes.decode_float(0)

# 将浮点数转换回32位整数（保持位模式）
func float_to_int_bits(value: float) -> int:
    var bytes = PackedByteArray()
    bytes.resize(4)
    bytes.encode_float(0, value)
    return bytes.decode_s32(0)

func DrawLight(index: int):
    rd.capture_timestamp("EmitLight%d Begin" % index)
    # 更新浮点数缓冲区（如果需要动态更新）
    # var startup_time = (Time.get_ticks_msec() / 1000.0) * RPM
    rotation_timer += rotation_rate * 0.1
    # rotation_timer += 0.00390625 * float(jump_deg)# 0.00606; # Magic number for reason idk, i get it though human based machine learning, it just work.
    # var cnt = UpdateCounter % 2
    # print(cnt)
    rd.texture_clear(Draw_int_texture_div1_rd, Color(0, 0, 0, 65535), 0, 1, 0, 1)
    rd.texture_clear(Draw_int_texture_div2_rd, Color(0, 0, 0, 65535), 0, 1, 0, 1)
    rd.texture_clear(Draw_int_texture_div4_rd, Color(0, 0, 0, 65535), 0, 1, 0, 1)
    rd.texture_clear(Draw_int_texture_div8_rd, Color(0, 0, 0, 65535), 0, 1, 0, 1)
    
    # 使用混合数据类型：整数 + 浮点数
    var int_data := PackedInt32Array([UpdateCounter + index])
    var jump_times := PackedInt32Array([particle_jump_times])
    # var float_data := PackedFloat32Array([rotation_timer * RPM])#([startup_time - floor(startup_time)])
    var float_data := PackedFloat32Array([rotation_timer])
    var flag: int = int(is_particle_transit_on) + (int(is_fluid_simulation_on) << 1) + (int(chromatic_dispersion) << 2) + (int(brghtnegative_feedback) << 3)
    var z := z_order_offset * 0.1
    var sun_light_dir := 0.3
    var sun_light_color := [1.0, 1.0, 1.0]
    var jump_length := particle_jump_length
    var combined_data := int_data.to_byte_array() + jump_times.to_byte_array() + float_data.to_byte_array() \
    + PackedInt32Array([flag]).to_byte_array() \
    + PackedFloat32Array([z, sun_light_dir, jump_length, light_penetration, emit_material_decay] + sun_light_color).to_byte_array()
    
    rd.buffer_update(Time_buffer, 0, combined_data.size(), combined_data)
    rd.texture_clear(LightPartical_textures_rd[(UpdateCounter + index) % 2], Color(0, 0, 0, 0), 0, 1, 0, 1)
    
    # 执行计算
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, DrawLight_pipeline)
    rd.compute_list_bind_uniform_set(compute_list, texture_set_for_DrawLight, 0)
    
    # 计算工作组数量（基于纹理尺寸）
    var groups_x: int = int((texture2d_size.x + 7) / 8.0)  # 向上取整
    var groups_y: int = int((texture2d_size.y + 7) / 8.0)  # 向上取整

    # var total_pixels = texture2d_size.x * texture2d_size.y
    # var groups_x = (total_pixels + 63) / 64

    rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
    rd.compute_list_end()
    rd.capture_timestamp("EmitLight%d End" % index)

func ParticleTransition(index: int):
    rd.capture_timestamp("ParticleTransition%d Begin" % index)
    # 执行计算
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, ParticleTransition_pipeline)
    rd.compute_list_bind_uniform_set(compute_list, texture_set_for_ParticleTransition, 0)
    
    # 计算工作组数量（基于纹理尺寸）
    var groups_x: int = int((texture2d_size.x + 7) / 8.0)  # 向上取整
    var groups_y: int = int((texture2d_size.y + 7) / 8.0)  # 向上取整

    rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
    rd.compute_list_end()
    rd.capture_timestamp("ParticleTransition%d End" % index)

func Dim():
    # 更新浮点数缓冲区（如果需要动态更新）
    var input_data := PackedFloat32Array([randf()])
    rd.buffer_update(Time_buffer, 0, input_data.to_byte_array().size(), input_data.to_byte_array())
    
    # 执行计算
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, Dim_pipeline)
    rd.compute_list_bind_uniform_set(compute_list, texture_set_for_Dim, 0)
    
    # 计算工作组数量（基于纹理尺寸）
    var groups_x: int = int((texture2d_size.x + 7) / 8.0)  # 向上取整
    var groups_y: int = int((texture2d_size.y + 7) / 8.0)  # 向上取整
    rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
    rd.compute_list_end()

func Blur(index: int, write_negetive_feedback: bool = false):
    rd.capture_timestamp("Blur%d Begin" % index)
    var write_negetive_feedback_val: float = 0.0
    if write_negetive_feedback and brghtnegative_feedback:
        write_negetive_feedback_val = 1.0
    var input_data := PackedFloat32Array([write_negetive_feedback_val, 0.0, 0.0, 0.0])
    rd.buffer_update(Brightness_Diffuse_buffer, 0, input_data.to_byte_array().size(), input_data.to_byte_array())
    # 执行计算
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, Blur_pipeline)
    rd.compute_list_bind_uniform_set(compute_list, texture_set_for_Blur, 0)
    
    # 计算工作组数量（基于纹理尺寸）
    var groups_x: int = int((texture2d_size.x + 7) / 8.0)  # 向上取整
    var groups_y: int = int((texture2d_size.y + 7) / 8.0)  # 向上取整
    rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
    rd.compute_list_end()
    rd.capture_timestamp("Blur%d End" % index)

func BrushDraw(uv1: Vector2, uv2: Vector2, uv3: Vector2, color: Color, brush_size: float, isClear: bool, draw_witch: int, direction: Vector2):
    # 直接传递RGB颜色和材质类型，不再通过浮点数转换
    var brush_color = [color.r * emit_strength, color.g  * emit_strength, color.b  * emit_strength, opacity]  # Alpha通道暂时设为0，将在着色器中设置
    var brush_position_1 = [uv1.x, uv1.y]         # 归一化位置 (0-1)
    var brush_position_2 = [uv2.x, uv2.y]         # 归一化位置 (0-1)
    var brush_position_3 = [uv3.x, uv3.y]         # 归一化位置 (0-1)
    # print(brush_position_1, brush_position_2, brush_position_3)
    
    # 创建包含整型材质类型的数据数组
    var input_data := PackedFloat32Array(brush_color + brush_position_1 + brush_position_2 + brush_position_3 + [brush_size])

    var encoded_data: PackedByteArray
    if isClear:
        encoded_data = PackedFloat32Array([0.0, 0.0, 0.0, 0.0]).to_byte_array()
    else:
        encoded_data = EncodeMaterialData()

    var direction_data = PackedFloat32Array([direction.x, direction.y]).to_byte_array()
    var UpdateCounter_data = PackedInt32Array([UpdateCounter]).to_byte_array()
    
    var brush_shape_data = PackedInt32Array([brush_shape]).to_byte_array()
    var normal_mode_data = PackedInt32Array([normal_mode]).to_byte_array()
    var custom_normal_data = PackedFloat32Array([custom_normal]).to_byte_array()
    var portal_distance_data = PackedFloat32Array([portal_distance.x, portal_distance.y]).to_byte_array()

    # 添加整型材质类型到缓冲区（需要转换为字节数组）
    var material_bytes = PackedInt32Array([draw_witch]).to_byte_array()
    
    # 移除 padding，因为加入 brush_position_3 后，数据已经对齐到 16 字节
    var combined_data = input_data.to_byte_array() + material_bytes + encoded_data + direction_data + UpdateCounter_data + brush_shape_data + normal_mode_data + custom_normal_data + portal_distance_data
    
    rd.buffer_update(BrushDraw_buffer, 0, combined_data.size(), combined_data)

    # 执行计算
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, BrushDraw_pipeline)
    rd.compute_list_bind_uniform_set(compute_list, texture_set_for_BrushDraw, 0)
    
    # 计算工作组数量（基于纹理尺寸）
    var groups_x: int = int((texture2d_size.x + 7) / 8.0)  # 向上取整
    var groups_y: int = int((texture2d_size.y + 7) / 8.0)  # 向上取整
    rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
    rd.compute_list_end()

func int_to_float(index: int):
    rd.capture_timestamp("int_to_float%d Begin" % index)
    var combined_data := PackedFloat32Array([kalman_process_noise, kalman_measurement_noise, brightness_blend_ratio, 0.0]).to_byte_array()
    rd.buffer_update(Develop_film_buffer, 0, combined_data.size(), combined_data)
    # 执行计算
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, int_to_float_pipeline)
    rd.compute_list_bind_uniform_set(compute_list, texture_set_for_int_to_float, 0)
    
    # 计算工作组数量（基于纹理尺寸）
    var groups_x: int = int((texture2d_size.x + 7) / 8.0)  # 向上取整
    var groups_y: int = int((texture2d_size.y + 7) / 8.0)  # 向上取整
    rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
    rd.compute_list_end()
    rd.capture_timestamp("int_to_float%d End" % index)

func ReadTexture(uv: Vector2):
    rd.capture_timestamp("ReadTexture Begin")

    # Update the UV coordinates in the buffer
    var uv_data = PackedFloat32Array([uv.x, uv.y])
    var combine_data = uv_data.to_byte_array()
    rd.buffer_update(ReadTexture_buffer, 0, combine_data.size(), combine_data)

    # Execute the compute shader
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, ReadTexture_pipeline)
    # Bind the uniform set containing both the texture and the buffer
    rd.compute_list_bind_uniform_set(compute_list, texture_set_for_ReadTexture, 0)
    rd.compute_list_dispatch(compute_list, 1, 1, 1)
    rd.compute_list_end()

    # Submit to the GPU and wait for it to finish
    # rd.submit()
    # rd.sync()

    # Read back the data from the GPU
    var buffer_data = rd.buffer_get_data(ReadTexture_buffer)
    # The first 2 floats are UVs, so we skip them. We are interested in the next 4 floats (RGBA).
    var result = buffer_data.to_float32_array().slice(2, 6)

    rd.capture_timestamp("ReadTexture End")
    
    return result

func FluidVelocitySim(add: int):
    rd.capture_timestamp("FluidVelocitySim%d Begin" % add)
    var combined_data := PackedInt32Array([UpdateCounter + add, 0, 0, 0]).to_byte_array() + PackedFloat32Array([0.0, 0.0, 0.0, 0.0]).to_byte_array()
    rd.buffer_update(FluidSim_buffer, 0, combined_data.size(), combined_data)
    # 执行计算
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, FluidVelocity_pipeline)
    rd.compute_list_bind_uniform_set(compute_list, texture_set_for_FluidVelocity, 0)
    
    # 计算工作组数量（基于纹理尺寸）
    var groups_x: int = int((texture2d_size.x + 7) / 8.0)  # 向上取整
    var groups_y: int = int((texture2d_size.y + 7) / 8.0)  # 向上取整
    rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
    rd.compute_list_end()
    rd.capture_timestamp("FluidVelocitySim%d End" % add)

func FluidColorSim(add: int):
    rd.capture_timestamp("FluidColorSim%d Begin" % add)
    var combined_data := PackedInt32Array([UpdateCounter + add, 0, 0, 0]).to_byte_array() + PackedFloat32Array([0.0, 0.0, 0.0, 0.0]).to_byte_array()
    rd.buffer_update(FluidSim_buffer, 0, combined_data.size(), combined_data)
    # 执行计算
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, FluidColor_pipeline)
    rd.compute_list_bind_uniform_set(compute_list, texture_set_for_FluidColor, 0)
    
    # 计算工作组数量（基于纹理尺寸）
    var groups_x: int = int((texture2d_size.x + 7) / 8.0)  # 向上取整
    var groups_y: int = int((texture2d_size.y + 7) / 8.0)  # 向上取整
    rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
    rd.compute_list_end()
    rd.capture_timestamp("FluidColorSim%d End" % add)

func clear_fluid_texture():
    rd.texture_clear(FluidColor_texture_rd[0], Color(0, 0, 0, 65535), 0, 1, 0, 1)
    rd.texture_clear(FluidColor_texture_rd[1], Color(0, 0, 0, 65535), 0, 1, 0, 1)
    rd.texture_clear(FluidVelocity_texture_rd[0], Color(0, 0, 0, 65535), 0, 1, 0, 1)
    rd.texture_clear(FluidVelocity_texture_rd[1], Color(0, 0, 0, 65535), 0, 1, 0, 1)

func _input(event):
    if event is InputEventMouseButton and current_uv > Vector2.ZERO and current_uv < Vector2(1.0, 1.0):
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            canvas_brush_size = clamp(canvas_brush_size * 1.1, 2.0, 1024.0)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            canvas_brush_size = clamp(canvas_brush_size / 1.1, 2.0, 1024.0)

func EncodeMaterialData() -> PackedByteArray:
    var data = PackedByteArray()
    data.resize(16)

    # Bytes 0, 1, 2: draw_color (r, g, b)
    data[2] = int(round(draw_color.r * 255.0))
    data[1] = int(round(draw_color.g * 255.0))
    data[0] = int(round(draw_color.b * 255.0))

    # Byte 3: opacity
    data[3] = int(round(opacity * 255.0))

    # Byte 4: empty
    data[4] = 0
    if (emit_strength > 0):
        data[4] = data[4] | 0x01
    if (opacity != 0.0):
        data[4] = data[4] | 0x02
    if (unique_material == 1):
        data[4] = data[4] | 0x04
    elif (unique_material == 2):
        data[4] = data[4] | 0x08

    # Byte 5: roughness
    data[5] = int(round(roughness * 255.0))

    # Byte 6: scatterRate
    data[6] = int(round(scatterRate * 255.0))

    # Byte 7: IOR - Mapped from [1.0, 2.0] to [0, 255]
    if (opacity > 0.0):
        data[7] = int(round((IOR) * 255.0))
    else:
        data[7] = 0

    # Bytes 8-12: empty
    data[8] = int(round(gravityX * 255.0))
    data[9] = int(round(gravityY * 255.0))
    data[10] = 0
    data[11] = 0
    data[12] = int(round(metallic * 255.0))

    # Byte 13: emit_range
    data[13] = int(round(emit_range * 255.0))

    # Byte 14: emit_scatterL
    data[14] = int(round(emit_scatterL * 255.0))

    # Byte 15: emit_scatterR
    data[15] = int(round(emit_scatterR * 255.0))

    return data


func DecodeMaterialData(encoded_floats: PackedFloat32Array) -> String:
    if not encoded_floats or encoded_floats.size() != 4:
        return "正在读取..."

    var data: PackedByteArray = encoded_floats.to_byte_array()
    if data.size() != 16:
        return "解码错误：字节大小不匹配 (%d)" % data.size()

    # 根据 EncodeMaterialData 的逻辑解包字节
    var r = data[2] / 255.0
    var g = data[1] / 255.0
    var b = data[0] / 255.0
    var decoded_opacity = data[3] / 255.0

    var flag = int(data[4])
    
    var decoded_roughness = data[5] / 255.0
    var decoded_scatterRate = data[6] / 255.0
    # 假设 IOR 在 UI 中范围是 0.0-1.0
    var decoded_IOR = data[7] / 255.0

    var decoded_metallic = data[12] / 255.0

    # 从第10和11字节解码16位无符号整数代表的角度
    # GLSL中角度存放在 .z 分量的高16位, 对应字节10和11
    var angle_encoded = (data[11] << 8) | data[10]
    # 将解码出的整数从 [0, 65535] 范围映射回 [-PI, PI] 的弧度
    var angle_rad = (float(angle_encoded) / 65535.0) * 2.0 * PI - PI
    # 将弧度转换为度数以便显示
    var angle_deg = rad_to_deg(angle_rad)

    var decoded_emit_range = data[13] * 8
    var decoded_emit_scatterL = data[14] / 255.0
    var decoded_emit_scatterR = data[15] / 255.0

    # 从第8和9字节解码16位有符号整数代表的重力
    # GLSL中重力存放在 .x 分量的高16位, 对应字节8和9
    var gravity_encoded_x = data[8] / 255.0
    var gravity_encoded_y = data[9] / 255.0
    # 将解码出的整数从 [-127, 127] 范围映射回 [-1.0, 1.0]
    var decoded_gravityX = (float(gravity_encoded_x) - 0.5) * 2048
    var decoded_gravityY = (float(gravity_encoded_y) - 0.5) * 2048

    var temp_string = ""
    if (TranslationServer.get_locale() == "zh" || TranslationServer.get_locale() == "zh_CN"):
        if (flag & 0x04 > 0):
            temp_string += "引力方向: (%.2f, %.2f)" % [decoded_gravityX, decoded_gravityY]
        elif (flag & 0x08 > 0):
            temp_string += "传送方向: (%.0fpx, %.0fpx)" % [decoded_gravityX, decoded_gravityY]
    else:
        if (flag & 0x04 > 0):
            temp_string += "Gravity Direction: (%.2f, %.2f)" % [decoded_gravityX, decoded_gravityY]
        elif (flag & 0x08 > 0):
            temp_string += "Teleport Direction: (%.0fpx, %.0fpx)" % [decoded_gravityX, decoded_gravityY]

    # 格式化为用于显示的字符串
    var color_hex = Color(r, g, b).to_html()
    var result_string = ""
    if (TranslationServer.get_locale() == "zh" || TranslationServer.get_locale() == "zh_CN"):
        result_string = """鼠标悬停处材质信息:- [color=#{color_hex}]■[/color] 颜色 (RGB): (%.2f, %.2f, %.2f)- 透明度: %.2f- 粗糙度: %.2f- 散射率: %.2f- 折射率 (IOR): %.2f- 金属度: %.2f- 法线角度: %.2f°- 发光范围: %dpx- 发光散射 (L/R): (%.2f, %.2f)- %s
""" % [
        r, g, b,
        decoded_opacity,
        decoded_roughness,
        decoded_scatterRate,
        decoded_IOR,
        decoded_metallic,
        angle_deg,
        decoded_emit_range,
        decoded_emit_scatterL, decoded_emit_scatterR,
        temp_string
    ]
    else:
        result_string = """Material Info:- [color=#{color_hex}]■[/color] Color (RGB): (%.2f, %.2f, %.2f)- Opacity: %.2f- Roughness: %.2f- Scatter Rate: %.2f- IOR: %.2f- Metallic: %.2f- Normal Angle: %.2f°- Emit Range: %.2f- Emit Scatter (L/R): (%.2f, %.2f)- %s
""" % [
        r, g, b,
        decoded_opacity,
        decoded_roughness,
        decoded_scatterRate,
        decoded_IOR,
        decoded_metallic,
        angle_deg,
        decoded_emit_range,
        decoded_emit_scatterL, decoded_emit_scatterR,
        temp_string
    ]
    
    return result_string.format({"color_hex": color_hex})

# 在 _process 函数中添加鼠标处理
func _process(delta: float) -> void:
# 检查鼠标按钮持续按下状态
    var is_left_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
    var is_right_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

    var mouse_pos = get_viewport().get_mouse_position()
    current_uv = (mouse_pos - Vector2(28.0, 28.0)) / Vector2(texture2d_size.x, texture2d_size.y)

    if not drawing_line_visualizer:
        drawing_line_visualizer = Line2D.new()
        drawing_line_visualizer.width = 1.0
        drawing_line_visualizer.default_color = Color(1.0, 1.0, 1.0, 0.8)
        if sprite:
            sprite.get_parent().add_child(drawing_line_visualizer)

    if Input.is_key_pressed(KEY_X):
        var fixed_y = last_mouse_uv.y * texture2d_size.y + 28.0
        var mouse_pos_now = get_viewport().get_mouse_position()
        get_viewport().warp_mouse(Vector2(mouse_pos_now.x, fixed_y))
        current_uv.y = last_mouse_uv.y
    elif Input.is_key_pressed(KEY_Y):
        var fixed_x = last_mouse_uv.x * texture2d_size.x + 28.0
        var mouse_pos_now = get_viewport().get_mouse_position()
        get_viewport().warp_mouse(Vector2(fixed_x, mouse_pos_now.y))
        current_uv.x = last_mouse_uv.x

    if is_left_pressed or is_right_pressed:
        var special_allow: bool = false
        var brush_color: Color
        var material_data: int
        var isClear: bool
        
        if is_left_pressed:
            # 左键绘制
            brush_color = draw_color
            material_data = 0x00000001
            isClear = false
        else:  # is_right_pressed
            # 右键擦除
            brush_color = Color(0.0, 0.0, 0.0, 0.0)
            material_data = 0x00000000
            isClear = true

        # 如果是刚按下鼠标，初始化上一帧位置为当前位置
        if not is_mouse_pressed:
            # print("first press")
            last_last_mouse_uv = current_uv
            last_mouse_uv = current_uv
            is_mouse_pressed = true
            special_allow = true
            
            if Input.is_key_pressed(KEY_CTRL):
                is_drawing_line = true
                straight_line_start_uv = current_uv
                line_brush_color = brush_color
                line_material_data = material_data
                line_is_clear = isClear
            else:
                is_drawing_line = false
        
        # 按下ALT键时，绘制流体模拟纹理, 否则绘制普通纹理
        # current_uv = Vector2(0.1, 0.1)
        # last_mouse_uv = Vector2(0.5, 0.5)
        # last_last_mouse_uv = Vector2(0.3, 0.4)
        
        if is_drawing_line:
            var start_pos = straight_line_start_uv * Vector2(texture2d_size) + Vector2(28.0, 28.0)
            var end_pos = current_uv * Vector2(texture2d_size) + Vector2(28.0, 28.0)
            drawing_line_visualizer.points = [start_pos, end_pos]
        else:
            drawing_line_visualizer.points = []
            if (current_uv - last_mouse_uv).length() > 0.003 or special_allow:
                special_allow = false
                # print(current_uv, last_mouse_uv, last_last_mouse_uv)
                if current_uv.x > 0.0 and current_uv.x < 1.0 and current_uv.y > 0.0 and current_uv.y < 1.0:
                    if Input.is_key_pressed(KEY_ALT) == false:
                        BrushDraw(current_uv, last_mouse_uv, last_last_mouse_uv, brush_color, canvas_brush_size, isClear, 0, Vector2(0.0, 0.0))
                    else:
                        BrushDraw(current_uv, last_mouse_uv, last_last_mouse_uv, brush_color, canvas_brush_size, isClear, 1, (current_uv - last_mouse_uv).normalized())
                last_last_mouse_uv = last_mouse_uv
                last_mouse_uv = current_uv
    else:
        # 鼠标松开时重置状态
        if is_mouse_pressed and is_drawing_line:
            drawing_line_visualizer.points = []
            if Input.is_key_pressed(KEY_ALT) == false:
                BrushDraw(current_uv, straight_line_start_uv, straight_line_start_uv, line_brush_color, canvas_brush_size, line_is_clear, 0, Vector2(0.0, 0.0))
            else:
                BrushDraw(current_uv, straight_line_start_uv, straight_line_start_uv, line_brush_color, canvas_brush_size, line_is_clear, 1, (current_uv - straight_line_start_uv).normalized())
            is_drawing_line = false
            
        is_mouse_pressed = false
        last_mouse_uv = current_uv

    UpdateCounter += 1

    for i in range(particle_simulation_times):
        DrawLight(i)
    
        if (is_particle_transit_on):
            ParticleTransition(i)

        int_to_float(i)

    # var brightness_diffuse_times = 2
    for i in range(brightness_diffuse_times):
        Blur(i, i == brightness_diffuse_times - 1)

    if (is_fluid_simulation_on):
        var iter: int = 3
        FluidColorSim(0)
        for i in range(iter):
            FluidVelocitySim(i)

    if (sprite):
        sprite.material.set_shader_parameter("mouse_position", current_uv)
        sprite.material.set_shader_parameter("brush_size", canvas_brush_size)
        sprite.material.set_shader_parameter("UpdateCounter", jump_deg)
        sprite.material.set_shader_parameter("brush_shape", brush_shape)
        sprite.material.set_shader_parameter("sun_angle", sun_angle)
        sprite.material.set_shader_parameter("ambient", ambient_color * ambient_strength)
        sprite.material.set_shader_parameter("outline", show_outline)
        sprite.material.set_shader_parameter("show_particle", show_particle)
        sprite.material.set_shader_parameter("show_normal", show_normal)

    if (current_uv.x >= 0.0 and current_uv.x <= 1.0 and current_uv.y >= 0.0 and current_uv.y <= 1.0):
        var read_back_data = ReadTexture(current_uv)
        var decoded_string = DecodeMaterialData(read_back_data)
        MaterialLabel.text = decoded_string
    else:
        MaterialLabel.text = "..."

    var time_coast = print_lighting_system_time_coast(delta)
    time_accumulator += delta
    if time_accumulator > 0.05:
        debug_ui._on_time_coast_changed(time_coast)
        time_accumulator = 0.0


func print_lighting_system_time_coast(delta: float) -> Dictionary:
    var current_fps = 1.0 / delta if delta > 0.0 else 0.0
    var result: Dictionary = {}

    var timestamps = {}
    var count = rd.get_captured_timestamps_count()
    for i in range(count):
        timestamps[rd.get_captured_timestamp_name(i)] = rd.get_captured_timestamp_gpu_time(i)

    var durations = {}
    for name in timestamps.keys():
        if name.ends_with(" End"):
            var base_name = name.trim_suffix(" End")
            var begin_name = base_name + " Begin"
            if timestamps.has(begin_name):
                var end_time = timestamps[name]
                var begin_time = timestamps[begin_name]
                if end_time > 0 and begin_time > 0:
                    durations[base_name] = (end_time - begin_time) / 1000000.0

    # if durations.is_empty():
    #     FPSlabel.text = "%s:%.1f|Light:%.2f" % [tr("FPS"), current_fps, total_gpu_ms]
    #     return result

    var total_gpu_ms = 0.0
    var parts = []
    var sorted_keys = durations.keys()
    sorted_keys.sort()

    for key in sorted_keys:
        var duration_ms = durations[key]
        total_gpu_ms += duration_ms
        parts.append("%s:%.2f" % [key, duration_ms])
        result[key] = duration_ms

    # print("GPU(ms) " + ", ".join(parts))
    FPSlabel.text = "%s:%.1f|Light:%.2fms" % [tr("FPS"), current_fps, total_gpu_ms]
    return result


func pixel_prob(pixel_crood: Vector2i, texture: RID):
    pass

# var LightPartical_textures_rd: Array[RID]
# var Obstacle_texture_rd: RID
# var QuickSampleObstacle_texture_rd: RID
# var FluidVelocity_texture_rd: Array[RID]
# var FluidColor_texture_rd: Array[RID]
# 清理资源（节点被移除时调用）
func _exit_tree() -> void:
    if rd:
        var rids_to_free = [
            # Pipelines
            DrawLight_pipeline, Dim_pipeline, Blur_pipeline, BrushDraw_pipeline, int_to_float_pipeline,
            # Shaders
            DrawLight_shader, Dim_shader, Blur_shader, BrushDraw_shader, int_to_float_shader,
            # Textures
            Draw_texture_rd, Blur_texture_rd, LightSource_texture_rd, Obstacle_texture_rd, QuickSampleObstacle_texture_rd,
            Draw_int_texture_div1_rd, Draw_int_texture_div2_rd, Draw_int_texture_div4_rd, Draw_int_texture_div8_rd,
            # Uniform Sets
            texture_set_for_DrawLight, texture_set_for_Dim, texture_set_for_Blur,
            texture_set_for_BrushDraw, texture_set_for_int_to_float,
            # Buffers
            Time_buffer, BrushDraw_buffer
        ]

        for i in range(2):
            rids_to_free.append(LightPartical_textures_rd[i])
            rids_to_free.append(FluidVelocity_texture_rd[i])
            rids_to_free.append(FluidColor_texture_rd[i])

        for rid in rids_to_free:
            if rid.is_valid():
                rd.free_rid(rid)
        
        rd = null

# 修改 uniform set 创建函数，包含浮点数缓冲区
func _create_DrawLight_uniform_set(shader: RID) -> RID:
    var texture_uniform := RDUniform.new()
    texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform.binding = 0
    texture_uniform.add_id(Draw_texture_rd)
    
    var float_uniform := RDUniform.new()
    float_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    float_uniform.binding = 1
    float_uniform.add_id(Time_buffer)

    # 分别创建4个纹理 uniform
    var texture_int_uniform_div1 := RDUniform.new()
    texture_int_uniform_div1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_int_uniform_div1.binding = 2
    texture_int_uniform_div1.add_id(Draw_int_texture_div1_rd)
    
    var texture_int_uniform_div2 := RDUniform.new()
    texture_int_uniform_div2.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_int_uniform_div2.binding = 3
    texture_int_uniform_div2.add_id(Draw_int_texture_div2_rd)
    
    var texture_int_uniform_div4 := RDUniform.new()
    texture_int_uniform_div4.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_int_uniform_div4.binding = 4
    texture_int_uniform_div4.add_id(Draw_int_texture_div4_rd)

    var texture_int_uniform_div8 := RDUniform.new()
    texture_int_uniform_div8.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_int_uniform_div8.binding = 5
    texture_int_uniform_div8.add_id(Draw_int_texture_div8_rd)

    var texture_uniform_Obstacle := RDUniform.new()
    texture_uniform_Obstacle.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_Obstacle.binding = 6
    texture_uniform_Obstacle.add_id(Obstacle_texture_rd)

    var texture_uniform_QuickSampleObstacle := RDUniform.new()
    texture_uniform_QuickSampleObstacle.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_QuickSampleObstacle.binding = 7
    texture_uniform_QuickSampleObstacle.add_id(QuickSampleObstacle_texture_rd)

    var texture_uniform_LightPartical := RDUniform.new()
    texture_uniform_LightPartical.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_LightPartical.binding = 8
    for i in range(0, LightPartical_textures_rd.size()):
        texture_uniform_LightPartical.add_id(LightPartical_textures_rd[i])
    
    var texture_uniform_FluidColor := RDUniform.new()
    texture_uniform_FluidColor.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_FluidColor.binding = 9
    for i in range(0, FluidColor_texture_rd.size()):
        texture_uniform_FluidColor.add_id(FluidColor_texture_rd[i])
    
    return rd.uniform_set_create([texture_uniform, float_uniform, texture_int_uniform_div1, texture_int_uniform_div2, texture_int_uniform_div4, texture_int_uniform_div8, texture_uniform_Obstacle, texture_uniform_QuickSampleObstacle, texture_uniform_LightPartical, texture_uniform_FluidColor], shader, 0)  

# func _create_dim_uniform_set(shader: RID) -> RID:
#     var texture_uniform := RDUniform.new()
#     texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
#     texture_uniform.binding = 0
#     texture_uniform.add_id(Draw_texture_rd)
    
#     return rd.uniform_set_create([texture_uniform], shader, 0)

func _create_blur_uniform_set(shader: RID) -> RID:
    var texture_uniform_input := RDUniform.new()
    texture_uniform_input.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_input.binding = 0
    texture_uniform_input.add_id(Draw_texture_rd)

    var texture_uniform_output := RDUniform.new()
    texture_uniform_output.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_output.binding = 1
    texture_uniform_output.add_id(Draw_texture_rd)

    var texture_uniform_QuickSampleObstacle := RDUniform.new()
    texture_uniform_QuickSampleObstacle.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_QuickSampleObstacle.binding = 2
    texture_uniform_QuickSampleObstacle.add_id(QuickSampleObstacle_texture_rd)

    var float_uniform := RDUniform.new()
    float_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    float_uniform.binding = 3
    float_uniform.add_id(Brightness_Diffuse_buffer)
    
    return rd.uniform_set_create([texture_uniform_input, texture_uniform_output, texture_uniform_QuickSampleObstacle, float_uniform], shader, 0)   

func _create_brushdraw_uniform_set(shader: RID) -> RID:
    var texture_uniform_Obstacle := RDUniform.new()
    texture_uniform_Obstacle.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_Obstacle.binding = 0
    texture_uniform_Obstacle.add_id(Obstacle_texture_rd)

    var texture_uniform_QuickSampleObstacle := RDUniform.new()
    texture_uniform_QuickSampleObstacle.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_QuickSampleObstacle.binding = 1
    texture_uniform_QuickSampleObstacle.add_id(QuickSampleObstacle_texture_rd)

    var texture_uniform_Velocity := RDUniform.new()
    texture_uniform_Velocity.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_Velocity.binding = 2
    for i in range(0, FluidVelocity_texture_rd.size()):
        texture_uniform_Velocity.add_id(FluidVelocity_texture_rd[i])
    
    var texture_uniform_Color := RDUniform.new()
    texture_uniform_Color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_Color.binding = 3
    for i in range(0, FluidColor_texture_rd.size()):
        texture_uniform_Color.add_id(FluidColor_texture_rd[i])
    
    var float_uniform := RDUniform.new()
    float_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    float_uniform.binding = 4
    float_uniform.add_id(BrushDraw_buffer)
    
    return rd.uniform_set_create([texture_uniform_Obstacle, texture_uniform_QuickSampleObstacle, texture_uniform_Velocity, texture_uniform_Color, float_uniform], shader, 0)

func _create_int_to_float_uniform_set(shader: RID) -> RID:
    var texture_uniform_input_div1 := RDUniform.new()
    texture_uniform_input_div1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_input_div1.binding = 0
    texture_uniform_input_div1.add_id(Draw_int_texture_div1_rd)

    var texture_uniform_input_div2 := RDUniform.new()
    texture_uniform_input_div2.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_input_div2.binding = 1
    texture_uniform_input_div2.add_id(Draw_int_texture_div2_rd)

    var texture_uniform_input_div4 := RDUniform.new()
    texture_uniform_input_div4.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_input_div4.binding = 2
    texture_uniform_input_div4.add_id(Draw_int_texture_div4_rd)

    var texture_uniform_input_div8 := RDUniform.new()
    texture_uniform_input_div8.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_input_div8.binding = 3
    texture_uniform_input_div8.add_id(Draw_int_texture_div8_rd)

    var texture_uniform_output := RDUniform.new()
    texture_uniform_output.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_output.binding = 4
    texture_uniform_output.add_id(Draw_texture_rd)

    var buffer_uniform := RDUniform.new()
    buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    buffer_uniform.binding = 5
    buffer_uniform.add_id(Develop_film_buffer)

    var quick_sample_obstacle_uniform := RDUniform.new()
    quick_sample_obstacle_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    quick_sample_obstacle_uniform.binding = 6
    quick_sample_obstacle_uniform.add_id(QuickSampleObstacle_texture_rd)
    
    return rd.uniform_set_create([texture_uniform_input_div1, texture_uniform_input_div2, texture_uniform_input_div4, texture_uniform_input_div8, texture_uniform_output, buffer_uniform, quick_sample_obstacle_uniform], shader, 0)

func _create_ParticleTransition_uniform_set(shader: RID) -> RID:
    var texture_uniform := RDUniform.new()
    texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform.binding = 0
    texture_uniform.add_id(Draw_texture_rd)
    
    var float_uniform := RDUniform.new()
    float_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    float_uniform.binding = 1
    float_uniform.add_id(Time_buffer)

    # 分别创建4个纹理 uniform
    var texture_int_uniform_div1 := RDUniform.new()
    texture_int_uniform_div1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_int_uniform_div1.binding = 2
    texture_int_uniform_div1.add_id(Draw_int_texture_div1_rd)
    
    var texture_int_uniform_div2 := RDUniform.new()
    texture_int_uniform_div2.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_int_uniform_div2.binding = 3
    texture_int_uniform_div2.add_id(Draw_int_texture_div2_rd)
    
    var texture_int_uniform_div4 := RDUniform.new()
    texture_int_uniform_div4.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_int_uniform_div4.binding = 4
    texture_int_uniform_div4.add_id(Draw_int_texture_div4_rd)
    
    var texture_int_uniform_div8 := RDUniform.new()
    texture_int_uniform_div8.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_int_uniform_div8.binding = 5
    texture_int_uniform_div8.add_id(Draw_int_texture_div8_rd)

    var texture_uniform_Obstacle := RDUniform.new()
    texture_uniform_Obstacle.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_Obstacle.binding = 6
    texture_uniform_Obstacle.add_id(Obstacle_texture_rd)

    var texture_uniform_QuickSampleObstacle := RDUniform.new()
    texture_uniform_QuickSampleObstacle.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_QuickSampleObstacle.binding = 7
    texture_uniform_QuickSampleObstacle.add_id(QuickSampleObstacle_texture_rd)

    var texture_uniform_LightPartical := RDUniform.new()
    texture_uniform_LightPartical.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_LightPartical.binding = 8
    for i in range(0, LightPartical_textures_rd.size()):
        texture_uniform_LightPartical.add_id(LightPartical_textures_rd[i])

    var texture_uniform_FluidColor := RDUniform.new()
    texture_uniform_FluidColor.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform_FluidColor.binding = 9
    for i in range(0, FluidColor_texture_rd.size()):
        texture_uniform_FluidColor.add_id(FluidColor_texture_rd[i])    
    
    return rd.uniform_set_create([texture_uniform, float_uniform, texture_int_uniform_div1, texture_int_uniform_div2, texture_int_uniform_div4, texture_int_uniform_div8, texture_uniform_Obstacle, texture_uniform_QuickSampleObstacle, texture_uniform_LightPartical, texture_uniform_FluidColor], shader, 0)

func _create_ReadTexture_uniform_set(shader: RID) -> RID:
    var texture_uniform := RDUniform.new()
    texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform.binding = 0
    texture_uniform.add_id(Obstacle_texture_rd)
    
    var buffer_uniform := RDUniform.new()
    buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    buffer_uniform.binding = 1
    buffer_uniform.add_id(ReadTexture_buffer)

    return rd.uniform_set_create([texture_uniform, buffer_uniform], shader, 0)

func _create_FluidVelocity_uniform_set(shader: RID) -> RID:
    var texture_uniform := RDUniform.new()
    texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform.binding = 0
    for i in range(2):
        texture_uniform.add_id(FluidVelocity_texture_rd[i])

    var texture_Obstacle_uniform := RDUniform.new()
    texture_Obstacle_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_Obstacle_uniform.binding = 1
    texture_Obstacle_uniform.add_id(Obstacle_texture_rd)
    
    var buffer_uniform := RDUniform.new()
    buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    buffer_uniform.binding = 2
    buffer_uniform.add_id(FluidSim_buffer)

    return rd.uniform_set_create([texture_uniform,texture_Obstacle_uniform, buffer_uniform], shader, 0)

func _create_FluidColor_uniform_set(shader: RID) -> RID:
    var texture_uniform := RDUniform.new()
    texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_uniform.binding = 0
    for i in range(2):
        texture_uniform.add_id(FluidVelocity_texture_rd[i])

    var texture_Color_uniform := RDUniform.new()
    texture_Color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    texture_Color_uniform.binding = 1
    for i in range(2):
        texture_Color_uniform.add_id(FluidColor_texture_rd[i])
    
    var buffer_uniform := RDUniform.new()
    buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    buffer_uniform.binding = 2
    buffer_uniform.add_id(FluidSim_buffer)

    return rd.uniform_set_create([texture_uniform, texture_Color_uniform, buffer_uniform], shader, 0)
