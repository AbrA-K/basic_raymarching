mod ui;
use ui::MyRaymarchUi;

use bevy::{
    core_pipeline::prepass::DepthPrepass,
    pbr::{ExtendedMaterial, MaterialExtension},
    prelude::*,
    render::render_resource::{AsBindGroup, ShaderType},
};

fn main() {
    App::new()
        .add_plugins((
            DefaultPlugins,
            MyRaymarchUi,
            MaterialPlugin::<ExtendedMaterial<StandardMaterial, RaymarchMaterial>>::default(),
        ))
        .add_systems(Startup, spawn_shit)
        .add_systems(Update, (spin_camera, update_raymarch_settings_time))
        .run();
}

#[derive(Component)]
struct SpinningCam {
    height: f32,
    distance: f32,
    speed: f32,
    sway_amount: f32,
    look_at: Vec3,
}

fn spin_camera(mut cams: Query<(&mut Transform, &SpinningCam)>, time: Res<Time>) {
    cams.iter_mut()
        .for_each(|(mut transform, spinning_cam_vars)| {
            let new_z =
                (time.elapsed_secs() * spinning_cam_vars.speed).cos() * spinning_cam_vars.distance;
            let new_x =
                (time.elapsed_secs() * spinning_cam_vars.speed).sin() * spinning_cam_vars.distance;
            let sway_y = (time.elapsed_secs() * spinning_cam_vars.speed / 0.35).sin()
                * spinning_cam_vars.sway_amount;
            let new_transform =
                Transform::from_xyz(new_x, spinning_cam_vars.height + sway_y, new_z)
                    .looking_at(spinning_cam_vars.look_at, Vec3::Y);
            *transform = new_transform;
        });
}

// info to pass to the shader
// VEEERY carefull with the order of these params
// they HAVE to reflect the state of the same named struct in the shader
#[derive(Debug, AsBindGroup, Clone, ShaderType)]
#[repr(C)]
struct RaymarchObjectDescriptor {
    // translation
    world_position: Vec3,
    rotation: Vec3,

    // movement
    move_amout: f32,
    rotation_amount: f32,

    // in rust land, we would use an enum here
    // but since this struct is passed to wgpu, I'm not sure how this would be passed
    // make it work first - I'm not shipping this to prod or something
    // TODO: maybe.. don't do this lol
    /// sphere = 1
    /// square = 2
    /// cone = 3
    /// mandelbulb = 4
    shape_type_id: u32,
    /// sphere -> radius
    /// square -> side lenght
    /// cone -> height
    shape_var: f32,
    scale: f32,

    // material
    // TODO: a bunch of those are unused. do you need them?
    base_color: Vec4,
    emissive: Vec4,
    reflectance: Vec3,
    perceptual_roughness: f32,
    metallic: f32,
    diffuse_transmission: f32,
    specular_transmission: f32,
    thickness: f32,
    ior: f32,
    attenuation_distance: f32,
    attenuation_color: Vec4,
    clearcoat: f32,
    clearcoat_perceptual_roughness: f32,
    anisotropy_strength: f32,
    anisotropy_rotation: Vec2,
}

impl Default for RaymarchObjectDescriptor {
    fn default() -> Self {
        return RaymarchObjectDescriptor {
            world_position: Vec3::new(0.0, 0.5, 0.0),
            rotation: Vec3::ZERO,
            move_amout: 0.0,
            rotation_amount: 0.0,
            shape_type_id: 1,
            shape_var: 0.4,
            scale: 0.4,
            base_color: Vec4::new(1.0, 0.0, 0.0, 1.0),
            emissive: Vec4::ZERO,
            reflectance: Vec3::splat(0.5),
            perceptual_roughness: 0.5,
            metallic: 0.0,
            diffuse_transmission: 0.0,
            specular_transmission: 0.0,
            thickness: 0.0,
            ior: 1.5,
            attenuation_distance: 1.0,
            attenuation_color: Vec4::splat(1.0),
            clearcoat: 0.0,
            clearcoat_perceptual_roughness: 0.0,
            anisotropy_strength: 0.0,
            anisotropy_rotation: Vec2::ZERO,
        };
    }
}

#[derive(Debug, AsBindGroup, Clone, ShaderType)]
#[repr(C)]
struct RaymarchGlobalSettings {
    /// 0 -> a OR b intersection
    /// 1 -> a AND b intersection
    /// 2 -> a NOT b intersection
    intersection_method: u32,
    intersection_smooth_amount: f32,
    glow_range: f32,
    glow_color: Vec4,
    far_clip: f32,
    termination_distance: f32,
    time: f32,
}

impl Default for RaymarchGlobalSettings {
    fn default() -> Self {
        return RaymarchGlobalSettings {
            intersection_method: 0,
            intersection_smooth_amount: 0.0,
            glow_range: 0.0,
            glow_color: Vec4::ZERO,
            far_clip: 10.0,
            termination_distance: 0.001,
            time: 0.0,
        };
    }
}

// update the elapsed time that I pass to the shader
fn update_raymarch_settings_time(
    mut rm_materials: ResMut<Assets<ExtendedMaterial<StandardMaterial, RaymarchMaterial>>>,
    rm_material_handle: Res<RaymarchMaterialHandle>,
    time: Res<Time>,
) {
    let maybe_mat = rm_materials.get_mut(&rm_material_handle.0);
    if let Some(mat) = maybe_mat {
        mat.extension.raymarch_global_settings.time = time.elapsed_secs();
    }
}

