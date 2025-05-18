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

const MARCH_MIN_DIST = 0.001;
const FAR_CLIP = 10.0;
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
  let radius = 0.5;
  var min_step_length = 1000.0; // TODO: change to +inf
  while dist_marched < FAR_CLIP {
      let sdf_out = sdf_world(curr_pos);
      if sdf_out.distance_to_surface < MARCH_MIN_DIST {
	  // HIT!

	  // color & material
	  var out: FragmentOutput;
	  var pbr_input = pbr_input_from_standard_material(mesh, true);
	  pbr_input.material.base_color = object1.base_color;
	  pbr_input.material.perceptual_roughness = object1.perceptual_roughness;

	  pbr_input.material.emissive = object1.emissive;
	  pbr_input.material.reflectance = object1.reflectance;
	  pbr_input.material.metallic = object1.metallic;
	  pbr_input.material.diffuse_transmission = object1.diffuse_transmission;
	  pbr_input.material.specular_transmission = object1.specular_transmission;
	  pbr_input.material.thickness = object1.thickness;
	  pbr_input.material.ior = object1.ior;
	  pbr_input.material.attenuation_distance = object1.attenuation_distance;
	  pbr_input.material.attenuation_color = object1.attenuation_color;
	  pbr_input.material.clearcoat = object1.clearcoat;
	  pbr_input.material.clearcoat_perceptual_roughness = object1.clearcoat_perceptual_roughness;
	  pbr_input.material.anisotropy_strength = object1.anisotropy_strength;
	  pbr_input.material.anisotropy_rotation = object1.anisotropy_rotation;



	  pbr_input.world_normal = get_normal_of_surface(curr_pos);
	  pbr_input.N = get_normal_of_surface(curr_pos); // this is also the normal??
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

      let step = ray_dir * sdf_out.distance_to_surface;
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
 distance_to_surface: f32,
 id: u32,
}

fn sdf_world(ray_position: vec3<f32>) -> SdfOutput {
  let radius = 0.5;
  var distance_to_surface = 100.0; // TODO: make +inf
  var rp1 = ray_position;

  // translation
  var added_translation = vec3<f32>(0.0);
  added_translation.x = sin(globals.time * 0.5) * object1.move_amount;
  added_translation.y = cos(globals.time) * object1.move_amount;
  added_translation.z = cos(globals.time) * object1.move_amount * 0.2;
  rp1 -= object1.world_position - added_translation;

  // rotation
  let added_rotation = object1.rotation_amount * globals.time;
  rp1 = (vec4<f32>(rp1, 1.0) * rotation_mat_x(object1.rotation.x + added_rotation)).xyz;

  // for some reason, the cone default position is really low
  // fix it here
  if object1.shape_type_id == 3 {
      var rp_higher = ray_position;
      rp_higher.y -= 0.25;
    }

  if object1.shape_type_id == 1 {
      distance_to_surface = sdf_circle(rp1,
				       object1.shape_var1);
    } else if object1.shape_type_id == 2 {
      distance_to_surface = sdBox(rp1,
				  vec3<f32>(object1.shape_var1));
    } else if object1.shape_type_id == 3 {
      distance_to_surface = sdConeBound(rp1,
					object1.shape_var1,
					vec2<f32>(sin(object1.shape_var2),
						  cos(object1.shape_var2)));
    }
  return SdfOutput(distance_to_surface, 0);
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


// stolen from https://github.com/rust-adventure/bevy-examples/blob/fabbb45b5c6adbfc8d317c95fcd9097b08666c7c/examples/raymarch-sphere/assets/shaders/sdf.wgsl#L160
fn get_normal_of_surface(position_of_hit: vec3<f32>) -> vec3<f32> {

  let tiny_change_x = vec3(0.001, 0.0, 0.0);
  let tiny_change_y = vec3(0.0 , 0.001 , 0.0);
  let tiny_change_z = vec3(0.0 , 0.0 , 0.001);

  let up_tiny_change_in_x: f32 = sdf_world(position_of_hit + tiny_change_x).distance_to_surface;
  let down_tiny_change_in_x: f32 = sdf_world(position_of_hit - tiny_change_x).distance_to_surface;

  let tiny_change_in_x: f32 = up_tiny_change_in_x - down_tiny_change_in_x;


  let up_tiny_change_in_y: f32 = sdf_world(position_of_hit + tiny_change_y).distance_to_surface;
  let down_tiny_change_in_y: f32 = sdf_world(position_of_hit - tiny_change_y).distance_to_surface;

  let tiny_change_in_y: f32 = up_tiny_change_in_y - down_tiny_change_in_y;


  let up_tiny_change_in_z: f32 = sdf_world(position_of_hit + tiny_change_z).distance_to_surface;
  let down_tiny_change_in_z: f32 = sdf_world(position_of_hit - tiny_change_z).distance_to_surface;

  let tiny_change_in_z: f32 = up_tiny_change_in_z - down_tiny_change_in_z;


  let normal = vec3(
		    tiny_change_in_x,
		    tiny_change_in_y,
		    tiny_change_in_z
		    );

  return normalize(normal);
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
// this does not exist in the base spec
// lol, lmao even
// https://github.com/gpuweb/gpuweb/issues/3987
fn modulo_euclidean (a: f32, b: f32) -> f32 {
	var m = a % b;
	if (m < 0.0) {
		if (b < 0.0) {
			m -= b;
		} else {
			m += b;
		}
	}
	return m;
}

/// used for getting the material transition between 2 objects
/// lerp_val is 0.0-1.0, where 0 is just at desc1, and 1 is just at desc2.
// fn lerp_descriptors(desc1: RaymarchObjectDescriptor,
// 		    desc2: RaymarchObjectDescriptor,
// 		    lerp_val: f32) -> RaymarchObjectDescriptor {

// }

// fn obj_descriptor_to_material(desc: RaymarchObjectDescriptor) -> StandardMaterial {
//   var mat = standard_material_new();
//   return mat;
// }

fn rotation_mat_x(angle_x: f32) -> mat4x4<f32> {
  return mat4x4<f32>(
		     vec4<f32>(1.0, 0.0, 0.0, 0.0),
		     vec4<f32>(0.0, cos(angle_x), sin(angle_x), 0.0),
		     vec4<f32>(0.0, -sin(angle_x), cos(angle_x), 0.0),
		     vec4<f32>(0.0, 0.0, 0.0, 1.0));
}
