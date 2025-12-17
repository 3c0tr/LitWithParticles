extends Control

# 引用你的主要脚本
@export var lanuage_switch_botton:Button
@export var color_picker:ColorPicker
@export var material_selector:ItemList
@onready var render_device_test = get_node("../Main")  # 根据实际节点路径调整

@export var menuList: ItemList
@export var menu: Array[Control]
@export var material_parameters_slider: Array[Slider]
@export var material_parameters_label: Array[Label]
@export var total_time_coast_label: RichTextLabel
@export var time_coast_label: Array[Label]

@export var emit_rotation_rate_label: Label
@export var emit_rotation_rate_spin: SpinBox

@export var emit_z_order_offset_label: Label
@export var emit_z_order_offset_spin: SpinBox

@export var particle_jump_length_label: Label
@export var particle_jump_length_spin: SpinBox

@export var particle_jump_times_label: Label
@export var particle_jump_times_spin: SpinBox

@export var is_particle_transit_buttom: OptionButton
@export var is_fluid_simulation_buttom: OptionButton

@export var kalman_process_noise_spin: SpinBox
@export var kalman_measurement_noise_spin: SpinBox

@export var canvas_brush_shape: ItemList
@export var special_buttom: Button
@export var unique_material_Buttom: OptionButton

@export var normal_mode_button: OptionButton
@export var custom_normal_spin: SpinBox
@export var invert_normal_buttom: OptionButton
@export var write_radiant_dir_buttom: OptionButton

@export var ambient_strength_slider: Slider
@export var ambient_color_buttom: ColorPickerButton

@export var show_outline_buttom: OptionButton
@export var show_particle_buttom: OptionButton
@export var show_normal_buttom: OptionButton

@export var chromatic_dispersion_buttom: OptionButton
@export var light_penetration_spin: SpinBox

@export var brghtnegative_feedback_buttom: OptionButton
@export var emit_material_decay_spin: SpinBox
@export var brightness_diffuse_times_spin: SpinBox
@export var particle_simulation_times_spin: SpinBox
@export var brightness_blend_ratio_spin: SpinBox


var click_time: int = 0


func _ready():
    # 连接语言切换按钮的信号
    if lanuage_switch_botton:
        lanuage_switch_botton.pressed.connect(_on_language_switch_pressed)
    if menuList:
        menuList.item_selected.connect(_on_menu_selected.bind())
    if color_picker:
        color_picker.color_changed.connect(_on_color_changed.bind())
    if material_selector:
        material_selector.item_selected.connect(_on_material_selected.bind())
        
    for i in range(material_parameters_slider.size()):
        var slider = material_parameters_slider[i]
        var label = material_parameters_label[i]
        if slider and label:
            slider.value_changed.connect(_on_material_parameter_changed.bind(label, i))
    
    if emit_rotation_rate_spin:
        emit_rotation_rate_spin.value_changed.connect(_on_emit_rotation_rate_changed.bind())

    if emit_z_order_offset_spin:
        emit_z_order_offset_spin.value_changed.connect(_on_emit_z_order_offset_changed.bind())

    if particle_jump_length_spin:
        particle_jump_length_spin.value_changed.connect(_on_particle_jump_length_changed.bind(particle_jump_length_label))

    if particle_jump_times_spin:
        particle_jump_times_spin.value_changed.connect(_on_particle_jump_times_changed.bind(particle_jump_times_label))
    
    if is_particle_transit_buttom:
        is_particle_transit_buttom.item_selected.connect(_on_is_particle_transit_changed.bind())

    if is_fluid_simulation_buttom:
        is_fluid_simulation_buttom.item_selected.connect(_on_is_fluid_simulation_changed.bind())
    
    if kalman_process_noise_spin:
        kalman_process_noise_spin.value_changed.connect(_on_kalman_process_noise_changed.bind())

    if kalman_measurement_noise_spin:
        kalman_measurement_noise_spin.value_changed.connect(_on_kalman_measurement_noise_changed.bind())
    
    if canvas_brush_shape:
        canvas_brush_shape.item_selected.connect(_on_canvas_brush_shape_changed.bind())
    
    if special_buttom:
        special_buttom.pressed.connect(_on_special_buttom_pressed.bind())
    
    if unique_material_Buttom:
        unique_material_Buttom.item_selected.connect(_on_unique_material_changed.bind())
    
    if normal_mode_button:
        normal_mode_button.item_selected.connect(_on_normal_mode_changed.bind())
        
    if custom_normal_spin:
        custom_normal_spin.value_changed.connect(_on_custom_normal_changed.bind())
        
    if invert_normal_buttom:
        invert_normal_buttom.item_selected.connect(_on_invert_normal_changed.bind())
        
    if write_radiant_dir_buttom:
        write_radiant_dir_buttom.item_selected.connect(_on_write_radiant_dir_changed.bind())
    
    if ambient_strength_slider:
        ambient_strength_slider.value_changed.connect(_on_ambient_strength_changed.bind())
    
    if ambient_color_buttom:
        ambient_color_buttom.color_changed.connect(_on_ambient_color_changed.bind())
    
    if show_outline_buttom:
        show_outline_buttom.item_selected.connect(_on_show_outline_changed.bind())
    
    if show_normal_buttom:
        show_normal_buttom.item_selected.connect(_on_show_normal_changed.bind())
    
    if show_particle_buttom:
        show_particle_buttom.item_selected.connect(_on_show_particle_changed.bind())
    
    if chromatic_dispersion_buttom:
        chromatic_dispersion_buttom.item_selected.connect(_on_chromatic_dispersion_changed.bind())
    
    if light_penetration_spin:
        light_penetration_spin.value_changed.connect(_on_light_penetration_changed.bind())
    
    if brghtnegative_feedback_buttom:
        brghtnegative_feedback_buttom.item_selected.connect(_on_brghtnegative_feedback_changed.bind())
    
    if emit_material_decay_spin:
        emit_material_decay_spin.value_changed.connect(_on_emit_material_decay_changed.bind())
    
    if brightness_diffuse_times_spin:
        brightness_diffuse_times_spin.value_changed.connect(_on_brightness_diffuse_times_changed.bind())

    if particle_simulation_times_spin:
        particle_simulation_times_spin.value_changed.connect(_on_particle_simulation_times_changed.bind())
    
    if brightness_blend_ratio_spin:
        brightness_blend_ratio_spin.value_changed.connect(_on_brightness_blend_ratio_changed.bind())



    material_selector.select(0)
    _on_material_selected(-1)
    _on_material_selected(0)

    
    material_parameters_label[9].visible = false
    material_parameters_label[10].visible = false
    material_parameters_label[11].visible = false

    menuList.select(0)
    _on_menu_selected(0)
    canvas_brush_shape.select(0)
    set_lighting_system_parameters_default()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
        var current_shape = canvas_brush_shape.get_selected_items()[0]
        var new_shape = 1 - current_shape
        canvas_brush_shape.select(new_shape)
        _on_canvas_brush_shape_changed(new_shape)



