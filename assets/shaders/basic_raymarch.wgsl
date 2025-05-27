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

@fragment
fn fragment(
	    mesh: VertexOutput,
	    // @builtin(sample_index) sample_index: u32,
	    ) ->  FragmentOutput {
  let march = perform_march(mesh.position.xy);
  let sdf_out = sdf_world(march.hit_pos);

  if march.has_hit {
      // return color & material
      var out: FragmentOutput;
      var normal = get_normal_of_surface(march.hit_pos);
      var material: StandardMaterial;
      var distances = vec2<f32>(sdf_out.distance_to_1object, sdf_out.distance_to_2object);
      distances = normalize(distances);
      let material_lerp_amount = ((distances.x - distances.y) + 1.0) * 0.5;
      let desc = lerp_descriptors(object1, object2, material_lerp_amount);

      material = obj_descriptor_to_material(desc);
      var pbr_input = pbr_input_new();
      pbr_input.material = material;
      pbr_input.world_normal = normal;
      pbr_input.N = normal; // this is also the normal??
      pbr_input.V = normal; // this is also the normal??
      pbr_input.world_position = vec4<f32>(march.hit_pos, 1.0);
      out.color = apply_pbr_lighting(pbr_input);

      // TODO: write to depth texture
      // right now: if something is in front, I just discard the pixel!
      // also: we cannot read from depth texture in webgl2
#ifdef WEBGL2
      return out;
#else
      let depth = bevy_pbr::prepass_utils::prepass_depth(mesh.position, 0);
      let clip_curr_pos = view.clip_from_world * vec4<f32>(march.hit_pos, 1.0);
      let ndc_curr_pos = clip_curr_pos.xyz / clip_curr_pos.w;
      let curr_pos_depth = ndc_curr_pos.z;
      out.color = main_pass_post_lighting_processing(pbr_input, out.color);
      if depth > curr_pos_depth {
	  out.color.w = 0.0;
	}
      return out;
#endif //WEBGL2
    } else {
    var out: FragmentOutput;
    let min_step_normalized = march.min_dist_from_object / raymarch_global_settings.glow_range;
    let glow_amount = (clamp(min_step_normalized, 0.0, 1.0) * -1.0 + 1.0)
      * raymarch_global_settings.glow_color.w;
    out.color = vec4<f32>(raymarch_global_settings.glow_color.xyz, glow_amount);
    return out;
  }
}

// depending if it has_hit some data is left empty/useless
// unions would go crazy here
struct MarchOutput {
 has_hit: bool,
 hit_pos: vec3<f32>,
 min_dist_from_object: f32,
};
fn perform_march(
		 coord: vec2<f32>,
		 // sample_index: u32,
) -> MarchOutput {
  // get the Ray direction
  let cam_pos = view.world_position;
  var viewport_uv = coords_to_viewport_uv(coord, view.viewport) * 2.0 - 1.0;
  viewport_uv.y *= -1;
  let clip = vec4<f32>(viewport_uv, 1.0, 1.0);
  var world = view.world_from_clip * clip;
  world /= world.w;
  let ray_dir = normalize(world.xyz - cam_pos);

  // start the marching
  var curr_pos = cam_pos;
  var dist_marched = 0.0;
  var min_step_length = 1000.0; // TODO: change to +inf
  while dist_marched < raymarch_global_settings.far_clip {
      let sdf_out = sdf_world(curr_pos);
      if my_min(sdf_out.distance_to_1object, sdf_out.distance_to_2object)
		 < raymarch_global_settings.termination_distance {
	  // HIT!
	  return MarchOutput(true, curr_pos, 0.0);
	}

      // no hit yet, continue marching..
      var step: vec3<f32>;
      let step_min_distance = my_min(sdf_out.distance_to_1object,
				     sdf_out.distance_to_2object);
      step = ray_dir * step_min_distance;
      let step_length = length(step);
      if step_length < min_step_length {
	  min_step_length = step_length;
	}
      dist_marched += step_length;
      curr_pos += step;
    }

  // no hit :c
  return MarchOutput(false, vec3<f32>(0.0), min_step_length);
}

struct SdfOutput {
 distance_to_1object: f32,
 distance_to_2object: f32,
}
fn sdf_world(ray_position: vec3<f32>) -> SdfOutput {
  let rp1 = translate_ray(ray_position, object1);
  let rp2 = translate_ray(ray_position, object2);

  let distance_to_1object = sdf_object(rp1, object1);
  let distance_to_2object = sdf_object(rp2, object2);
  return SdfOutput(distance_to_1object, distance_to_2object);
}

