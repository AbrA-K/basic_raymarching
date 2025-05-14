#import bevy_pbr::{
    mesh_view_bindings::view,
    forward_io::VertexOutput,
    forward_io::FragmentOutput,
    utils::coords_to_viewport_uv,
    pbr_functions::{apply_pbr_lighting, main_pass_post_lighting_processing},
    pbr_types::pbr_input_new,
    pbr_functions::alpha_discard,
    pbr_fragment::pbr_input_from_standard_material,
}

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
	  pbr_input.material.base_color = alpha_discard(pbr_input.material, pbr_input.material.base_color);
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
  // my world consists of one sphere at (0.0, 0.5, 0.5) with id 0
  // TODO: make this something passed from the cpu
  let radius = 0.5;
  let distance_to_surface = sdf_circle(ray_position, vec3<f32>(0.0, 0.5, 0.5), radius);
  return SdfOutput(distance_to_surface, 0);
}

fn sdf_circle(ray_position: vec3<f32>, circ_pos: vec3<f32>, rad: f32) -> f32 {
  return distance(ray_position, circ_pos) - rad;
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
