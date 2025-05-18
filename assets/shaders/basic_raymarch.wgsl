#import bevy_pbr::{
      mesh_view_bindings::view,
      forward_io::VertexOutput,
      forward_io::FragmentOutput,
      utils::coords_to_viewport_uv,
      pbr_functions::{apply_pbr_lighting, main_pass_post_lighting_processing},
      pbr_types::pbr_input_new,
      pbr_types::StandardMaterial,
      pbr_types::standard_material_new,
      pbr_functions::alpha_discard,
      pbr_fragment::pbr_input_from_standard_material,
      mesh_view_bindings::globals,
}

@group(2) @binding(100) var<uniform> object1: RaymarchObjectDescriptor;
@group(2) @binding(101) var<uniform> object2: RaymarchObjectDescriptor;
@group(2) @binding(102) var<uniform> raymarch_global_settings: RaymarchGlobalSettings;


const NEAR_CLIP = 0.5; // TODO: this is unused

@fragment
fn fragment(
    mesh: VertexOutput,
    @builtin(sample_index) sample_index: u32,
	    ) ->  FragmentOutput {
  // get the Ray direction
  let cam_pos = view.world_position;
  var viewport_uv = coords_to_viewport_uv(mesh.position.xy, view.viewport) * 2.0 - 1.0;
  viewport_uv.y *= -1;
  let clip = vec4<f32>(viewport_uv, 1.0, 1.0);
  var world = view.world_from_clip * clip;
  world /= world.w;
  let ray_dir = normalize(world.xyz - cam_pos);
  let depth = bevy_pbr::prepass_utils::prepass_depth(mesh.position, sample_index);

  // start the marching
  var curr_pos = cam_pos;
  var dist_marched = 0.0;
  var min_step_length = 1000.0; // TODO: change to +inf
  while dist_marched < raymarch_global_settings.far_clip {
      let sdf_out = sdf_world(curr_pos);
      if sdf_out.distance_to_object1 < raymarch_global_settings.termination_distance
		  || sdf_out.distance_to_object2 < raymarch_global_settings.termination_distance {
	  // HIT!

	  // color & material
	  var out: FragmentOutput;
	  var normal = vec3<f32>(0.3);
	  var material: StandardMaterial;
	  if sdf_out.distance_to_object1 < sdf_out.distance_to_object2 {
	      normal = get_normal_of_surface(curr_pos).normal_obj_1;
	      material = obj_descriptor_to_material(object1);
	    } else {
	      normal = get_normal_of_surface(curr_pos).normal_obj_2;
	      material = obj_descriptor_to_material(object2);
	  }
	  var pbr_input = pbr_input_from_standard_material(mesh, true);
	  pbr_input.material = material;
	  pbr_input.world_normal = normal;
	  pbr_input.N = normal; // this is also the normal??
	  pbr_input.world_position = vec4<f32>(curr_pos, 1.0);
	  out.color = apply_pbr_lighting(pbr_input);

	  // TODO: write to depth texture
	  // right now: if something is in front, I just discard the pixel!
	  let clip_curr_pos = view.clip_from_world * vec4<f32>(curr_pos, 1.0);
	  let ndc_curr_pos = clip_curr_pos.xyz / clip_curr_pos.w;
	  let curr_pos_depth = ndc_curr_pos.z;
	  out.color = main_pass_post_lighting_processing(pbr_input, out.color);
	  if depth > curr_pos_depth {
	      out.color.w = 0.0;
	    }

	  return out;
	}

      var step: vec3<f32>;
      if sdf_out.distance_to_object1 < sdf_out.distance_to_object2 {
	  step = ray_dir * sdf_out.distance_to_object1;
	} else {
	  step = ray_dir * sdf_out.distance_to_object2;
      }
      let step_length = length(step);
      if step_length < min_step_length {
	  min_step_length = step_length;
	}
      dist_marched += step_length;
      curr_pos += step;
    }

  // no hit :c
  var out: FragmentOutput;
  out.color = vec4<f32>(0.0);
  return out;
}

struct SdfOutput {
 distance_to_object1: f32,
 distance_to_object2: f32,
}

fn sdf_world(ray_position: vec3<f32>) -> SdfOutput {
  let rp1 = translate_ray(ray_position, object1);
  let rp2 = translate_ray(ray_position, object2);

  let distance_to_object1 = sdf_object(rp1, object1);
  let distance_to_object2 = sdf_object(rp2, object2);
  return SdfOutput(distance_to_object1, distance_to_object2);
}

// TODO: implement y and z euler angles
fn translate_ray(r: vec3<f32>, obj: RaymarchObjectDescriptor) -> vec3<f32> {
  var out = r;
  // translation
  var added_translation = vec3<f32>(0.0);
  added_translation.x = sin(globals.time * 0.5) * obj.move_amount;
  added_translation.y = cos(globals.time) * obj.move_amount;
  added_translation.z = cos(globals.time) * obj.move_amount * 0.2;
  out -= obj.world_position - added_translation;

  // rotation
  let added_rotation = obj.rotation_amount * globals.time;
  out = (vec4<f32>(out, 1.0) * rotation_mat_x(obj.rotation.x + added_rotation)).xyz;
  return out;
}

