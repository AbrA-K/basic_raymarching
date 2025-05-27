use core::f32;

use bevy::{pbr::ExtendedMaterial, prelude::*};
use bevy_egui::{
    self,
    egui::{self, Color32},
    EguiContextPass, EguiContexts, EguiPlugin,
};

use crate::{RaymarchMaterial, RaymarchMaterialHandle, RaymarchObjectDescriptor, SpinningCam};

pub struct MyRaymarchUi;
impl Plugin for MyRaymarchUi {
    fn build(&self, app: &mut App) {
        app.init_resource::<UiState>();
        app.add_plugins(EguiPlugin {
            enable_multipass_for_primary_context: false,
        });
        app.add_systems(
            EguiContextPass,
            (
                camera_settings_ui,
                object_settings_ui,
                global_settings_ui,
                ui_settings_ui,
            ),
        );
    }
}

fn global_settings_ui(
    mut contexts: EguiContexts,
    mut rm_materials: ResMut<Assets<ExtendedMaterial<StandardMaterial, RaymarchMaterial>>>,
    rm_material_handle: Res<RaymarchMaterialHandle>,
    ui_state: Res<UiState>,
) {
    if ui_state.into_inner() == &UiState::Minimal {
        return;
    }
    let maybe_mat = rm_materials.get_mut(&rm_material_handle.0);
    if let Some(mat) = maybe_mat {
        egui::Window::new("Global Settings").show(contexts.ctx_mut(), |ui| {
            ui.horizontal(|ui| {
                ui.label("far clip");
                ui.add(egui::Slider::new(
                    &mut mat.extension.raymarch_global_settings.far_clip,
                    0.0..=20.0,
                ));
            });
            ui.horizontal(|ui| {
                ui.label("termination distance");
                ui.add(egui::Slider::new(
                    &mut mat.extension.raymarch_global_settings.termination_distance,
                    0.0001..=0.5,
                ));
            });
            ui.horizontal(|ui| {
                ui.label("glow_range");
                ui.add(egui::Slider::new(
                    &mut mat.extension.raymarch_global_settings.glow_range,
                    0.0..=1.0,
                ));
            });
            ui.horizontal(|ui| {
                ui.label("glow_color");
                let mut color32 =
                    vec4_to_color32(&mat.extension.raymarch_global_settings.glow_color);
                ui.color_edit_button_srgba(&mut color32);
                mat.extension.raymarch_global_settings.glow_color = color32_to_vec4(color32);
            });
            ui.horizontal(|ui| {
                ui.label("intersection method");
                ui.vertical(|ui| {
                    ui.radio_value(
                        &mut mat.extension.raymarch_global_settings.intersection_method,
                        IntersectionMethod::Or as u32,
                        "1 OR 2",
                    );
                    ui.radio_value(
                        &mut mat.extension.raymarch_global_settings.intersection_method,
                        IntersectionMethod::And as u32,
                        "1 AND 2",
                    );
                    ui.radio_value(
                        &mut mat.extension.raymarch_global_settings.intersection_method,
                        IntersectionMethod::Not as u32,
                        "1 NOT 2",
                    );
                });
            });
            ui.horizontal(|ui| {
                ui.label("smooth intersection");
                ui.add(egui::Slider::new(
                    &mut mat
                        .extension
                        .raymarch_global_settings
                        .intersection_smooth_amount,
                    0.0..=1.0,
                ));
            });
        });
    }
}