// my RayMarch Material
#[derive(Asset, TypePath, AsBindGroup, Debug, Clone)]
struct RaymarchMaterial {
    #[uniform(100)]
    material1: RaymarchObjectDescriptor,
    #[uniform(101)]
    material2: RaymarchObjectDescriptor,
    #[uniform(102)]
    raymarch_global_settings: RaymarchGlobalSettings,
}

impl MaterialExtension for RaymarchMaterial {
    fn fragment_shader() -> bevy::render::render_resource::ShaderRef {
        "shaders/basic_raymarch.wgsl".into()
    }
    fn prepass_fragment_shader() -> bevy::render::render_resource::ShaderRef {
        "shaders/basic_raymarch_prepass.wgsl".into()
    }
}

impl RaymarchMaterial {
    fn get_basic_config() -> Self {
        let mut out = RaymarchMaterial {
            material1: RaymarchObjectDescriptor::default(),
            material2: RaymarchObjectDescriptor::default(),
            raymarch_global_settings: RaymarchGlobalSettings::default(),
        };
        out.material2.world_position = Vec3::new(-0.5, 0.75, 0.4);
        out.material2.base_color = Vec4::new(0.0, 1.0, 0.0, 1.0);
        out.material2.rotation_amount = 0.5;
        out.material2.shape_type_id = 2;
        return out;
    }

    fn get_smooth_config() -> Self {
        let mut out = RaymarchMaterial {
            material1: RaymarchObjectDescriptor::default(),
            material2: RaymarchObjectDescriptor::default(),
            raymarch_global_settings: RaymarchGlobalSettings::default(),
        };
        out.material2.world_position = Vec3::new(-0.5, 0.75, 0.4);
        out.material2.base_color = Vec4::new(0.0, 1.0, 0.0, 1.0);
        out.material2.shape_type_id = 2;
        out.material2.metallic = 0.6;
        out.material2.rotation_amount = 0.3;
        out.raymarch_global_settings.intersection_smooth_amount = 0.5;
        return out;
    }

    fn get_intersection_config() -> Self {
        let mut out = RaymarchMaterial {
            material1: RaymarchObjectDescriptor::default(),
            material2: RaymarchObjectDescriptor::default(),
            raymarch_global_settings: RaymarchGlobalSettings::default(),
        };
        out.material2.world_position = Vec3::new(-0.5, 0.75, 0.4);
        out.material2.base_color = Vec4::new(0.0, 1.0, 0.0, 1.0);
        out.material2.shape_type_id = 2;
        out.material2.metallic = 0.6;
        out.material2.rotation_amount = 0.5;
        out.raymarch_global_settings.intersection_method = 2;
        return out;
    }

    fn get_mandelbulb_config() -> Self {
        let mut out = RaymarchMaterial {
            material1: RaymarchObjectDescriptor::default(),
            material2: RaymarchObjectDescriptor::default(),
            raymarch_global_settings: RaymarchGlobalSettings::default(),
        };
        out.material1.world_position = Vec3::new(0.0, 0.8, 0.0);
        out.material1.rotation.x = 0.8;
        out.material1.shape_type_id = 4;
        out.material1.shape_var = 1.85;
        out.material2.shape_var = 0.0;
        return out;
    }
}

/// this holds the current Material Handle (like a pointer) as a Resource
#[derive(Resource)]
struct RaymarchMaterialHandle(Handle<ExtendedMaterial<StandardMaterial, RaymarchMaterial>>);

fn spawn_shit(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
    mut raymarch_material: ResMut<Assets<ExtendedMaterial<StandardMaterial, RaymarchMaterial>>>,
) {
    // camera
    commands.spawn((
        Camera3d {
            ..Default::default()
        },
        Msaa::Off, // turn it off since it doesn't work on web
        SpinningCam {
            height: 2.0,
            distance: 4.0,
            speed: 0.5,
            sway_amount: 1.0,
            look_at: Vec3::new(0.0, 0.5, 0.0),
        },
        DepthPrepass,
    ));

    // circular base
    commands.spawn((
        Mesh3d(meshes.add(Circle::new(4.0))),
        MeshMaterial3d(materials.add(Color::WHITE)),
        Transform::from_rotation(Quat::from_rotation_x(-std::f32::consts::FRAC_PI_2)),
    ));

    // cube
    let rm_material_handle = raymarch_material.add(ExtendedMaterial {
        base: StandardMaterial {
            // base_color_texture: Some(asset_server.load("icon.png")),
            // base_color: bevy::color::palettes::css::BLUE.into(),
            alpha_mode: AlphaMode::Blend,
            ..Default::default()
        },
        extension: RaymarchMaterial::get_basic_config(),
    });
    commands.insert_resource(RaymarchMaterialHandle(rm_material_handle.clone()));
    commands.spawn((
        Mesh3d(meshes.add(Cuboid::new(4.0, 4.0, 4.0))),
        MeshMaterial3d(rm_material_handle.clone()),
        Transform::from_xyz(0.0, 0.5, 0.0),
    ));

    // // cylinder
    // // It's spawned inside of the raymarched cube to test if depth stuff works
    // // uncomment this to test!
    // // on web, you will see that depth stuff doesn't work, so I'll leave this commented
    // commands.spawn((
    //     Mesh3d(meshes.add(Cylinder::new(0.2, 5.0))),
    //     MeshMaterial3d(materials.add(Color::WHITE)),
    //     Transform::from_xyz(0.4, 0.2, 0.4),
    // ));

    // light
    commands.spawn((
        PointLight {
            shadows_enabled: true,
            intensity: 2000000.0,
            ..default()
        },
        Transform::from_xyz(4.0, 4.0, 4.0),
    ));
}