fn sdf_object(ray_position: vec3<f32>, obj: RaymarchObjectDescriptor) -> f32 {
  if obj.shape_type_id == 1 {
      return sdf_circle(ray_position, obj.shape_var1);
    } else if obj.shape_type_id == 2 {
      return sdBox(ray_position, vec3<f32>(obj.shape_var1));
    } else if obj.shape_type_id == 3 {
      // for some reason, the cone default position is really low
      // fix it here
      var rp_higher = ray_position;
      rp_higher.y -= 0.25;
      return sdConeBound(rp_higher,
			 obj.shape_var1,
			 vec2<f32>(sin(obj.shape_var2),
				   cos(obj.shape_var2)));
    }
  return 100000.0;
}

// ------------ SDF_FUNCTIONS ------------
// I got them from: https://gist.github.com/munrocket/f247155fc22ecb8edf974d905c677de1
fn sdf_circle(p: vec3<f32>, rad: f32) -> f32 {
  return length(p) - rad;
}

fn sdBox(p: vec3f, b: vec3f) -> f32 {
  let q = abs(p) - b;
  return length(max(q, vec3f(0.))) + min(max(q.x, max(q.y, q.z)), 0.);
}

fn sdConeBound(p: vec3f, h: f32, sincos: vec2f) -> f32 {
  return max(dot(sincos.yx, vec2f(length(p.xz), p.y)), -h - p.y);
}

fn opSmoothUnion(d1: f32, d2: f32, k: f32) -> f32 {
  let h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0., 1.);
  return mix(d2, d1, h) - k * h * (1. - h);
}

// stolen from https://github.com/rust-adventure/bevy-examples/blob/fabbb45b5c6adbfc8d317c95fcd9097b08666c7c/examples/raymarch-sphere/assets/shaders/sdf.wgsl#L160
fn get_normal_of_surface(position_of_hit: vec3<f32>) -> SdfNormalOutput {

  let tiny_change_x = vec3(0.001, 0.0, 0.0);
  let tiny_change_y = vec3(0.0 , 0.001 , 0.0);
  let tiny_change_z = vec3(0.0 , 0.0 , 0.001);

  let up_tiny_change_in_x1: f32 = sdf_world(position_of_hit + tiny_change_x).distance_to_object1;
  let down_tiny_change_in_x1: f32 = sdf_world(position_of_hit - tiny_change_x).distance_to_object1;
  let tiny_change_in_x1: f32 = up_tiny_change_in_x1 - down_tiny_change_in_x1;


  let up_tiny_change_in_y1: f32 = sdf_world(position_of_hit + tiny_change_y).distance_to_object1;
  let down_tiny_change_in_y1: f32 = sdf_world(position_of_hit - tiny_change_y).distance_to_object1;
  let tiny_change_in_y1: f32 = up_tiny_change_in_y1 - down_tiny_change_in_y1;


  let up_tiny_change_in_z1: f32 = sdf_world(position_of_hit + tiny_change_z).distance_to_object1;
  let down_tiny_change_in_z1: f32 = sdf_world(position_of_hit - tiny_change_z).distance_to_object1;
  let tiny_change_in_z1: f32 = up_tiny_change_in_z1 - down_tiny_change_in_z1;


  let normal_dir1 = vec3(
		    tiny_change_in_x1,
		    tiny_change_in_y1,
		    tiny_change_in_z1,
		    );

  let normal1 = normalize(normal_dir1);

  // DRY people are shaking rn
  let up_tiny_change_in_x2: f32 = sdf_world(position_of_hit + tiny_change_x).distance_to_object2;
  let down_tiny_change_in_x2: f32 = sdf_world(position_of_hit - tiny_change_x).distance_to_object2;
  let tiny_change_in_x2: f32 = up_tiny_change_in_x2 - down_tiny_change_in_x2;


  let up_tiny_change_in_y2: f32 = sdf_world(position_of_hit + tiny_change_y).distance_to_object2;
  let down_tiny_change_in_y2: f32 = sdf_world(position_of_hit - tiny_change_y).distance_to_object2;
  let tiny_change_in_y2: f32 = up_tiny_change_in_y2 - down_tiny_change_in_y2;


  let up_tiny_change_in_z2: f32 = sdf_world(position_of_hit + tiny_change_z).distance_to_object2;
  let down_tiny_change_in_z2: f32 = sdf_world(position_of_hit - tiny_change_z).distance_to_object2;
  let tiny_change_in_z2: f32 = up_tiny_change_in_z2 - down_tiny_change_in_z2;


  let normal_dir2 = vec3(
		    tiny_change_in_x2,
		    tiny_change_in_y2,
		    tiny_change_in_z2,
		    );

  let normal2 = normalize(normal_dir2);

  return SdfNormalOutput(normal1, normal2);
}
struct SdfNormalOutput {
 normal_obj_1: vec3<f32>,
 normal_obj_2: vec3<f32>,
}


