#import bevy_pbr::{
    mesh_view_bindings::view,
    forward_io::VertexOutput,
    utils::coords_to_viewport_uv,
}

// TODO: pass from cpu
const point = vec3<f32>(0.0, 0.5, 0.5);

const MARCH_MIN_DIST = 0.01;
const MARCH_MAX_DIST = 10.0;

@fragment
fn fragment(
    mesh: VertexOutput,
) -> @location(0) vec4<f32> {
  var color = vec3<f32>(1.0, 1.0, 1.0);
  let cam_pos = view.world_position;
  var viewport_uv = coords_to_viewport_uv(mesh.position.xy, view.viewport) * 2.0 - 1.0;
  viewport_uv.y *= -1;
  let clip = vec4<f32>(viewport_uv, 1.0, 1.0);
  var world = view.world_from_clip * clip;
  world /= world.w;
  let ray_dir = normalize(world.xyz - cam_pos);

  var curr_pos = cam_pos;
  var dist_marched = 0.0;
  let radius = 0.2;
  var min_step_length = 1000.0; // TODO: change to +inf
  while dist_marched < MARCH_MAX_DIST {
     if sdf_circle(curr_pos, point, radius) < MARCH_MIN_DIST {
	 // HIT!
	 return vec4<f32>(calc_color_circle(point, curr_pos), 1.0);
       }

     let step = ray_dir * sdf_circle(curr_pos, point, radius);
     let step_length = length(step);
     if step_length < min_step_length {
	 min_step_length = step_length;
       }
     dist_marched += step_length;
     curr_pos += step;
   }

  let glow = clamp((-min_step_length + 1.0), 0.0, 1.0);
  return vec4<f32>(color, glow);
}

fn sdf_circle(point: vec3<f32>, circ_pos: vec3<f32>, rad: f32) -> f32 {
  return distance(point, circ_pos) - rad;
}

fn calc_color_circle(circle_pos: vec3<f32>, hit_pos: vec3<f32>) -> vec3<f32> {
  return normalize(hit_pos - circle_pos);
}
