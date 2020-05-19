I saw a post on reddit asking for a simple game dev tutorial with Rust. Generally people encourage using ECS with any Rust game, so I guess there's no tutorials for anything without it. However, for simple games like Pong or Flappy Bird, it really is easier to forgo the ECS.

While Amethyst, the biggest Rust game engine, is completely built on ECS and you can't make a game without it, there's still plenty of small game engines that don't make any assumptions. My favorite of these is ggez.

With this tutorial I won't try to explain very much syntax. You should probably read at least a few chapter of the book to understand everything.

I'd recommend also opening the [ggez documentation](https://docs.rs/ggez/0.5.1/ggez/index.html) while following this tutorial.

___

## Project setup

To get started, make a new folder and initialize a Rust project with `cargo init`. If you don't have rust installed, install it with [rustup](https://rustup.rs/). If you're on Linux rustup is probably already in your distro's repositories.

After running `cargo init`, you should have a folder structure like this:
```
.
├── Cargo.lock
├── Cargo.toml
└── src
    └── main.rs
```

Cargo.toml contains the manifest info for your Rust crate (crate is Rustacean for package). Mine looks like this:

```toml
[package]
name = "pong_tutorial"
version = "0.1.0"
authors = ["Mikail Khan <mikail.khan45@gmail.com>"]
edition = "2018"

# See more keys and their definitions at https://doc.rust-lang.org/cargo/reference/manifest.html

[dependencies]

```

The src/ directory is where all of your Rust code goes. main.rs comes with Hello World already written:
```rust
fn main() {
    println!("Hello, world!");
}
```

Run `cargo build` to build your project, and `cargo run` to run it. If you just want to check for project for syntax and type errors, run `cargo check`. It's a lot faster than `cargo build`.

___

## ggez basics

Adding ggez as a dependency is pretty simple. Just go to the `dependencies` section of your Cargo.toml and add `ggez = "0.5.1"`
```toml
[package]
name = "pong_tutorial"
version = "0.1.0"
authors = ["Mikail Khan <mikail.khan45@gmail.com>"]
edition = "2018"

# See more keys and their definitions at https://doc.rust-lang.org/cargo/reference/manifest.html

[dependencies]
ggez = "0.5.1"
```

Run `cargo build` now to download and build ggez and all of its dependencies. It might take a few minutes.

The behavior of the program hasn't actually changed at all yet. `cargo run` will still just output "Hello, World!".

ggez works by creating a graphics context and an event loop and then using a user defined struct with specific methods implemented to run the game. ggez comes with a specific function to make the actual game run. It has this signature:
```rust
pub fn run<S>(
    ctx: &mut Context, 
    events_loop: &mut EventsLoop, 
    state: &mut S
) -> GameResult where
    S: EventHandler,
```

What this tells us is that to get started we need:
- [ ] A ggez `Context`
- [ ] A ggez `EventsLoop`
- [ ] A struct that implements `EventHandler`

We can actually make a `Context` and `EventsLoop` with a single step, so let's get that out of the way. Clear your main method and add this:

```rust
fn main() {
   let (ctx, event_loop) = &mut ggez::ContextBuilder::new("Pong", "Mikail Khan").build();
}
```

ggez nicely comes with a `ContextBuilder` to make a `Context` and `EventsLoop`. This is an example of the builder pattern in Rust.

`ggez::ContextBuilder::new("Pong", "Mikail Khan")` creates a `ContextBuilder` with title "Pong" and author "Mikail Khan". Running `.build()` on it creates a `Context` and `EventsLoop`. The `&mut` at the front makes sure that we get a mutable reference to the created values.

Next, we need a struct that implements `ggez::event::EventHandler`. For convenience, add `use ggez::event::EventHandler` to the start of the file. Next, make a struct `MainState`. It doesn't need to have anything for now.

```rust
struct MainState {
}
```

Next, we need to implement `EventHandler` for `MainState`. `EventHandler` is the trait that lets ggez know what to do with your struct to get the game going. It sets up the main loop and the draw loop for your game.

```rust
impl EventHandler for MainState {
}
```

