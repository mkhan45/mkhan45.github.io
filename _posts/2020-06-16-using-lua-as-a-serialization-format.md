This is somewhat of a followup to [my post on Lua integration](https://mkhan45.github.io/2020/06/12/lua-integration.html) from a few days ago. 

As one part of my senior research project this year, I wrote a universal gravitation simulator meant to help learn/teach physics. The goal was for it to be as accessible/useable as possible, so I spent 90% of the time on UI. One of the main features of the project is that you can save and load preset scenarios, for example, a grid of equal mass bodies or a dual star system.

The project is written in Rust, so during the year, I'd decided to use the super powerful, popular `serde` library, which integrates well with the ECS library I used, `specs`. I serialized to the ron format for no reason in particular other than that it's theoretically human readable.

It worked out pretty ok and I was happy with the results; serialization/deserialization performance isn't that imporant because the simulation can't handle more than ~1000 bodies, so the files are pretty small. My biggest problem is that there was a lot of unnecessary data serialized and there was a lot of spacing, making it kind of unlegible for humans. I didn't care enough to fix it though.

Recently, I added Lua integration to my rewrite of the mechanics simulator part of my project and was really surprised with how easy it was. Initially I'd planned on using Lua only as an alternative to serde/ron serialization just to be more friendly to non-coder users, but given Lua's syntax, you can make input files that are practically markup. 

The mechanics simulator rewrite is very incomplete right now so I didn't want to write a serializer yet, but I decided to move my gravity simulator completely to Lua. The results are pretty great.

___

One of the preset situations, `bench_grid`, is just a huge ~1000 body grid of bodies which repel each other due to their negative mass. It's just meant for benchmarking. With ron serialization, it was represented in a 25k line, 534 kb file.
Each .ron serialized body looks like this:
```ron
 EntityData(
        marker: SimpleMarker(0),
        components: (Some(Position([
            0,
            0,
        ])), Some(Kinematics(
            vel: [
                0,
                0,
            ],
            accel: [
                0,
                0,
            ],
            past_accel: [
                0,
                0,
            ],
        )), Some(Mass(-0.2)), Some(Draw(Color(
            r: 1,
            g: 1,
            b: 1,
            a: 1,
        ))), Some(Radius(5)), Some(Trail(
            points: [],
            max_len: 35,
        ))),
    ),
```

While it's technically human readable/editable, it's very unpleasant. This really isn't what ron was meant for.

Of course, this is a best case scenario for Lua. The Lua file is just this:
```lua
for i = 1, 32 do
   for j = 1, 32 do
      add_body({x = 20 * i, y = 20 * j, mass = -0.1, rad = 2})
   end
end
```
___


For scenarios that don't have any logic, the Lua is practically just markup. Here's a binary star system:
```lua
add_bodies(
	{x = 125.000, y = 70.000, x_vel = 0.000, y_vel = 1.000, mass = 80.000, rad = 4.500},
	{x = 175.000, y = 70.000, x_vel = 0.000, y_vel = -1.000, mass = 80.000, rad = 4.500},
	{x = -30.000, y = 70.000, x_vel = 0.000, y_vel = -1.000, mass = 0.500, rad = 1.000},
	{x = 330.000, y = 70.000, x_vel = 0.000, y_vel = 1.000, mass = 0.500, rad = 1.000}
)
```
IMO, this is way more human readable/editable than the .ron was.

___

As always when user scripting is allowed, this is just the tip of the iceberg. I'm sure that instead of creating a binary star system by hardcoding values, a savvy user could do some math and write a Lua script that could generate an n-star system.

Here's the repo: [https://github.com/mkhan45/gravity-sim-v2](https://github.com/mkhan45/gravity-sim-v2)