# func _on_brush_size_changed(value: float, label: Label):
#     label.text = "旋转速率(圈/秒): %.3f" % value
#     # 更新你的渲染参数
#     if render_device_test:
#         render_device_test.RPM = value

func _on_menu_selected(index: int):
    for i in range(menu.size()):
        menu[i].set_visible(i == index)

func _on_blur_strength_changed(value: float, label: Label):
    label.text = "旋转相位像素偏移X(2pi): %.3f" % value
    # 更新模糊强度参数
    if render_device_test:
        render_device_test._x_offset = value

# func _on_photon_intensity_changed(value: float, label: Label):
#     label.text = "旋转相位像素偏移Y(2pi): %.3f" % value
#     # 更新光子强度参数
#     if render_device_test:
#         render_device_test._y_offset = value

func _on_color_changed(color: Color):
    # 更新颜色参数
    if render_device_test:
        render_device_test.draw_color = color

func _on_material_parameter_changed(value: float, label: Label, index: int):
    if render_device_test:
        # This is a generic handler. Specific label text formatting is removed.
        # You might want to create a more complex handler if specific text is needed.
        match index:
            0: # Roughness
                label.text = tr("Roughness") + ": %.2f" % value
                render_device_test.roughness = value
            1: # IOR
                label.text = tr("IOR") + ": %.2f" % (value * 1.5 + 1.0)
                render_device_test.IOR = value
            2: # Scatter Rate
                label.text = tr("Scatter Rate") + ": %.2f" % value
                render_device_test.scatterRate = value
            3: # Opacity
                label.text = tr("opacity") + ": %.2f" % value
                render_device_test.opacity = value
            4: # Metallic
                label.text = tr("Metallic") + ": %.2f" % value
                render_device_test.metallic = value
            5: # Emit Strength
                label.text = tr("Emit Strength") + ": %.2f" % value
                render_device_test.emit_strength = value
            6: # Emit Range
                var int_value = int(value * 255.0) * 8
                # if (int_value == 255 * 16):
                #     label.text = tr("Emit Range") + ": ∞px"
                # else:
                label.text = tr("Emit Range") + ": %dpx" % int_value
                render_device_test.emit_range = value
            7: # Emit Scatter L
                label.text = tr("Emit Angle L") + ": %.1f°" % (value * 360.0)
                render_device_test.emit_scatterL = value
            8: # Emit Scatter R
                label.text = tr("Emit Angle R") + ": %.1f°" % (value * 360.0)
                render_device_test.emit_scatterR = value
            9: # GravityX
                if (render_device_test.unique_material == 1):
                    label.text = tr("GravityX") + ": %.2f" % value
                elif (render_device_test.unique_material == 2):
                    label.text = tr("PortalX") + ": %.2f" % value
                render_device_test.gravityX = value
            10: # GravityY
                if (render_device_test.unique_material == 1):
                    label.text = tr("GravityY") + ": %.2f" % value
                elif (render_device_test.unique_material == 2):
                    label.text = tr("PortalY") + ": %.2f" % value
                render_device_test.gravityY = value