struct RaymarchObjectDescriptor {
 world_position: vec3<f32>,
 rotation: vec3<f32>,
 move_amount: f32,
 rotation_amount: f32,
 // read src/main.rs RaymarchObjectDescriptor for explaination
 shape_type_id: u32,
 shape_var1: f32,
 shape_var2: f32,
 base_color: vec4<f32>,
 emissive: vec4<f32>,
 reflectance: vec3<f32>,
 perceptual_roughness: f32,
 metallic: f32,
 diffuse_transmission: f32,
 specular_transmission: f32,
 thickness: f32,
 ior: f32,
 attenuation_distance: f32,
 attenuation_color: vec4<f32>,
 clearcoat: f32,
 clearcoat_perceptual_roughness: f32,
 anisotropy_strength: f32,
 anisotropy_rotation: vec2<f32>,
}

struct RaymarchGlobalSettings {
 intersection_method: u32,
 intersection_smooth_amount: f32,
 glow_range: f32,
 glow_color: vec4<f32>,
 far_clip: f32,
 termination_distance: f32
}


/// used for getting the material transition between 2 objects
/// lerp_val is 0.0-1.0, where 0 is just at desc1, and 1 is just at desc2.
fn lerp_descriptors(desc1: RaymarchObjectDescriptor,
		    desc2: RaymarchObjectDescriptor,
		    lerp_val: f32) -> RaymarchObjectDescriptor {
  let desc1_amount = 1.0 - lerp_val;
  let desc2_amount = lerp_val;
  var out = desc1;

  out.base_color = desc1.base_color * desc1_amount + desc2.base_color * desc2_amount;
  out.emissive = desc1.emissive * desc1_amount + desc2.emissive * desc2_amount;
  out.reflectance = desc1.reflectance * desc1_amount + desc2.reflectance * desc2_amount;
  out.perceptual_roughness = desc1.perceptual_roughness * desc1_amount + desc2.perceptual_roughness * desc2_amount;
  out.metallic = desc1.metallic * desc1_amount + desc2.metallic * desc2_amount;
  out.diffuse_transmission = desc1.diffuse_transmission * desc1_amount + desc2.diffuse_transmission * desc2_amount;
  out.specular_transmission =
    desc1.specular_transmission * desc1_amount + desc2.specular_transmission * desc2_amount;
  out.thickness = desc1.thickness * desc1_amount + desc2.thickness * desc2_amount;
  out.ior = desc1.ior * desc1_amount + desc2.ior * desc2_amount;
  out.attenuation_distance = desc1.attenuation_distance * desc1_amount + desc2.attenuation_distance * desc2_amount;
  out.attenuation_color = desc1.attenuation_color * desc1_amount + desc2.attenuation_color * desc2_amount;
  out.clearcoat = desc1.clearcoat * desc1_amount + desc2.clearcoat * desc2_amount;
  out.clearcoat_perceptual_roughness =
    desc1.clearcoat_perceptual_roughness * desc1_amount + desc2.clearcoat_perceptual_roughness * desc2_amount;
  out.anisotropy_strength = desc1.anisotropy_strength * desc1_amount + desc2.anisotropy_strength * desc2_amount;
  out.anisotropy_rotation = desc1.anisotropy_rotation * desc1_amount + desc2.anisotropy_rotation * desc2_amount;

  return out;
}


fn obj_descriptor_to_material(desc: RaymarchObjectDescriptor) -> StandardMaterial {
  var mat = standard_material_new();

  mat.base_color = desc.base_color;
  mat.perceptual_roughness = desc.perceptual_roughness;
  mat.emissive = desc.emissive;
  mat.reflectance = desc.reflectance;
  mat.metallic = desc.metallic;
  mat.diffuse_transmission = desc.diffuse_transmission;
  mat.specular_transmission = desc.specular_transmission;
  mat.thickness = desc.thickness;
  mat.ior = desc.ior;
  mat.attenuation_distance = desc.attenuation_distance;
  mat.attenuation_color = desc.attenuation_color;
  mat.clearcoat = desc.clearcoat;
  mat.clearcoat_perceptual_roughness = desc.clearcoat_perceptual_roughness;
  mat.anisotropy_strength = desc.anisotropy_strength;
  mat.anisotropy_rotation = desc.anisotropy_rotation;

  return mat;
}

fn rotation_mat_x(angle_x: f32) -> mat4x4<f32> {
  return mat4x4<f32>(
		     vec4<f32>(1.0, 0.0, 0.0, 0.0),
		     vec4<f32>(0.0, cos(angle_x), sin(angle_x), 0.0),
		     vec4<f32>(0.0, -sin(angle_x), cos(angle_x), 0.0),
		     vec4<f32>(0.0, 0.0, 0.0, 1.0));
}