If you run `cargo check` (or `cargo build`) now, you'll get an error:
```
error[E0046]: not all trait items implemented, missing: `update`, `draw`
  --> src/main.rs:20:1
   |
20 | impl EventHandler for MainState {
   | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ missing `update`, `draw` in implementation
   |
   = help: implement the missing item: `fn update(&mut self, _: &mut ggez::context::Context) -> std::result::Result<(), ggez::error::GameError> {
 todo!() }`
   = help: implement the missing item: `fn draw(&mut self, _: &mut ggez::context::Context) -> std::result::Result<(), ggez::error::GameError> { t
odo!() }`
```

This error tells us that we're missing two functions and gives us their signatures. If we follow its advice, we get:

```rust
impl EventHandler for MainState {
    fn update(&mut self, ctx: &mut ggez::Context) -> ggez::GameResult {
        todo!()
    }

    fn draw(&mut self, ctx: &mut ggez::Context) -> ggez::GameResult {
        todo!()
    }
}
```

`todo!()` is a macro which just exits the program with an error.

Now that we have the skeleton of a struct that implements `EventHandler`, we can complete our main method for now:

```rust
fn main() {
    // create a mutable reference to a `Context` and `EventsLoop`
    let (ctx, event_loop) = &mut ggez::ContextBuilder::new("Pong", "Fish").build().unwrap();

    // Make a mutable reference to `MainState`
    let main_state = &mut MainState {};

    // Start the game
    ggez::event::run(ctx, event_loop, main_state);
}
```

The program is now runnable! It doesn't do anything yet though. We get this error:
```
thread 'main' panicked at 'not yet implemented', src/main.rs:22:9
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

That's because ggez tried to run our `update()` method, which just has a `todo!()`.

There's also one warning: 
```
warning: unused `std::result::Result` that must be used
  --> src/main.rs:38:5
   |
38 |     ggez::event::run(ctx, event_loop, main_state);
   |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = note: `#[warn(unused_must_use)]` on by default
   = note: this `Result` may be an `Err` variant, which should be handled
```

This error tels us that `ggez::event::run` returns a `Result`, which might be an error. If it's an error, we should handle it. However, if this function fails, the program can't really recover. Also, it's going to be the last line in `main()`. To fix this, we can make `main()` return a `Result`. This is useful because if `main()` fails the error will just be printed when the program crashes. `ggez::event::run()` specifically returns a `ggez::GameResult`, so that's what we should make `main()` return. 

Change the function signature to 
```rust
fn main() -> ggez::GameResult
```

If we try to compile this (or `cargo check` it), we'll get another error: 
```
error[E0308]: mismatched types
  --> src/main.rs:30:14
   |
30 | fn main() -> ggez::GameResult {
   |    ----      ^^^^^^^^^^^^^^^^ expected enum `std::result::Result`, found `()`
   |    |
   |    implicitly returns `()` as its body has no tail or `return` expression
...
38 |     ggez::event::run(ctx, event_loop, main_state);
   |                                                  - help: consider removing this semicolon
   |
   = note:   expected enum `std::result::Result<(), ggez::error::GameError>`
           found unit type `()`

error: aborting due to previous error

For more information about this error, try `rustc --explain E0308`.
```

The Rust compiler helpfully tells us exactly what to do. If we remove the last semicolon on our `ggez::event::run()` call, `main()` will return it. Now, `main()` looks like this:
```rust
fn main() -> ggez::GameResult {
    // create a mutable reference to a `Context` and `EventsLoop`
    let (ctx, event_loop) = &mut ggez::ContextBuilder::new("Pong", "Fish").build().unwrap();

    // Make a mutable reference to `MainState`
    let main_state = &mut MainState {};

    // Start the game
    ggez::event::run(ctx, event_loop, main_state)
}
```

To stop the game from crashing immediately, we should replace the bodies of our `update()` and `draw()` functions with something other than `todo!()`. Since both of them also return a `Result`, we can make both of them just return `Ok(())`, which just means that there's been no errors.
```rust
impl EventHandler for MainState {
    fn update(&mut self, _: &mut ggez::Context) -> ggez::GameResult {
        Ok(())
    }

    fn draw(&mut self, _: &mut ggez::Context) -> ggez::GameResult {
        Ok(())
    }
}
```

Running the program now will create a blank window and do nothing. That's the start of the game!

You can find the full code so far [on Github here](https://github.com/mkhan45/ggez-pong-tutorial/tree/master/part1). 

If you have any feedback, please email me at mikail.khan45@gmail.com

I'll write Part 2 soon and link it here.