# 语言切换按钮回调函数
func _on_language_switch_pressed():
    var current_locale = TranslationServer.get_locale()
    var new_locale = ""
    
    # 在中文和英文之间切换
    if current_locale == "zh" or current_locale == "zh_CN":
        new_locale = "en"
    else:
        new_locale = "zh"
    
    # 设置新的语言
    TranslationServer.set_locale(new_locale)
    refresh_ui_text()

func refresh_ui_text():
    for i in range(material_parameters_slider.size()):
        if i < material_parameters_label.size() and material_parameters_slider[i] and material_parameters_label[i]:
            _on_material_parameter_changed(material_parameters_slider[i].value, material_parameters_label[i], i)

func set_lighting_system_parameters_default():
    emit_rotation_rate_spin.value = 0.181 #0.215 0.175
    emit_z_order_offset_spin.value = 0.250 #0.256
    particle_jump_length_spin.value = 3.0
    particle_jump_times_spin.value = 108
    kalman_process_noise_spin.value = 0.033
    kalman_measurement_noise_spin.value = 40.0

func set_material_parameters(params: Array):
    for i in range(min(params.size(), material_parameters_slider.size())):
        if material_parameters_slider[i]:
            material_parameters_slider[i].value = params[i]

func _on_particle_jump_length_changed(value: float, label: Label):
    label.text = "粒子跳跃长度: %.2f" % value
    # 更新粒子跳跃长度参数
    if render_device_test:
        render_device_test.particle_jump_length = value

func _on_particle_jump_times_changed(value: int, label: Label):
    label.text = "粒子跳跃次数: %d" % value
    # 更新粒子跳跃次数参数
    if render_device_test:
        render_device_test.particle_jump_times = value
    
func _on_is_particle_transit_changed(index: int):
    print(index)
    # 更新是否开启粒子传递参数
    if render_device_test:
        if index == 0:
            render_device_test.is_particle_transit_on = false
        else:
            render_device_test.is_particle_transit_on = true

func _on_is_fluid_simulation_changed(index: int):
    print(index)
    # 更新是否开启流体模拟参数
    if render_device_test:
        if index == 0:
            render_device_test.is_fluid_simulation_on = false
            render_device_test.clear_fluid_texture()
        else:
            render_device_test.is_fluid_simulation_on = true

func _on_material_selected(index: int):
    if render_device_test:
        match index:
            -1:
                set_material_parameters([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]) # 无材质
            0:
                set_material_parameters([0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.31, 0.0, 1.0]) # 发光体
            1:
                set_material_parameters([0.05, 0.46, 0.0, 1.0, 0.1, 0.0, 0.0, 0.0, 0.0]) # 陶瓷
            2:
                set_material_parameters([0.05, 0.33, 0.0, 0.05, 0.05, 0.0, 0.0, 0.0, 0.0]) # 透明玻璃
            3:  
                set_material_parameters([0.05, 0.33, 0.2, 0.05, 0.1, 0.0, 0.0, 0.0, 0.0]) # 毛玻璃
            4:
                set_material_parameters([0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]) # 黑体
            5: 
                set_material_parameters([0.0, 0.75, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0]) # 镜面
            6:
                set_material_parameters([0.5, 0.35, 0.5, 1.0, 0.01, 0.0, 0.0, 0.0, 0.0]) # 砂岩
            7:
                set_material_parameters([0.5, 0.37, 0.5, 0.3, 0.01, 0.5, 0.1, 0.0, 1.0]) # 萤石

func _on_emit_rotation_rate_changed(value: float):
    # 更新旋转速率参数
    if render_device_test:
        render_device_test.rotation_rate = value
        
func _on_emit_z_order_offset_changed(value: float):
    # 更新Z序偏移参数
    if render_device_test:
        render_device_test.z_order_offset = value
        
func _on_kalman_process_noise_changed(value: float):
    # 更新Kalman过程噪声参数
    if render_device_test:
        render_device_test.kalman_process_noise = value
        
func _on_kalman_measurement_noise_changed(value: float):
    # 更新Kalman测量噪声参数
    if render_device_test:
        render_device_test.kalman_measurement_noise = value

func _on_canvas_brush_shape_changed(index: int):
    # 更新画笔形状参数
    if render_device_test:
        render_device_test.brush_shape = index

func _on_special_buttom_pressed():
    click_time += 1
    if (click_time >= 5):
        material_parameters_label[11].visible = true

