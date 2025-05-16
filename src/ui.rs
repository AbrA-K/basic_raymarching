use bevy::{pbr::ExtendedMaterial, prelude::*};
use bevy_egui::{self, egui, EguiContextPass, EguiContexts, EguiPlugin};

use crate::{RaymarchMaterial, RaymarchMaterialHandle, SpinningCam};

pub struct MyRaymarchUi;
impl Plugin for MyRaymarchUi {
    fn build(&self, app: &mut App) {
        app.add_plugins(EguiPlugin {
            enable_multipass_for_primary_context: true,
        });
        app.add_systems(EguiContextPass, (camera_settings_ui, raymarch_settings_ui));
    }
}

fn camera_settings_ui(mut contexts: EguiContexts, mut cameras: Query<&mut SpinningCam>) {
    egui::Window::new("Camera Settings").show(contexts.ctx_mut(), |ui| {
        for mut cam in cameras.iter_mut() {
            ui.horizontal(|ui| {
                ui.label("Speed:");
                ui.add(egui::Slider::new(&mut cam.speed, 0.0..=1.0));
            });
            ui.horizontal(|ui| {
                ui.label("Distance:");
                ui.add(egui::Slider::new(&mut cam.distance, 0.0..=10.0));
            });
            ui.horizontal(|ui| {
                ui.label("height:");
                ui.add(egui::Slider::new(&mut cam.height, 0.0..=10.0));
            });
            ui.horizontal(|ui| {
                ui.label("sway:");
                ui.add(egui::Slider::new(&mut cam.sway_amount, 0.0..=1.0));
            });
        }
    });
}

fn raymarch_settings_ui(
    mut contexts: EguiContexts,
    mut rm_materials: ResMut<Assets<ExtendedMaterial<StandardMaterial, RaymarchMaterial>>>,
    rm_material_handle: Res<RaymarchMaterialHandle>,
) {
    let rm_material = rm_materials.get_mut(&rm_material_handle.0);
    if let Some(mat) = rm_material {
	egui::Window::new("Raymarch Settings").show(contexts.ctx_mut(), |ui| {
            ui.horizontal(|ui| {
		ui.label("roughness");
		ui.add(egui::Slider::new(&mut mat.extension.roughness, 0.0..=1.0))
            })
	});
    }
}
