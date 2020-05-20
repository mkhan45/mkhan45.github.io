This is a continuation of [Pong tutorial with ggez](https://mkhan45.github.io/2020/05/19/Pong-tutorial-with-ggez.html).

At the end part 1, we had the skeleton of a ggez game:

```rust
use ggez::{
    event::EventHandler,
};

struct MainState {
}

impl EventHandler for MainState {
    fn update(&mut self, _: &mut ggez::Context) -> ggez::GameResult {
        Ok(())
    }

    fn draw(&mut self, _: &mut ggez::Context) -> ggez::GameResult {
        Ok(())
    }
}

fn main() -> ggez::GameResult {
    // create a mutable reference to a `Context` and `EventsLoop`
    let (ctx, event_loop) = &mut ggez::ContextBuilder::new("Pong", "Fish").build().unwrap();

    // Make a mutable reference to `MainState`
    let main_state = &mut MainState {};

    // Start the game
    ggez::event::run(ctx, event_loop, main_state)
}
```

In this part, we'll set up our structs and the draw loop.

___

## Struct setup

Pong essentially consists of just a few pieces. There's two paddles and a ball. There's also two score counters. We want to store all the data Pong needs in our `MainState`. To make our `MainState` struct, we need to figure out what type each field should be. 

Paddles are pretty simple. They're really just rectangles. They don't even need to have a stored velocity because they only move when there's input. A `Paddle` struct could look like this:

```rust
Paddle {
   // in ggez, positions are stored as floats
   x: f32, // top left x coordinate
   y: f32, // top left y coordinate 
   width: f32,
   height: f32,
}
```

But luckily, we don't have to make our own `Paddle` struct because [ggez conveniently comes with a nice `Rect` struct](https://docs.rs/ggez/0.5.1/ggez/graphics/struct.Rect.html).

ggez's `Rect` comes with some nice methods like `.overlaps()`.

If we store each paddle in our game as a ggez `Rect`, our `MainState` so far looks like this:

```rust
MainState {
   l_paddle: ggez::graphics::Rect,
   r_paddle: ggez::graphics::Rect,
}
```

It's easier not to keep writing out `ggez::graphics::Rect`, so add a `use ggez::graphics::Rect` at the start of the file and then you can replace `ggez::graphics::Rect` with just `Rect`.

The ball in Pong is also really just a Rect, but it also has velocity. Because of that, it's best to make a new struct for it.

```rust
Ball {
   rect: Rect,
   x_vel: f32,
   y_vel: f32,
}
```

Instead of storing `x_vel` and `y_vel` separately as `f32`s, we could use ggez's `Vector` type. ggez actually uses a specific math library which contains its `Vector` type called `mint`, so the full name is `ggez::mint::Vector2<T>`. The `<T>` denotes that `Vector2` is a generic type. Since all the graphics stuff in ggez is done with `f32`s, we want to use `Vector2<f32>`s. To make things easier, add this somewhere near the start of your file:
```rust
type Vector = ggez::mint::Vector2<f32>;
```

Now, our `Ball` struct can be this:
```rust
Ball {
   rect: Rect,
   vel: Vector,
}
```

Now that we have our `Ball` struct, we can add it to our `MainState` struct:
```rust
MainState {
   l_paddle: Rect,
   r_paddle: Rect,
   ball: Ball,
}
```

Now, the only thing `MainState` needs is a way to store the scores, and for that we can use `u8`s. `u8`s will overflow if the score goes above 255 though, so maybe we should use `u16` just to be safe.

```rust
MainState {
   l_paddle: Rect,
   r_paddle: Rect,
   ball: Ball,
   l_score: u16,
   r_score: u16,
}
```
___

You might've noticed that as soon as we started adding new fields to `MainState` the program stopped compiling properly. That's because of this line in our `main()` method: 
```rust
let main_state = &mut MainState {};
```

We have to set every field of our `MainState` struct to declare a new one.
```rust
 let main_state = &mut MainState {
     l_paddle: Rect::new(20.0, 300.0, 20.0, 50.0),
     r_paddle: Rect::new(280.0, 300.0, 20.0, 50.0),
     ball: Ball { rect: Rect::new(300.0, 300.0, 20.0, 20.0), vel: Vector {x: 0.0, y: 0.0} },
     l_score: 0,
     r_score: 0,
 };
```

This declaration is kind of awkward. I arbitrarily chose all the coordinates and sizes, and we'll probably want to change everything later. To make that easier, let's set up some consts at the start of the file. We also want to choose a screen size to work with.

Here's what I end up with:

```rust
const SCREEN_HEIGHT: f32 = 600.;
const SCREEN_WIDTH: f32 = 600.;

const X_OFFSET: f32 = 20.; // distance from each paddle to their respective walls
const PADDLE_WIDTH: f32 = 12.;
const PADDLE_HEIGHT: f32 = 75.;

const BALL_RADIUS: f32 = 10.;
```

Now, we can declare `main_state` like this:

```rust
 let main_state = &mut MainState {
     l_paddle: Rect::new(X_OFFSET, SCREEN_HEIGHT / 2.0 - PADDLE_HEIGHT / 2.0, PADDLE_WIDTH, PADDLE_HEIGHT),
     r_paddle: Rect::new(SCREEN_WIDTH - X_OFFSET, SCREEN_HEIGHT / 2.0 - PADDLE_HEIGHT / 2.0, PADDLE_WIDTH, PADDLE_HEIGHT),
     ball: Ball { rect: 
         Rect::new(SCREEN_WIDTH / 2.0 - BALL_RADIUS / 2.0, SCREEN_HEIGHT / 2.0 - BALL_RADIUS / 2.0, BALL_RADIUS, BALL_RADIUS), 
         vel: Vector {x: 0.0, y: 0.0} },
     l_score: 0,
     r_score: 0,
 };
```

Adding consts makes the lines a lot longer. I've self formatted a bit, but luckily we can use `cargo fmt` to automatically format. This will also adjust anything else in the file that doesn't meet the official Rust formatting guidelines.

```rust
 let main_state = &mut MainState {
     l_paddle: Rect::new(
         X_OFFSET,
         SCREEN_HEIGHT / 2.0 - PADDLE_HEIGHT / 2.0,
         PADDLE_WIDTH,
         PADDLE_HEIGHT,
     ),
     r_paddle: Rect::new(
         SCREEN_WIDTH - X_OFFSET,
         SCREEN_HEIGHT / 2.0 - PADDLE_HEIGHT / 2.0,
         PADDLE_WIDTH,
         PADDLE_HEIGHT,
     ),
     ball: Ball {
         rect: Rect::new(
             SCREEN_WIDTH / 2.0 - BALL_RADIUS / 2.0,
             SCREEN_HEIGHT / 2.0 - BALL_RADIUS / 2.0,
             BALL_RADIUS,
             BALL_RADIUS,
         ),
         vel: Vector { x: 0.0, y: 0.0 },
     },
     l_score: 0,
     r_score: 0,
 };
```
___

## Drawing

So we've set up all our structs and written like 50 lines but the behavior of our program hasn't changed a single bit. Now that our `MainState` actually has stuff in it though, we can draw it. This is, of course, done in the `draw()` method of our `MainState`.

Before, the signature of `draw()` was:
```rust
fn draw(&mut self, _: &mut ggez::Context) -> ggez::GameResult
```

We didn't use the field of type `&mut ggez::Context` before, so we just left it unnamed with an underscore. Now, we're going to use it so we should rename it to `ctx`.
```rust
fn draw(&mut self, ctx: &mut ggez::Context) -> ggez::GameResult
```

Do the same thing with your `update()` method.

Drawing in ggez is pretty straightforward for Pong. We just have to draw each paddle and the ball. We also have to clear the screen in between frames. With more advanced games ggez has more efficient ways to draw things, but for Pong we can just draw each shape individually.

To clear the screen, we just use `ggez::graphics::clear`. From the [ggez documentation](https://docs.rs/ggez/0.5.1/ggez/graphics/fn.clear.html), we can see its full signature: 
```rust
pub fn clear(ctx: &mut Context, color: Color)
```

From this, we know that it takes a mutable reference to a `Context`, which we have, and a `Color`, which we don't. If you click on `Color` in the ggez web documentation, it will take you [to the `Color` documentation](https://docs.rs/ggez/0.5.1/ggez/graphics/struct.Color.html). From the `Color` documentation, we see that we can initialize `Color`s with `ggez::graphics::Color::new(r, g, b, a)`. Knowing that, here's our new `draw()` method:
```rust
    fn draw(&mut self, ctx: &mut ggez::Context) -> ggez::GameResult {
        ggez::graphics::clear(ctx, ggez::graphics::Color::new(0.0, 0.0, 0.0, 1.0));
        Ok(())
    }
```

`ggez::graphics::Color` is really long to write out, but we won't use it anywhere other than in `draw()` so we can do a scoped `use ggez::graphics::Color` at the start of it. We should also just `use ggez::graphics` because there's a lot more stuff from it we'll use in `draw()`.
```rust
 fn draw(&mut self, ctx: &mut ggez::Context) -> ggez::GameResult {
     use ggez::graphics::Color;
     use ggez::graphics;

     graphics::clear(ctx, Color::new(0.0, 0.0, 0.0, 1.0));
     Ok(())
 }
```

After `clear`ing the screen, we need to actually `present()` it to see the changes. This is done with `ggez::graphics::present()`. All drawing code needs to be done between `clear()` and `present()`.

```rust
 fn draw(&mut self, ctx: &mut ggez::Context) -> ggez::GameResult {
     use ggez::graphics::Color;
     use ggez::graphics;

     graphics::clear(ctx, Color::new(0.0, 0.0, 0.0, 1.0)); // Color::new(0.0, 0.0, 0.0, 1.0) is black
     // all drawing stuff goes here
     graphics::present(ctx);
     Ok(())
 }
```

On compiling and running this, we get a black window. We also get a familiar compiler warning:
```
warning: unused `std::result::Result` that must be used
  --> src/main.rs:38:9
   |
38 |         graphics::present(ctx);
   |         ^^^^^^^^^^^^^^^^^^^^^^^
   |
   = note: `#[warn(unused_must_use)]` on by default
   = note: this `Result` may be an `Err` variant, which should be handled
```

`ggez::graphics::present` returns a `Result`, more specifically, a `GameResult`. Rust wants us to handle this if it's an error, but the game can't really continue if the graphics don't work. Because of that, we can just `unwrap()` the `Result`, or `.expect()` it if we want a more specific error message (IMO it's best to always use expects instead of unwraps but it gets tedious). This is a common theme with game programming in Rust because a lot of game errors just aren't recoverable.

Our new `draw()` method looks like this:
```rust
 fn draw(&mut self, ctx: &mut ggez::Context) -> ggez::GameResult {
     use ggez::graphics::Color;
     use ggez::graphics;

     graphics::clear(ctx, Color::new(0.0, 0.0, 0.0, 1.0)); // Color::new(0.0, 0.0, 0.0, 1.0) is black
     // all drawing stuff goes here
     graphics::present(ctx).expect("error presenting");
     Ok(())
 }
```

There's a few steps to actually draw the paddles and the ball. First, we have to make graphics meshes, using [ggez's `ggez::graphics::Mesh`](https://docs.rs/ggez/0.5.1/ggez/graphics/struct.Mesh.html). `ggez::graphics::Mesh` has a [`new_rectangle()` method](https://docs.rs/ggez/0.5.1/ggez/graphics/struct.Mesh.html#method.new_rectangle) with this signature:
```rust
pub fn new_rectangle(
    ctx: &mut Context,
    mode: DrawMode,
    bounds: Rect,
    color: Color
) -> GameResult<Mesh>
```

We already have `ctx` and `bounds`, and we know how to get `color`, but `DrawMode` is new. From clicking on `DrawMode` in the documentation, we find that `ggez::graphics::DrawMode` has a `fill()` method, which specifies that ggez will fill the shape as opposed to just drawing its outline. We also now know that `new_rectangle()` returns a `GameResult`, but it's still unrecoverable so we should `expect()` it.

Knowing this, to make a mesh for our ball, we can use this line:
```rust
let ball_mesh = graphics::Mesh::new_rectangle(ctx, graphics::DrawMode::fill(), self.ball.rect, Color::new(1.0, 1.0, 1.0, 1.0))
   .expect("error creating ball mesh");
```

To draw it, we use [`ggez::graphics::draw()`](https://docs.rs/ggez/0.5.1/ggez/graphics/fn.draw.html), which takes a reference to a `Drawable` and `DrawParams`. Our `ball_mesh` is `Drawable`, so we just need to figure out what to use for `DrawParams`. From the (`DrawParam` documentation)[https://docs.rs/ggez/0.5.1/ggez/graphics/struct.DrawParam.html] we can see that it has a `default()` implementation, so let's just use that. Again, `draw()` returns a result which we should `.expect()`

```rust
graphics::draw(ctx, &ball_mesh, graphics::DrawParam::default()).expect("error drawing ball mesh");
```

Our draw method (after running `cargo fmt`) now looks like this:
```rust
 fn draw(&mut self, ctx: &mut ggez::Context) -> ggez::GameResult {
     use ggez::graphics;
     use ggez::graphics::Color;

     graphics::clear(ctx, Color::new(0.0, 0.0, 0.0, 1.0)); // Color::new(0.0, 0.0, 0.0, 1.0) is black

     let ball_mesh = graphics::Mesh::new_rectangle(
         ctx,
         graphics::DrawMode::fill(),
         self.ball.rect,
         Color::new(1.0, 1.0, 1.0, 1.0),
     )
     .expect("error creating ball mesh");
     graphics::draw(ctx, &ball_mesh, graphics::DrawParam::default())
         .expect("error drawing ball mesh");

     graphics::present(ctx).expect("error presenting");
     Ok(())
 }
```

If we compile and run our program, we get a white rectangle roughly in the middle of the screen. It's not quite centered because we haven't actually set our screen width and height properly, but we'll do that later.

Repeat the steps for drawing the ball on the l_paddle and r_paddle and we get our final `draw()` method for now:
```rust
    fn draw(&mut self, ctx: &mut ggez::Context) -> ggez::GameResult {
        use ggez::graphics;
        use ggez::graphics::Color;

        graphics::clear(ctx, Color::new(0.0, 0.0, 0.0, 1.0)); // Color::new(0.0, 0.0, 0.0, 1.0) is black

        let ball_mesh = graphics::Mesh::new_rectangle(
            ctx,
            graphics::DrawMode::fill(),
            self.ball.rect,
            Color::new(1.0, 1.0, 1.0, 1.0),
        )
        .expect("error creating ball mesh");
        graphics::draw(ctx, &ball_mesh, graphics::DrawParam::default())
            .expect("error drawing ball mesh");

        let l_paddle_mesh = graphics::Mesh::new_rectangle(
            ctx,
            graphics::DrawMode::fill(),
            self.l_paddle,
            Color::new(1.0, 1.0, 1.0, 1.0),
        )
        .expect("error creating ball mesh");
        graphics::draw(ctx, &l_paddle_mesh, graphics::DrawParam::default())
            .expect("error drawing ball mesh");

        let r_paddle_mesh = graphics::Mesh::new_rectangle(
            ctx,
            graphics::DrawMode::fill(),
            self.r_paddle,
            Color::new(1.0, 1.0, 1.0, 1.0),
        )
        .expect("error creating ball mesh");
        graphics::draw(ctx, &r_paddle_mesh, graphics::DrawParam::default())
            .expect("error drawing ball mesh");

        graphics::draw(ctx, &ball_mesh, graphics::DrawParam::default())
            .expect("error drawing ball mesh");

        graphics::present(ctx).expect("error presenting");
        Ok(())
    }
```

There's a lot of duplicated code here from creating all the new rectangle meshes and drawing them so sometimes I make a simple function like `fn draw_rectangle(ctx: &mut Context, rect: &graphics::Rect) -> GameResult`, but that's overkill for Pong.

___


It's annoying that stuff isn't properly centered, so let's set our window size to the consts that we used earlier. To create our window and ggez context before, we used this:
```rust
    let (ctx, event_loop) = &mut ggez::ContextBuilder::new("Pong", "Mikail Khan")
        .build()
        .unwrap();
```

Here, we created a [`ContextBuilder`](https://docs.rs/ggez/0.5.1/ggez/struct.ContextBuilder.html) with the default settings and used `build()` immediately. To set our screen size, we want to set the `ggez::conf::WindowMode` of our ContextBuilder. There's a lot of settings but you can find them all in the documentation. Here, all we have to use is `.dimensions()`.

```rust
    let (ctx, event_loop) = &mut ggez::ContextBuilder::new("Pong", "Mikail Khan")
        .window_mode(ggez::conf::WindowMode::default().dimensions(SCREEN_WIDTH, SCREEN_HEIGHT))
        .build()
        .unwrap();
```

After adding this, the window size is set and everything is nicely centered. 

___

In the next part, we'll make Pong playable by finishing the update loop.

You can find the updated code for this part [here](https://github.com/mkhan45/ggez-pong-tutorial/tree/master/part2).

I'll link it here when I'm done.
