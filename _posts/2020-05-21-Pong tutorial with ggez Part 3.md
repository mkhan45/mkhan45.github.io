This is a continuation of [Pong tutorial with ggez](https://mkhan45.github.io/2020/05/19/Pong-tutorial-with-ggez.html) and [Pong tutorial with ggez part 2](http://localhost:4000/2020/05/20/Pong-tutorial-with-ggez-Part-2.html).

At the end of part 2, we had finished datastructures and a working draw loop. You can find the code from part 2 [here](https://github.com/mkhan45/ggez-pong-tutorial/tree/master/part2).

In this part, we'll finish the update loop and make Pong playable. We're finally getting to some actual gamedev!

___

Right now, our update function looks like this:
```rust
 fn update(&mut self, ctx: &mut ggez::Context) -> ggez::GameResult {
     Ok(())
 }
```

To get Pong going, we need it to:
1. Handle some input
2. Move the ball
3. Handle collisions

And that's pretty much it!

___

## Input handling

Input handling in ggez is roughly split into two methods. We've made `update()` and `draw()` methods in our `impl EventHandler` block, but `EventHandler` also specifies a few other methods including `key_down_event()`, which runs whenever a user presses a key. `key_down_event()` is great when we want to know when a button is pressed once, like if someone jumps in a platformer. It's not good for Pong because we expect the keys to be held down. For Pong, we'll use [`ggez::input::keyboard::is_key_pressed`](https://docs.rs/ggez/0.5.1/ggez/input/keyboard/fn.is_key_pressed.html). All it does is tell us if a specific key is pressed during the current frame.

From the function signature, we can see that this function takes a reference to `Context` and a `ggez::input::keyboard::KeyCode`. `ggez::input::keyboard::KeyCode` is kind of long to type, so you could add `use ggez::input::keyboard::KeyCode` and `use ggez::input::keyboard::is_key_pressed` somewhere at the top of your file. I prefer to have the `keyboard` namespace somewhere though so I usually just `use ggez::input::keyboard` so I can just write `keyboard::is_key_pressed()` and `keyboard::KeyCode` etc.

I want to make the left paddle use W and S to go up and down and make the right paddle use the Up and Down arrows to move. If we look at [the ggez documentation for `KeyCode`](https://docs.rs/ggez/0.5.1/ggez/input/keyboard/enum.KeyCode.html), we can see the proper names of all the available keycodes.

To detect when W is pressed, we just use:
```rust
if keyboard::is_key_pressed(ctx, keyboard::KeyCode::W) {
   // handle W being pressed
}
```

Since we want to move the left paddle up, we can just use `self.l_paddle.y -= 5.0`. It's important to note that like most computer graphics stuff, ggez uses (0, 0) as the top left of the screen and y goes top to bottom while x goes left to right.

Replicating this for the rest of the inputs, we get:
```rust
  if keyboard::is_key_pressed(ctx, keyboard::KeyCode::W) {
      self.l_paddle.y -= 5.0;
  }
  if keyboard::is_key_pressed(ctx, keyboard::KeyCode::S) {
      self.l_paddle.y += 5.0;
  }

  if keyboard::is_key_pressed(ctx, keyboard::KeyCode::Up) {
      self.r_paddle.y -= 5.0;
  }
  if keyboard::is_key_pressed(ctx, keyboard::KeyCode::Down) {
      self.r_paddle.y += 5.0;
  }
```

I chose 5.0 arbitrarily, but we'll probably want to change the speed later, so it's best to set paddle speed as a const at the start of the file:
```rust
const PADDLE_SPEED: f32 = 5.0;
```
Remember to substitute 5.0 in your if statements with `PADDLE_SPEED`.

Now, if you run the game with `cargo run`, the paddles will move when you press buttons!

___

## Making the ball move

Moving the ball is pretty similar to moving the paddles, except that its velocity is stored and it's in two dimensions. We could write:
```rust
self.ball.rect.x += self.ball.vel.x;
self.ball.rect.y += self.ball.vel.y;
```

However, ggez conveniently has a translate function for `Rect`, so we'll just use that:
```rust
self.ball.rect.translate(self.ball.vel);
```

If you run the game... 

Nothing will change. The ball's velocity is <0, 0>.

&nbsp;

We initially hardcoded the ball's velocity in our `main()` method when initializing our `MainState`. We could just tell it to use a random vector in `main()`, but we're going to be resetting the ball a lot later when someone scores, so it's best to just put it in a `Ball::new()` method.

To add a method to our `Ball` type, we use an `impl` block. I'd recommend putting it right after our declaration of the `Ball` struct.
```rust
impl Ball {
   //stuff
}
```

If we just copy over what we have in `main()`, we'd get:
```rust
impl Ball {
    fn new() -> Self {
        Ball {
            rect: Rect::new(
                      SCREEN_WIDTH / 2.0 - BALL_RADIUS / 2.0,
                      SCREEN_HEIGHT / 2.0 - BALL_RADIUS / 2.0,
                      BALL_RADIUS,
                      BALL_RADIUS,
                  ),
                  vel: Vector { x: 0.0, y: 0.0 },
        }
    }
}
```
Note: the signature `fn new() -> Self` indicates that this function returns a ball because in an `impl` block, `Self` is just an alias for whatever is being `impl`'d. We could also use `fn new() -> Ball` but in `new()` methods I think it's more standard to use `Self`.

We need to change `vel: Vector { x: 0.0, y: 0.0 }` to use a random vector. Rust doesn't actually have random number generation in its standard library, but the `rand` crate/library is the standard way to do it. To add `rand` as a dependency, just add `rand = "0.7.3" to the `[dependencies]` section of your `Cargo.toml`.

The function I most use from `rand` is [`Rng::gen_range()`](https://docs.rs/rand/0.7.3/rand/trait.Rng.html#method.gen_range). Here's the example usage from the `rand` documentation:
```rust
use rand::{thread_rng, Rng};

let mut rng = thread_rng();
let n: u32 = rng.gen_range(0, 10);
println!("{}", n);
let m: f64 = rng.gen_range(-40.0f64, 1.3e5f64);
println!("{}", m);
```

We're not going to use `rand` anywhere other than in `Ball::new()`, so it's safe to scope the `use rand::{thread_rng, Rng}` to just this function. The possible starting values we want for the ball's velocity are kind of weird. It would be bad for the velocity to be 0, but it should be possible for it to be negative. Usually I implement this with `rng.gen_range(min_vel, max_vel)` and then use a coin flip to determine whether or not to multiply it by negative one. For a coin flip, we can use `rng.gen::<Bool>()`. 

We also need to do everything twice. Since the x and y velocities need to be different, we can't reuse our `rng.gen_range()`.
Here's what my `Ball::new()` ends up as.

```rust
 fn new() -> Self {
     use rand::{thread_rng, Rng};

     let mut rng = thread_rng(); // initialize random number generator
     let mut x_vel = rng.gen_range(3.0, 5.0); // generate random float from 3 to 5
     let mut y_vel = rng.gen_range(3.0, 5.0);

     // rng.gen::<bool> generates either true or false with a 50% chance of each
     if rng.gen::<bool>() {
         x_vel *= -1.0;
     }
     if rng.gen::<bool>() {
         y_vel *= -1.0;
     }

     Ball {
         rect: Rect::new(
             SCREEN_WIDTH / 2.0 - BALL_RADIUS / 2.0,
             SCREEN_HEIGHT / 2.0 - BALL_RADIUS / 2.0,
             BALL_RADIUS,
             BALL_RADIUS,
         ),
         vel: Vector { x: x_vel, y: y_vel },
     }
 }
```

I used 3.0 and 5.0 as the bounds of `gen_range` arbitrarily, so as usual replace them with consts.
```rust
const MIN_VEL: f32 = 3.0;
const MAX_VEL: f32 = 5.0;
```

We need to replace our hardcoded ball initialization in `main()` with this, so instead of using `ball: Ball { ... }`, we can just use `ball: Ball::new()`.

Now, if you run the game, the ball will move! If you keep rerunning you'll see that it always goes a different direction.

___

## Collisions

As it turns out, collision detection and handling is pretty easy. ggez provides a `.overlaps()` method for `Rect`, and since our paddles and ball all have a `Rect`, we can use it.

In proper Pong, you want the ball to behave differently depending on where on the paddle it collides. For simplicity though, we'll just reverse the x direction.

```rust
  if self.ball.rect.overlaps(&self.l_paddle) || self.ball.rect.overlaps(&self.r_paddle) {
      self.ball.vel.x *= -1.0;
  }
```

It's good practice to also check that the ball is going towards the paddle it's collided with:
```rust
  if (self.ball.vel.x < 0.0 && self.ball.rect.overlaps(&self.l_paddle))
      || (self.ball.vel.x > 0.0 && self.ball.rect.overlaps(&self.r_paddle))
  {
      self.ball.vel.x *= -1.0;
  }
```

As it turns out, it's really hard to catch the ball with a paddle before it goes flying off into nowhere. I've upped `PADDLE_SPEED` to 8.

We also need to make the ball bounce off the top and bottom walls. This is pretty easy. ggez provides `top()` and `bottom()` methods for `Rect` which makes things even simpler.

```rust
  if (self.ball.vel.y < 0.0 && self.ball.rect.top() < 0.0)
      || (self.ball.vel.y > 0.0 && self.ball.rect.bottom() > SCREEN_HEIGHT) {
          self.ball.vel.y *= -1.0;
  }
```

After adding these lines, the game is more or less playable.

## Scorekeeping

Scorekeeping is pretty much the same as collision handling. If the ball goes off the left side of the screen, reset it and add one to the right paddle's score and vice versa. Usually I also add a small pause before the ball resets. Ideally the paddles can still move before the reset, but for simplicity we'll just pause the whole game for a second.

In Rust, we pause a thread with [`std::thread::sleep`](https://doc.rust-lang.org/std/thread/fn.sleep.html). It takes a `std::time::Duration` which we can make using `Duration::from_millis()`.

```rust
  if self.ball.rect.left() < 0.0 {
      self.r_score += 1;
      std::thread::sleep(std::time::Duration::from_millis(1000));
      self.ball = Ball::new();
  }
  if self.ball.rect.right() > SCREEN_WIDTH {
      self.l_score += 1;
      std::thread::sleep(std::time::Duration::from_millis(1000));
      self.ball = Ball::new();
  }
```

There's some duplicated code here, but it seems overkill to make a function just for this.

## Drawing the score

I probably should've included this in the last part, but I forgot.

We want text to be drawn over everything else, so we should put it at the very end of `draw()`. Text in ggez is represented by `ggez::graphics::Text`.

For simplicity, I want to use only one piece of text for the scoreboard. We'll put it in the top center of the screen with the format "L: {score} [tab] R: {score}".

To make our score string, we can use `format!()`. If you've used `println!()`, you already know how `format()` works. Our string can be written with `format!("L: {} \t R: {}", self.l_score, self.r_score)`. We can make a `ggez::graphics::Text` instance out of it with `graphics::Text::new()`.
```rust
let scoreboard_text = 
   graphics::Text::new(format!("L: {} \t R: {}", self.l_score, self.r_score));
```

In general, you shouldn't call `Text::new()` in your draw loop. Text rendering is fairly expensive, so you should cache it and call `Text::new()` only when the text changes.`

To center our text, we need to use `DrawParam`. Previously, we just used `DrawParam::default()` but since `graphics::Text` doesn't have any position data it needs to use `DrawParam` to change location.

The [documentation for `DrawParam`](https://docs.rs/ggez/0.5.1/ggez/graphics/struct.DrawParam.html) tells us that we can use `DrawParam::dest()` to change the location. The input to dest is a `Point2<f32>`, but `Point2<f32>` implements `From<[f32; 2]>`, meaning that we can just use an array of two f32s.

`graphics::Text` has a `width()` method so we have everything we need to make our coordinates and our `DrawParam`:

```rust
let coords = [SCREEN_WIDTH / 2.0 - scoreboard_text.width(ctx) as f32 / 2.0, 10.0];
let params = graphics::DrawParam::default().dest(coords);
```

`graphics::Text` implements `Drawable`, so we can just draw it with `graphics::draw()` as usual:
```rust
graphics::draw(ctx, &scoreboard_text, params).expect("error drawing scoreboard text");
```

If you run it, you'll see the text at the top of the screen! It's kind of small though. `graphics::Text` has a `set_font()` method which also has `font_scale` as an argument. You can, of course, use this to use a custom font with `Font::new()`, but for simplicity we'll just use ggez's default font with `Font::default()`. The `font_scale` argument has to be a `graphics::Scale` object, so we'll use `Scale::uniform()` to make sure the aspect ratio of the font is maintained.

We have to set the font scale before we calculate the coordinates otherwise it will be off center. We also have to make `scoreboard_text` mutable. Here's the finished scoreboard drawing code:
```rust
  let mut scoreboard_text =
      graphics::Text::new(format!("L: {} \t R: {}", self.l_score, self.r_score));
  scoreboard_text.set_font(graphics::Font::default(), graphics::Scale::uniform(24.0));

  let coords = [
      SCREEN_WIDTH / 2.0 - scoreboard_text.width(ctx) as f32 / 2.0,
      10.0,
  ];

  let params = graphics::DrawParam::default().dest(coords);
  graphics::draw(ctx, &scoreboard_text, params).expect("error drawing scoreboard text");
```

And, with that, pong is done!

___

&nbsp;

You can find the completed code on github [here](https://github.com/mkhan45/ggez-pong-tutorial/tree/master/part3).

To learn more, you could expand on this by changing how paddle-ball collisions work. You could also write a simple AI and make it singleplayer.

This is the first long tutorial I've written, so if you have any feedback please email me at mikail.khan45@gmail.com