fn sdf_object(ray_position: vec3<f32>, obj: RaymarchObjectDescriptor) -> f32 {
  if obj.shape_type_id == 1 {
      return sdf_circle(ray_position, obj.shape_1var);
    } else if obj.shape_type_id == 2 {
      return sdBox(ray_position, vec3<f32>(obj.shape_1var));
    } else if obj.shape_type_id == 3 {
      // for some reason, the cone default position is really low
      // fix it here
      var rp_higher = ray_position;
      rp_higher.y -= 0.25;
      return sdConeBound(rp_higher,
			 obj.shape_1var,
			 vec2<f32>(sin(obj.shape_2var),
				   cos(obj.shape_2var)));
    }
  return 100000.0;
}

//   ,--.                                 ,---.                                  ,--.  ,--.
// ,-'  '-.,--.--. ,--,--.,--,--,  ,---. /  .-' ,---. ,--.--.,--,--,--. ,--,--.,-'  '-.`--' ,---. ,--,--,
// '-.  .-'|  .--'' ,-.  ||      \(  .-' |  `-,| .-. ||  .--'|        |' ,-.  |'-.  .-',--.| .-. ||      \
//   |  |  |  |   \ '-'  ||  ||  |.-'  `)|  .-'' '-' '|  |   |  |  |  |\ '-'  |  |  |  |  |' '-' '|  ||  |
//   `--'  `--'    `--`--'`--''--'`----' `--'   `---' `--'   `--`--`--' `--`--'  `--'  `--' `---' `--''--'
// transformation
// TODO: implement y and z euler angles
fn translate_ray(r: vec3<f32>, obj: RaymarchObjectDescriptor) -> vec3<f32> {
  var out = r;
  // translation
  var added_translation = vec3<f32>(0.0);
  added_translation.x = sin(raymarch_global_settings.time * 0.5) * obj.move_amount;
  added_translation.y = cos(raymarch_global_settings.time) * obj.move_amount;
  added_translation.z = cos(raymarch_global_settings.time) * obj.move_amount * 0.2;
  out -= obj.world_position - added_translation;

  // rotation
  let added_rotation = obj.rotation_amount * raymarch_global_settings.time;
  out = (vec4<f32>(out, 1.0) * rotation_mat_x(obj.rotation.x + added_rotation)).xyz;
  return out;
}

fn rotation_mat_x(angle_x: f32) -> mat4x4<f32> {
  return mat4x4<f32>(
		     vec4<f32>(1.0, 0.0, 0.0, 0.0),
		     vec4<f32>(0.0, cos(angle_x), sin(angle_x), 0.0),
		     vec4<f32>(0.0, -sin(angle_x), cos(angle_x), 0.0),
		     vec4<f32>(0.0, 0.0, 0.0, 1.0));
}


fn my_min(a: f32, b: f32) -> f32 {
  if raymarch_global_settings.intersection_method == 0 {
      return opSmoothUnion(a, b, raymarch_global_settings.intersection_smooth_amount);
    } else if raymarch_global_settings.intersection_method == 1 {
      return opSmoothIntersect(a, b, raymarch_global_settings.intersection_smooth_amount);
    } else if raymarch_global_settings.intersection_method == 2 {
      return opSmoothSubtract(a, b, raymarch_global_settings.intersection_smooth_amount);
    }
  return 100000.0; // Todo: +inf
}


//  ,---.  ,------.  ,------.    ,------.                        ,--.  ,--.
// '   .-' |  .-.  \ |  .---'    |  .---',--.,--.,--,--,  ,---.,-'  '-.`--' ,---. ,--,--,  ,---.
// `.  `-. |  |  \  :|  `--,     |  `--, |  ||  ||      \| .--''-.  .-',--.| .-. ||      \(  .-'
// .-'    ||  '--'  /|  |`       |  |`   '  ''  '|  ||  |\ `--.  |  |  |  |' '-' '|  ||  |.-'  `)
// `-----' `-------' `--'        `--'     `----' `--''--' `---'  `--'  `--' `---' `--''--'`----'
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

fn opSmoothSubtract(d1: f32, d2: f32, k: f32) -> f32 {
  let h = clamp(0.5 - 0.5 * (d1 + d2) / k, 0., 1.);
  return mix(d1, -d2, h) + k * h * (1. - h);
}

