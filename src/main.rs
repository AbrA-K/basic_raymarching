mod ui;
use ui::MyRaymarchUi;

use bevy::{
    core_pipeline::prepass::DepthPrepass,
    pbr::{ExtendedMaterial, MaterialExtension, NotShadowCaster},
    prelude::*,
    render::{render_resource::AsBindGroup, storage::ShaderStorageBuffer},
};

fn main() {
    App::new()
        .add_plugins((
            DefaultPlugins,
            MyRaymarchUi,
            MaterialPlugin::<ExtendedMaterial<StandardMaterial, RaymarchMaterial>>::default(),
        ))
        .add_systems(Startup, (spawn_camera, spawn_shit))
        .add_systems(Update, spin_camera)
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

fn spawn_camera(mut commands: Commands) {
    commands.spawn((
        Camera3d {
            ..Default::default()
        },
        SpinningCam {
            height: 2.0,
            distance: 4.0,
            speed: 0.5,
            sway_amount: 1.0,
            look_at: Vec3::new(0.0, 0.5, 0.0),
        },
        Msaa::Off,
        DepthPrepass,
        // DeferredPrepass,
        // NormalPrepass,
        // MotionVectorPrepass,
    ));
}

// my RayMarch Material
#[derive(Asset, TypePath, AsBindGroup, Debug, Clone)]
struct RaymarchMaterial {
    #[uniform(100)]
    roughness: f32,
}
impl MaterialExtension for RaymarchMaterial {
    fn fragment_shader() -> bevy::render::render_resource::ShaderRef {
        "shaders/basic_raymarch.wgsl".into()
    }
    fn specialize(
        _pipeline: &bevy::pbr::MaterialExtensionPipeline,
        descriptor: &mut bevy::render::render_resource::RenderPipelineDescriptor,
        _layout: &bevy::render::mesh::MeshVertexBufferLayoutRef,
        _key: bevy::pbr::MaterialExtensionKey<Self>,
    ) -> std::result::Result<(), bevy::render::render_resource::SpecializedMeshPipelineError> {
        descriptor.primitive.cull_mode = Some(bevy::render::render_resource::Face::Back);
        descriptor.depth_stencil = Some(bevy::render::render_resource::DepthStencilState {
            format: bevy::render::render_resource::TextureFormat::Depth32Float,
            depth_write_enabled: true,
            depth_compare: bevy::render::render_resource::CompareFunction::Greater,
            stencil: bevy::render::render_resource::StencilState::default(),
            bias: bevy::render::render_resource::DepthBiasState::default(),
        });
        Ok(())
    }
    fn prepass_fragment_shader() -> bevy::render::render_resource::ShaderRef {
        "shaders/basic_raymarch_prepass.wgsl".into()
    }
}

fn spawn_shit(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
    mut raymarch_material: ResMut<Assets<ExtendedMaterial<StandardMaterial, RaymarchMaterial>>>,
) {
    // circular base
    commands.spawn((
        Mesh3d(meshes.add(Circle::new(4.0))),
        MeshMaterial3d(materials.add(Color::WHITE)),
        Transform::from_rotation(Quat::from_rotation_x(-std::f32::consts::FRAC_PI_2)),
    ));
    // cube
    let rm_material_handle = raymarch_material.add(ExtendedMaterial {
            base: StandardMaterial {
                base_color: bevy::color::palettes::css::BLUE.into(),
                alpha_mode: AlphaMode::Blend,
                ..Default::default()
            },
            extension: RaymarchMaterial { roughness: 1.0 },
    });
    commands.insert_resource(RaymarchMaterialHandle(rm_material_handle.clone()));
    commands.spawn((
        Mesh3d(meshes.add(Cuboid::new(2.0, 2.0, 2.0))),
        MeshMaterial3d(rm_material_handle.clone()),
        NotShadowCaster,
        Transform::from_xyz(0.0, 0.5, 0.0),
    ));
    // cylinder
    commands.spawn((
        Mesh3d(meshes.add(Sphere::new(0.5))),
        MeshMaterial3d(materials.add(StandardMaterial {
            base_color: Color::Srgba(Srgba::rgb_u8(200, 40, 40)),
            ..Default::default()
        })),
        Transform::from_xyz(1.0, 0.5, 1.0),
    ));
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

/// this holds the current Material Handle (like a pointer) as a Resource
#[derive(Resource)]
struct RaymarchMaterialHandle(Handle<ExtendedMaterial<StandardMaterial, RaymarchMaterial>>);
