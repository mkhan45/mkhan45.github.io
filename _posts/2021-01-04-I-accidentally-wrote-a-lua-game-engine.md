Lately I’ve been working on SIMple Physics, a set of educational physics simulators meant to help teach and learn physics intuitively without expensive lab equipment or in person classes. Each simulator allows users to import and export scenes and potentially add some more advanced functionality through Lua. 

Until recently, the Lua scripting was fairly limited. It could be used to add/remove objects and change variables such as but crucially it could not affect objects once they were created.gravity, and there was also an update() function which ran every frame.

```lua
-- this example instantiates a multicolored grid of circles
for row = 1,HEIGHT do
    for col = 1,WIDTH do
        color = {
            r = (row * col) / (WIDTH * HEIGHT) * 255,
            g = col / WIDTH * 255,
            b = row / HEIGHT * 255
        }
        add_shape{
            shape = "circle", 
            x = col * OFFSET + START_X_OFFSET, 
            y = row * OFFSET, 
            r = RAD, 
            mass = 1, 
            color = color
        }
    end
end
```

Crucially, there was no way to affect individual objects directly once they had been instantiated. By now, you can probably see where this is going.

I’ve been in contact with my physics professor about this project, and he told me that he would like for students to be able to code the equations we learn in class. For example, basic position integration through Euler’s method or the collision equations. With that, I decided to implement a way for the Lua interface to be able to update individual objects. 

What I arrived at is object specific update functions. By specifying a function to be called on an object every frame, users can now modify the features of an object including position, velocity, color, etc. Here’s the MVP for an integration lab which lets students write their own integration method:

```lua
-- the student should edit this function
local function integrate(x, y, v_x, v_y, dt)
    return {
        new_x = x + v_x * dt,
        new_y = y + v_y * dt,
    }
end

X_VEL = 1
Y_VEL = -1

-- this function is called on the circle every frame
function update_fn(obj)
    local old_x, old_y = obj.x, obj.y
    data = integrate(old_x, old_y, X_VEL, Y_VEL, DT / 100)
    obj.x, obj.y = data.new_x, data.new_y
    return obj
end

add_shape {
    shape="circle",
    x=SCREEN_X/2,
    y=SCREEN_Y/2,
    r=1,
    mass=1,
    update_function="update_fn"
}

GRAVITY = 0
```

The idea is that students would write their own `integrate()` function. Ideally, there should be another circle which uses the simulator’s physics engine, and by comparing the behavior of the two shapes it will be possible to see the error in Euler integration.

As I wrote the examples, I realized that the object specific update functions are pretty similar to the way Unity’s ECS works. The update functions are essentially a script component. While it’s only possible to add one update function to each object, that’s a pretty easy limitation to get around.

Upon this realization, I decided to write Flappy Bird. Here’s where I admit that the title is a bit clickbaity: there’s still no way to handle user input from the Lua scripts, so the program still can’t really be called a game engine. Users can drag around objects with their mouse, so it would be possible to set up physical buttons in the scene, and there are also global `MOUSE_X` and `MOUSE_Y` Lua variables, but the Lua can’t see keyboard or mouse clicks. Because of this, I wrote a super simple AI to play Flappy Bird.

My Lua code is a bit amateurish and too long for a code snippet, so I’d encourage you to [check it out on GitHub](https://github.com/mkhan45/SIMple-Mechanics/blob/master/lua/flappy_bird.lua) if you want to read it.

Building Flappy Bird on top of a physics engine like this is pretty interesting. I didn’t bother to write an end game condition, but if the bird crashes into one of the pipes they both go flying off. Instead of manually updating the x-position of the pipes, I just initialized their velocity to be negative. I assume this is similar to how it would work in Unity or Godot. However, while it’s definitely possible to write games using the engine, it’s not terribly ergonomic. I’m okay with that though. 

Something else I was surprised at was the speed of interfacing with Lua from Rust. Every frame, the program is pulling numerous fields of the Lua objects into the physics engine and passing them back to Lua. In the Flappy Bird example, the physics engine is nearly inactive, so I’d expected the Lua system to be more intensive than the physics engine, but it uses about a tenth of the performance if I’m reading my profiler correctly. I’m tempted to rewrite the Universal Gravitation portion of SIMple Physics into a Lua script.