fn camera_settings_ui(
    mut contexts: EguiContexts,
    mut cameras: Query<&mut SpinningCam>,
    ui_state: Res<UiState>,
) {
    if ui_state.into_inner() == &UiState::Minimal {
        return;
    }
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

fn ui_settings_ui(
    mut contexts: EguiContexts,
    mut ui_state: ResMut<UiState>,
    mut rm_materials: ResMut<Assets<ExtendedMaterial<StandardMaterial, RaymarchMaterial>>>,
    rm_material_handle: Res<RaymarchMaterialHandle>,
) {
    egui::Window::new("Quick Settings").show(contexts.ctx_mut(), |ui| {
        ui.label("depth reading cannot work on web!!");
        ui.horizontal(|ui| {
            ui.label("UI Mode");
            ui.vertical(|ui| {
                ui.radio_value(&mut *ui_state, UiState::Minimal, "Minimal");
                ui.radio_value(&mut *ui_state, UiState::Full, "Full");
            });
        });
        ui.horizontal(|ui| {
            ui.label("Demos");
            let maybe_mat = rm_materials.get_mut(&rm_material_handle.0);
            if let Some(mat) = maybe_mat {
                ui.horizontal(|ui| {
                    ui.label("load config");
                    ui.vertical(|ui| {
                        let default_prototype_button = ui.button("Default");
                        if default_prototype_button.clicked() {
                            mat.extension = RaymarchMaterial::get_basic_config()
                        }
                        let smooth_prototype_button = ui.button("Smooth Intersection");
                        if smooth_prototype_button.clicked() {
                            mat.extension = RaymarchMaterial::get_smooth_config()
                        }
                        let intersection_prototype_button = ui.button("NOT Intersection");
                        if intersection_prototype_button.clicked() {
                            mat.extension = RaymarchMaterial::get_intersection_config()
                        }
                    });
                });
            }
        });
    });
}

fn object_settings_ui(
    mut contexts: EguiContexts,
    mut rm_materials: ResMut<Assets<ExtendedMaterial<StandardMaterial, RaymarchMaterial>>>,
    rm_material_handle: Res<RaymarchMaterialHandle>,
    ui_state: Res<UiState>,
) {
    if ui_state.into_inner() == &UiState::Minimal {
        return;
    }
    let rm_material = rm_materials.get_mut(&rm_material_handle.0);
    if let Some(mat) = rm_material {
        egui::Window::new("Object 1 Settings").show(contexts.ctx_mut(), |ui| {
            create_object_settings(ui, &mut mat.extension.material1);
        });
        egui::Window::new("Object 2 Settings").show(contexts.ctx_mut(), |ui| {
            create_object_settings(ui, &mut mat.extension.material2);
        });
    }
}

fn create_object_settings(ui: &mut egui::Ui, desc: &mut RaymarchObjectDescriptor) {
    ui.horizontal(|ui| {
        ui.label("Shape");
        ui.radio_value(&mut desc.shape_type_id, Shape::Circle as u32, "Sphere");
        ui.radio_value(&mut desc.shape_type_id, Shape::Cube as u32, "Cube");
        ui.radio_value(&mut desc.shape_type_id, Shape::Cone as u32, "Cone");
    });
    ui.heading("Transform");
    ui.horizontal(|ui| {
        ui.label("x position");
        ui.add(egui::Slider::new(&mut desc.world_position.x, -1.0..=1.0))
    });
    ui.horizontal(|ui| {
        ui.label("y position");
        ui.add(egui::Slider::new(&mut desc.world_position.y, -1.0..=1.0));
    });
    ui.horizontal(|ui| {
        ui.label("z position");
        ui.add(egui::Slider::new(&mut desc.world_position.z, -1.0..=1.0));
    });
    ui.horizontal(|ui| {
        ui.label("rotation x");
        ui.add(egui::Slider::new(
            &mut desc.rotation.x,
            -f32::consts::PI..=f32::consts::PI,
        ))
    });
    ui.horizontal(|ui| {
        ui.label("rotation over time");
        ui.add(egui::Slider::new(&mut desc.rotation_amount, 0.0..=1.0))
    });
    ui.horizontal(|ui| {
        ui.label("translation over time");
        ui.add(egui::Slider::new(&mut desc.move_amout, 0.0..=1.0))
    });

    ui.heading("Material");
    ui.horizontal(|ui| {
        ui.label("roughness");
        ui.add(egui::Slider::new(&mut desc.perceptual_roughness, 0.0..=1.0))
    });
    ui.horizontal(|ui| {
        ui.label("base color");
        let mut color32 = vec4_to_color32(&desc.base_color);
        ui.color_edit_button_srgba(&mut color32);
        desc.base_color = color32_to_vec4(color32);
    });
    ui.horizontal(|ui| {
        ui.label("reflectance");
        let mut color = desc.reflectance.to_array().map(|e| (e * 255.0) as u8);
        ui.color_edit_button_srgb(&mut color);
        desc.reflectance = Vec3::new(
            color[0] as f32 / 255.0,
            color[1] as f32 / 255.0,
            color[2] as f32 / 255.0,
        );
    });
    ui.horizontal(|ui| {
        ui.label("emissive");
        let mut color32 = vec4_to_color32(&desc.emissive);
        ui.color_edit_button_srgba(&mut color32);
        desc.emissive = color32_to_vec4(color32);
    });
    ui.horizontal(|ui| {
        ui.label("metallic");
        ui.add(egui::Slider::new(&mut desc.metallic, 0.0..=1.0))
    });
    ui.horizontal(|ui| {
        ui.label("clearcoat");
        ui.add(egui::Slider::new(&mut desc.clearcoat, 0.0..=1.0))
    });
    ui.horizontal(|ui| {
        ui.label("clearcoat roughness");
        ui.add(egui::Slider::new(
            &mut desc.clearcoat_perceptual_roughness,
            0.0..=1.0,
        ))
    });
    ui.add(egui::Label::new(
        "hätte noch mehr Möglichkeiten, aber will nicht overcrouden",
    ));
}

fn vec4_to_color32(vec: &Vec4) -> Color32 {
    let r = (vec.x * 255.0) as u8;
    let g = (vec.y * 255.0) as u8;
    let b = (vec.z * 255.0) as u8;
    let a = (vec.w * 255.0) as u8;
    return Color32::from_rgba_premultiplied(r, g, b, a);
}

fn color32_to_vec4(color: Color32) -> Vec4 {
    let r = color.r() as f32 / 255.0;
    let g = color.g() as f32 / 255.0;
    let b = color.b() as f32 / 255.0;
    let a = color.a() as f32 / 255.0;
    return Vec4::new(r, g, b, a);
}

#[derive(PartialEq)]
enum Shape {
    Circle = 1,
    Cube = 2,
    Cone = 3,
}

#[derive(PartialEq)]
enum IntersectionMethod {
    Or = 0,
    And = 1,
    Not = 2,
}

#[derive(Resource, PartialEq)]
enum UiState {
    Full,
    Minimal,
}

impl Default for UiState {
    fn default() -> Self {
        UiState::Minimal
    }
}
