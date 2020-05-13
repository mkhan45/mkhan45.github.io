# Gravity Sim Overview

This is a more in depth overview of how my gravity simulator works. You should read [my previous post](https://mkhan45.github.io/blog/gravity-sim) if you haven't.

## Architecture

I'm using Rust and a game engine called ggez. The main method is pretty short.

_____
```rust
pub fn main() -> GameResult{
    let (ctx, event_loop) = &mut ggez::ContextBuilder::new("N-body gravity sim", "Fish")
        .window_setup(ggez::conf::WindowSetup::default().title("N-body gravity sim"))
        .window_mode(ggez::conf::WindowMode::default().dimensions(1000.0, 800.0))
        .build().expect("error building context");
    let state = &mut MainState::new().clone();

    event::run(ctx, event_loop, state)
}
```
All this does is initialize a ggez window that uses MainState, a struct that controls the whole game.

_____

```rust
struct MainState {
        bodies: Vec<Body>,
        start_point: Point2,
        zoom: f32,
        offset: Point2,
        density: f32,
        radius: f32,
        mouse_pos: Point2,
        trail_length: usize,
        mouse_pressed: bool,
        paused: bool,
        predict_body: Body,
        predict_speed: usize,
        integrator: Integrator,
        help_menu: bool,
        fast_forward: usize,
        step_size: f32,
}
```

There's a lot of stuff stored inside of MainState, but most important is `bodies`. This is where every planet/star is stored. This is the declaration for the `Body` struct:

```rust
pub struct Body {
        pub pos: Point2,
        pub mass: f32,
        pub radius: f32,
        pub velocity: Vector2,
        pub trail: VecDeque<Point2>,
        pub trail_length: usize,
        pub past_accel: Vector2,
        pub current_accel: Vector2,
}
```

To run the actual simulation, ggez runs a method, `update`, every frame. Here's the most important part of it:

```rust
if !self.paused{ //physics sim
    (0..self.fast_forward).for_each(|_i|{
            self.bodies = update_velocities_and_collide(&self.bodies, &self.integrator, &self.step_size);
            ...
            })
}
```

Basically, it calls the actual physics sim method `fast_forward` times. `fast_forward` is a simple multiplier on simulation time so that when the step size is decreased to increase precision I can keep things from getting stagnant.

_____

The actual math and physics is in `update_velocities_and_collide`. For simplicity, I removed everything unrelated to the actual gravity.

```rust
pub fn update_velocities_and_collide(bodies: &Vec<Body>, method: &Integrator, step_size: &f32) -> Vec<Body>{
    let mut bodies = bodies.clone();

    ...

        for current_body_i in 0..bodies.len(){
            bodies[current_body_i].current_accel = Vector2::new(0.0, 0.0);

            for other_body_i in 0..bodies.len(){
                if other_body_i != current_body_i {
                    let other_body = &bodies[other_body_i].clone();
                    let current_body = &mut bodies[current_body_i];

                    let r = distance(&other_body.pos, &current_body.pos);
                    let a_mag = (G*other_body.mass)/(r.powi(2)); //acceleration = Gm_2/r^2
                    let angle = angle(&other_body.pos, &current_body.pos);

                    //if two bodies collide, add them to remove list and create new body that's a combination of both
                    if r <= other_body.radius + current_body.radius && !collision_blacklist.contains(&current_body_i){
                        collision_blacklist.insert(current_body_i);
                        collision_blacklist.insert(other_body_i);
                        collision_bodies.push(collide(&current_body, &other_body));
                    }

                    current_body.current_accel += Vector2::new(angle.cos() * a_mag, angle.sin() * a_mag);
                }
            }

            match method {
                &Integrator::Euler => bodies[current_body_i].update_euler(step_size),
                    &Integrator::Verlet => bodies[current_body_i].update_verlet(step_size),
            };
        }

    return bodies;
}
```

What this method does is loop through the `Vec<Body>` and calculate the acceleration of each individual body. It's O(n^2), but I don't think there's a way around that. This is one of the first bits of code I wrote for this, and looking at it now I think I would've used `fold()` to make it a bit neater. Maybe I'll change it eventually.


At the bottom, you can see a match statement for the integration method. `update_velocities_and_collide` calculates the accelerations, but it doesn't apply them. I partially explained the difference between Euler integration and Verlet integration in my previous post.

```rust
pub fn update_euler(&mut self, step_size: &f32){
    microprofile::scope!("Update", "Bodies");

    self.pos += Vector2::new(self.velocity.x * step_size, self.velocity.y * step_size);
    self.velocity += self.current_accel * step_size.powi(2);
}

pub fn update_verlet(&mut self, step_size: &f32){ //verlet velocity
    microprofile::scope!("Update", "Bodies");

    self.velocity += ((self.current_accel + self.past_accel)/2.0) * *step_size;
    self.pos += self.velocity * *step_size + (self.current_accel/2.0) * (*step_size).powi(2);
    self.past_accel = self.current_accel;
}
```
______

Ggez also calls `draw()` every frame. `draw()` is the longest method but only because of all the conditionals. The important part is here:

```rust
let params = graphics::DrawParam::new()
                .dest(self.offset)
                .scale(Vector2::new(self.zoom, self.zoom));


            for i in 0..self.bodies.len(){ //draw bodies
                let body = graphics::Mesh::new_circle( //draw body
                    ctx,
                    graphics::DrawMode::fill(),
                    self.bodies[i].pos,
                    self.bodies[i].radius,
                    2.0,
                    graphics::Color::new(1.0, 1.0, 1.0, 1.0))
                    .expect("error building body mesh");

                graphics::draw(ctx, &body, params).expect("error drawing body");
}
```

First, I create the DrawParams that tell ggez how to draw the object. At first I was implementing camera movement by manually editing the position of each body in this method, but then I read the ggez documentation and that made it a lot easier. 

I also learned about error management in Rust from this method. Instead of catching and throwing errors, methods that  have the potential to error must return an `Option` that might be an `Err`. If I want to ignore an error, I can `match` (Rust switch statements) it to empty braces. If I want to close the program with an error message, I use `expect()`. If I want to tell Rust that I know that there's definitely no error, I can use `unwrap()`. You can see a lot more error management with how I drew trails if you look at the code [here](https://github.com/mkhan45/gravity-sim/blob/master/src/main.rs#L149). 

_____

The rest is just processing input. Ggez gives methods like `key_down_event` and `mouse_motion_event`, and the rest is pretty simple. I might change how camera movement works because while `key_down_event` is automatically debounced, there's also `ggez::input::keyboard::pressed_keys()` which returns a set of all the keys pressed during a frame, which I can use to make the movement smoother. I'd also like to add a GUI but there aren't many good options for Rust GUIs yet, so I think I'll implement a simple one myself.
