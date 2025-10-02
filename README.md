# Description
![thumbnail](https://github.com/user-attachments/assets/069ba635-70a9-4689-9ff7-40fc726407ea)

This is a small raymarching sandbox for you to play around in.
It has a couple of demos to show some basic features. If you want to explore more, you can change to the full ui, which will crowd the screen a lot (hence the default minimal ui). To give you some interesting knobs to turn, I recommend playing around with:
- Global Settings:
  - Termination distance
  - glow_color (careful - it's default 100% transparent)
  - glow_range
  - smooth intersection
  - intersection method
- Object Settings
  - rotation over time
  - translation over time


# Building
you should just be able to `cargo run` this, but you need bevys dependencies:
https://github.com/bevyengine/bevy/blob/latest/docs/linux_dependencies.md

Or you can run it from my Website:
https://abra-k.xyz/static/games/basic_raymarching/index.html