func _on_unique_material_changed(index: int):
    if render_device_test:
        render_device_test.unique_material = index
        material_parameters_slider[9].value = 1.0
        material_parameters_slider[10].value = 1.0
        material_parameters_slider[9].value = 0.0
        material_parameters_slider[10].value = 0.0
        if (index == 0):
            material_parameters_label[9].visible = false
            material_parameters_label[10].visible = false
        else:
            material_parameters_label[9].visible = true
            material_parameters_label[10].visible = true

func _on_normal_mode_changed(index: int):
    if render_device_test:
        if index == 1:
            render_device_test.normal_mode |= 1
        else:
            render_device_test.normal_mode &= ~1

func _on_custom_normal_changed(value: float):
    if render_device_test:
        render_device_test.custom_normal = value

func _on_invert_normal_changed(index: int):
    if render_device_test:
        if index == 1:
            render_device_test.normal_mode |= 4
        else:
            render_device_test.normal_mode &= ~4

func _on_write_radiant_dir_changed(index: int):
    if render_device_test:
        if index == 1:
            render_device_test.normal_mode |= 2
        else:
            render_device_test.normal_mode &= ~2

func _on_ambient_strength_changed(value: float):
    if render_device_test:
        render_device_test.ambient_strength = value

func _on_ambient_color_changed(color: Color):
    if render_device_test:
        render_device_test.ambient_color = color

func _on_show_outline_changed(index: int):
    if render_device_test:
        render_device_test.show_outline = index == 1

func _on_show_normal_changed(index: int):
    if render_device_test:
        render_device_test.show_normal = index == 1

func _on_show_particle_changed(index: int):
    if render_device_test:
        render_device_test.show_particle = index == 1

func _on_chromatic_dispersion_changed(index: int):
    if render_device_test:
        render_device_test.chromatic_dispersion = index == 1

func _on_light_penetration_changed(value: float):
    if render_device_test:
        render_device_test.light_penetration = value

func _on_brghtnegative_feedback_changed(index: int):
    if render_device_test:
        render_device_test.brghtnegative_feedback = index == 1

func _on_emit_material_decay_changed(value: float):
    if render_device_test:
        render_device_test.emit_material_decay = value

func _on_brightness_diffuse_times_changed(value: int):
    if render_device_test:
        render_device_test.brightness_diffuse_times = value

func _on_particle_simulation_times_changed(value: int):
    if render_device_test:
        render_device_test.particle_simulation_times = value

func _on_brightness_blend_ratio_changed(value: float):
    if render_device_test:
        render_device_test.brightness_blend_ratio = value



func _on_time_coast_changed(time_coast: Dictionary):
    var particle_emit_time = 0.0
    var particle_propagation_time = 0.0
    var energy_diffuse_time = 0.0
    var develop_film_time = 0.0
    var fluid_sim_time = 0.0
    var read_texture_time = 0.0
    var total_time = 0.0

    for key in time_coast.keys():
        var time_val = time_coast[key]
        if "EmitLight" in key:
            particle_emit_time += time_val
        elif "ParticlePropagation" in key:
            particle_propagation_time += time_val
        elif "Blur" in key:
            energy_diffuse_time += time_val
        elif "int_to_float" in key:
            develop_film_time += time_val
        elif "Fluid" in key:
            fluid_sim_time += time_val
        elif "ReadTexture" in key:
            read_texture_time += time_val
        
        total_time += time_val

    total_time_coast_label.text = tr("Time Cost") + ": %.2fms" % (total_time)
    
    var timing_data = [
        {"name": tr("Particle Emit"), "time": particle_emit_time, "label": time_coast_label[0]},
        {"name": tr("Particle Transit"), "time": particle_propagation_time, "label": time_coast_label[1]},
        {"name": tr("Film Exposure"), "time": develop_film_time, "label": time_coast_label[2]},
        {"name": tr("Energy Diffuse"), "time": energy_diffuse_time, "label": time_coast_label[3]},
        {"name": tr("Fluid Sim"), "time": fluid_sim_time, "label": time_coast_label[4]},
        {"name": tr("Texture Prob"), "time": read_texture_time, "label": time_coast_label[5]}
    ]

    var max_name_len = 0
    for item in timing_data:
        if item.name.length() > max_name_len:
            max_name_len = item.name.length()

    for item in timing_data:
        if item.time > 0.001 and total_time > 0.001:
            item.label.visible = true
            var name_part = ("%-" + str(max_name_len + 1) + "s") % (item.name + ":")
            var time_part = "%6.2fms" % item.time
            var percentage = item.time / total_time * 100.0
            var percentage_part = "(%.1f%%)" % percentage
            item.label.text = "%s %s %s" % [name_part, time_part, percentage_part]
        else:
            item.label.visible = false
