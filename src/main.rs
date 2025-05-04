use bevy::{
    core_pipeline::prepass::{DepthPrepass, MotionVectorPrepass, NormalPrepass},
    prelude::*,
    render::render_resource::AsBindGroup,
};

fn main() {
    App::new()
        .add_plugins((
            DefaultPlugins,
            MaterialPlugin::<RaymarchMaterial>::default(),
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
    look_at: Vec3,
}

fn spin_camera(mut cams: Query<(&mut Transform, &SpinningCam)>, time: Res<Time>) {
    cams.iter_mut()
        .for_each(|(mut transform, spinning_cam_vars)| {
            let new_z =
                (time.elapsed_secs() * spinning_cam_vars.speed).cos() * spinning_cam_vars.distance;
            let new_x =
                (time.elapsed_secs() * spinning_cam_vars.speed).sin() * spinning_cam_vars.distance;
            let sway_y = (time.elapsed_secs() * spinning_cam_vars.speed / 0.35).sin();
            let new_transform = Transform::from_xyz(new_x, spinning_cam_vars.height + sway_y, new_z)
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
            distance: 2.0,
            speed: 0.5,
            look_at: Vec3::new(0.0, 0.5, 0.0),
        },
        DepthPrepass,
        NormalPrepass,
        MotionVectorPrepass,
    ));
}

// my RayMarch Material
#[derive(Asset, TypePath, AsBindGroup, Debug, Clone)]
struct RaymarchMaterial {}

impl Material for RaymarchMaterial {
    fn fragment_shader() -> bevy::render::render_resource::ShaderRef {
        "shaders/basic_raymarch.wgsl".into()
    }

    fn alpha_mode(&self) -> AlphaMode {
        AlphaMode::Blend
    }
}

fn spawn_shit(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
    mut raymarch_material: ResMut<Assets<RaymarchMaterial>>,
) {
    // circular base
    commands.spawn((
        Mesh3d(meshes.add(Circle::new(4.0))),
        MeshMaterial3d(materials.add(Color::WHITE)),
        Transform::from_rotation(Quat::from_rotation_x(-std::f32::consts::FRAC_PI_2)),
    ));
    // cube
    commands.spawn((
        Mesh3d(meshes.add(Cuboid::new(2.0, 2.0, 2.0))),
        MeshMaterial3d(raymarch_material.add(RaymarchMaterial {})),
        Transform::from_xyz(0.0, 0.5, 0.0),
    ));
    // light
    commands.spawn((
        PointLight {
            shadows_enabled: true,
            ..default()
        },
        Transform::from_xyz(4.0, 8.0, 4.0),
    ));
}
