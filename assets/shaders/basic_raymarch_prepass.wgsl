#import bevy_pbr::{
  mesh_view_bindings::globals,
  prepass_utils,
  prepass_io::VertexOutput,
  forward_io::FragmentOutput,
}

@fragment
fn fragment(
	    @builtin(sample_index) sample_index: u32,
	    in: VertexOutput,
	    ) -> @builtin(frag_depth) f32 {
// #ifdef UNCLIPPED_DEPTH_ORTHO_EMULATION
  // in.unclipped_depth = 1000.0;
// #endif // UNCLIPPED_DEPTH_ORTHO_EMULATION
  // var out: FragmentOutput;
  // out.color = vec4<f32>(0.0, 0.0, 1.0, 1.0);
  // return out;
  return 0.0;
}
