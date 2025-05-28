# Description
This is a small raymarching sandbox for you to play around in.
It has a couple of demos to show some basic features. If you want to explore more, you can change to the full ui, which will crowd the screen a lot (hence the default minimal ui). To give you some interesting knobs to turn, I recommend playing around with:
- Global Settings:
  - Termination distance
  - glow color (careful - it's default 100% transparent)
  - smooth intersection
  - intersection method
- Object Settings
  - rotation over time
  - translation over time

# Building
you should just be able to `cargo run` this, but you need bevys dependencies:
https://github.com/bevyengine/bevy/blob/latest/docs/linux_dependencies.md

once I'm done you should also be able to run this from my website