fn opSmoothIntersect(d1: f32, d2: f32, k: f32) -> f32 {
  let h = clamp(0.5 - 0.5 * (d2 - d1) / k, 0., 1.);
  return mix(d2, d1, h) + k * h * (1. - h);
}


fn smin_circular(a: f32, b: f32, k: f32) -> f32 {
  let km = k * (1.0/(1.0-sqrt(0.5)));
  let h = max(k - abs(a-b), 0.0) / k;
  return min(a,b) - k * 0.5 * (1.0 + h - sqrt(1.0 - h * (h - 2.0)));
}

// stolen from https://github.com/rust-adventure/bevy-examples/blob/fabbb45b5c6adbfc8d317c95fcd9097b08666c7c/examples/raymarch-sphere/assets/shaders/sdf.wgsl#L160
fn get_normal_of_surface(position_of_hit: vec3<f32>) -> vec3<f32> {
  let tiny_change_x = vec3(0.001, 0.0, 0.0);
  let tiny_change_y = vec3(0.0 , 0.001 , 0.0);
  let tiny_change_z = vec3(0.0 , 0.0 , 0.001);

  let up_tiny_change_in_x: f32 = my_min(sdf_world(position_of_hit + tiny_change_x).distance_to_1object,
					sdf_world(position_of_hit + tiny_change_x).distance_to_2object);
  let down_tiny_change_in_x: f32 = my_min(sdf_world(position_of_hit - tiny_change_x).distance_to_1object,
					  sdf_world(position_of_hit - tiny_change_x).distance_to_2object);
  let tiny_change_in_x: f32 = up_tiny_change_in_x - down_tiny_change_in_x;

  let up_tiny_change_in_y: f32 = my_min(sdf_world(position_of_hit + tiny_change_y).distance_to_1object,
					sdf_world(position_of_hit + tiny_change_y).distance_to_2object);
  let down_tiny_change_in_y: f32 = my_min(sdf_world(position_of_hit - tiny_change_y).distance_to_1object,
					  sdf_world(position_of_hit - tiny_change_y).distance_to_2object);
  let tiny_change_in_y: f32 = up_tiny_change_in_y - down_tiny_change_in_y;

  let up_tiny_change_in_z: f32 = my_min(sdf_world(position_of_hit + tiny_change_z).distance_to_1object,
					       sdf_world(position_of_hit + tiny_change_z).distance_to_2object);
  let down_tiny_change_in_z: f32 = my_min(sdf_world(position_of_hit - tiny_change_z).distance_to_1object,
					  sdf_world(position_of_hit - tiny_change_z).distance_to_2object);
  let tiny_change_in_z: f32 = up_tiny_change_in_z - down_tiny_change_in_z;


  let normal_dir = vec3(tiny_change_in_x,
			tiny_change_in_y,
			tiny_change_in_z);

  return normalize(normal_dir);
}

//                 ,--. ,---.
// ,--.,--.,--,--, `--'/  .-' ,---. ,--.--.,--,--,--. ,---.
// |  ||  ||      \,--.|  `-,| .-. ||  .--'|        |(  .-'
// '  ''  '|  ||  ||  ||  .-'' '-' '|  |   |  |  |  |.-'  `)
//  `----' `--''--'`--'`--'   `---' `--'   `--`--`--'`----'
// uniforms
struct RaymarchObjectDescriptor {
 world_position: vec3<f32>,
 rotation: vec3<f32>,
 move_amount: f32,
 rotation_amount: f32,
 shape_type_id: u32,
 shape_1var: f32,
 shape_2var: f32,
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
 termination_distance: f32,
 time: f32,
}



//                     ,--.                ,--.        ,--.
// ,--,--,--. ,--,--.,-'  '-. ,---. ,--.--.`--' ,--,--.|  | ,---.
// |        |' ,-.  |'-.  .-'| .-. :|  .--',--.' ,-.  ||  |(  .-'
// |  |  |  |\ '-'  |  |  |  \   --.|  |   |  |\ '-'  ||  |.-'  `)
// `--`--`--' `--`--'  `--'   `----'`--'   `--' `--`--'`--'`----'
// materials

// used for getting the material transition between 2 objects
// lerp_val is 0.0-1.0, where 0 is just at desc1, and 1 is just at desc2.
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
