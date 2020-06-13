I'm writing an [educational physics thing](https://github.com/mkhan45/physics-v2) which is basically just a physics sandbox that can theoretically be used for labs and demonstrations in physics classes. I've tried to write it before with my own physics engine, but [it didn't turn out very well](https://github.com/mkhan45/physics-engine) because I couldn't get my collision solver right. Now I'm writing it with [nphysics](https://nphysics.org/).

I've also written [a universal gravitation simulator](https://github.com/mkhan45/gravity-sim-v2) with the same idea, and since a universal gravitation sim on its own is pretty easy to write, 95% of the work went into getting the UI/UX right. I think the final product is pretty good, the biggest problem was the lack of preset scenarios and the difficulty in creating them. The presets were each meant to demonstrate one cool effect of gravity or just interesting scenarios in general, like a dual star system. I made them by hand in the simulator and then used the export button which exports all the planets to a .toml markup file. While it's technically human readable and editable, it's really not ideal considering how much extra info was serialized. If I'd written the serializer manually I probably could've gotten better results, but I really didn't want to. 

For some scenarios such as the grid, I just edited the starting planets in the main method and recompiled and then exported it to toml, and it worked, but compiling Rust is pretty slow and it produced [a pretty uneditable result](https://github.com/mkhan45/gravity-sim-v2/blob/master/saved_systems/grid.ron). Every time I wanted to edit the grid I had to just rewrite the code, because for whatever reason I never decided to save it.

___

&nbsp;

For this new physics sandbox, I wanted something better. I've not really started any UI stuff yet, but I wanted an easier way to add and remove objects for testing. I've also been interested in using scripting languages like [Mun](https://mun-lang.org/) for some parts of game development. This seemed like the perfect opportunity. I'd like to use Mun for it, but it seems like it's not ready, and with what little experience with Lua I have, I like it.

___

&nbsp;

Using [rlua](https://github.com/amethyst/rlua), adding Lua integration to my project was super easy. Given my lack of experience with Lua I ran into some problems with the exact implementation details, but I figured it out pretty quickly. 

Right now you can only load objects from Lua on startup, and the Lua instance starts and ends in the `add_shapes_from_lua` function. I want to make it run alongside the whole program eventually.

Here's what `add_shapes_from_lua` does:
1. Initialize the Lua instance
2. Add some globals, including pi, the screen size, and, most importantly, the vector (table) `shapes`.
3. Run some Lua code which makes the Lua functions `add_shape` and `add_shapes`. Realistically these are kind of unnecessary but I wanted it to be as accessible as possible for people who have no coding experience, and with these two functions your Lua code can practically be a markup file.
4. Read and execute the user Lua code
5. Take the Lua table `shapes` into Rust and turn all of the internal Lua shapes into proper nphysics objects.

___

&nbsp;

Before, I had a default scenario with a floor, a static floating block, and some extra shapes. The Rust code for it was fairly verbose, and anytime I wanted to change things I had to recompile. Now, the starting shapes are made from this Lua:

```lua
add_shapes(
   -- floor
   {shape = "rect", x = 0, y = SCREEN_Y, status = "static", w = SCREEN_X * 5.0, h = 0.25, elasticity = 0.1},

   {shape = "rect", x = 10.0, y = 16.0, w = 0.5, h = 1.25, mass = 5.0},
   {shape = "rect", x = 8.0, y = 0.0, w = 2.0, h = 1.0, mass = 8.0, rotation = PI / 3.0},
   {shape = "circle", x = 19.25, y = 1.0, r = 2.0, mass = 12.5, elasticity = 0.5},

   -- static floating square
   {shape = "rect", x = SCREEN_X / 3.0, y = SCREEN_Y / 2.0, status = "static", w = 0.1, h = 0.1}
)
```

It's practically markup, and I think physics students and teachers should be able to figure it out pretty quickly.

Of course, Lua also lets you do some fancier stuff. Here's a grid:
```lua
for i = 1, 13 do
   for j = 1, 20 do
      add_shape({
         shape = "rect", 
         x = i * ((SCREEN_X * 0.9) / 10), 
         y = j * ((SCREEN_Y * 0.9) / 20), 
         w = 0.5, 
         h = 0.5, 
         r = 0.5,
         elasticity = 0.05, 
         friction = 1.0
      })
   end
end
```

Given how well this turned out, I'm trying to figure out a way I could use Lua for the GUI or other stuff that needs quick iteration.

My biggest problem so far is that Lua is one indexed.
