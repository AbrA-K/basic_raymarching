#import bevy_pbr::{
mesh_view_bindings::globals,
  // forward_io::VertexOutput,
  prepass_utils,
  bevy_pbr::prepass_io,
  prepass_io::VertexOutput,
  prepass_io::FragmentOutput,
}

@fragment
fn fragment(
	    @builtin(sample_index) sample_index: u32,
	    in: VertexOutput,
	    ) -> @location(0) vec3<f32> {
  let color = vec4<f32>(0.0);
  return color;
}
