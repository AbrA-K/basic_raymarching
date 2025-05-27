#import bevy_pbr::{
  prepass_io::VertexOutput,
  mesh_view_bindings::view,
}

#import "shaders/basic_raymarch.wgsl"::perform_march
#import "shaders/basic_raymarch.wgsl"::MarchOutput

@fragment
fn fragment(
	    @builtin(sample_index) sample_index: u32,
	    mesh: VertexOutput,
	    ) -> @builtin(frag_depth) f32 {
  let march = perform_march(mesh.position.xy, sample_index);
  if march.has_hit {
      let clip_curr_pos = view.clip_from_world * vec4<f32>(march.hit_pos, 1.0);
      let ndc_curr_pos = clip_curr_pos.xyz / clip_curr_pos.w;
      let curr_pos_depth = ndc_curr_pos.z;
      return curr_pos_depth;
    }
  return 0.0;
}
