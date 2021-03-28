A few days ago, I started working on a digital electronics/logic simulator along the lines of <https://github.com/SebLague/Digital-Logic-Sim>.

To start out, I needed to construct a graph structure of logical components such as AND/OR gates. I also plan on adding much more complicated components such as ALUs. There are plenty of ways to construct a graph like this, but I wanted to optimize for safety and speed. I also wanted to use an Entity-Component-System architecture (ECS) for other stuff in the program, so I thought it'd be nice to have the whole graph stored in entities as well.

I also started writing this the day after const generics were stabilized in Rust, so they were on my mind and I decided that they could work pretty well. A `Node` is pretty logically represented like so:

```rs
pub trait Node<const I: usize, const O: usize> {
    fn calculate_state(inputs: [bool; I]) -> [bool; O];
}

pub struct OnNode;
impl Node<0, 1> for OnNode {
    fn calculate_state(_: [bool; 0]) -> [bool; 1] {
        [true]
    }
}

pub struct AndNode;
impl Node<2, 1> for AndNode {
    fn calculate_state(input: [bool; 2]) -> [bool; 1] {
        [input[0] && input[1]]
    }
}
```

This way, nodes don't carry any data with them, and it's super easy to make new ones. However, you might've noticed that this isn't anywhere near a graph; the Nodes aren't connected to anything.

To make the actual graph structure, I made a `Connected` struct:

```rs
#[derive(Component)]
pub struct Connected<N, const I: usize, const O: usize>
where
    N: Node<I, O> + 'static,
{
    pub node: PhantomData<N>, // PhantomData is erased at runtime, very cool
    pub inputs: [Option<Entity>; I],
    pub outputs: [Option<Entity>; O],
}
```

There's an issue here: the inputs and outputs are stored as specs Entities, but surely not every Entity will be a proper graph node. I'm not sure if anything can be done about this but the nice thing is that when it crashes it will crash hard and it shouldn't be difficult to debug.

The next step is to actually run the logic. The `calculate_state()` function on each `Node` uses an array of inputs and outputs, so the node directly before and after a logical node has to be one to one. Additionally, I wanted there to be a buffer of sorts so that I could run each step of the circuit discretely. However, neither `Connected` or `Node` actually carry any state with them. The solution I came up with is a `Wire` struct/node.

```rs
pub struct Wire {
    pub input_state: bool,
    pub output_state: bool,
}

impl Node<1, 1> for Wire {
    fn calculate_state(i: [bool; 1]) -> [bool; 1] {
        i
    }
}
```

If I want to make fat wires that can carry multiple bits I could use:

```rs
impl<const S: usize> Node<S, S> for Wire {
    fn calculate_state(i: [bool; S]) -> [bool; S] {
        i
    }
}
```

I'm not sure if it would have any uses but it's cool that it's possible.

The neat thing about the `Wires` is that all the state of the circuit is contained in them. By having an input and output state separately, I can also step through the circuit discretely using this system:

```rs
pub struct WireSys;
impl<'a> System<'a> for WireSys {
    type SystemData = WriteStorage<'a, Wire>;

    fn run(&mut self, mut wires: Self::SystemData) {
        (&mut wires).join().for_each(|wire| {
            wire.output_state = wire.input_state;
            wire.input_state = false;
        });
    }
}
```

I also use this system to run the non-wire nodes:

```rs
pub struct ElectroSys<N, const I: usize, const O: usize>
where
    N: Node<I, O> + 'static,
{
    node: PhantomData<N>,
}

impl<'a, N, const I: usize, const O: usize> System<'a> for ElectroSys<N, I, O>
where
    N: Node<I, O> + 'static,
{
    type SystemData = (WriteStorage<'a, Connected<N, I, O>>, WriteStorage<'a, Wire>);

    fn run(&mut self, (mut nodes, mut wires): Self::SystemData) {
        // direct inputs and outputs must be wires
        (&mut nodes).join().for_each(|node| {
            let mut inputs = [false; I];
            for (i, input_entity) in node.inputs.iter().enumerate() {
                match input_entity {
                    Some(e) => {
                        let wire = wires.get(*e).expect("All inputs must be a wire");
                        inputs[i] = wire.output_state;
                    }
                    None => return,
                }
            }

            let outputs = N::calculate_state(inputs);
            dbg!(inputs, outputs);

            for (i, output_entity) in node.outputs.iter().enumerate() {
                if let Some(e) = output_entity {
                    wires.get_mut(*e).unwrap().input_state = outputs[i];
                }
            }
        })
    }
}
```

The issue with this is that I have to register a new system for each non-wire node:

```rs
pub fn add_node_systems<'a, 'b>(builder: DispatcherBuilder<'a, 'b>) -> DispatcherBuilder<'a, 'b> {
    builder
        .with(WireSys, "wire_sys", &[])
        .with(
            ElectroSys::<OnNode, 0, 1>::default(),
            "on_node_sys",
            &["wire_sys"],
        )
        .with(
            ElectroSys::<OffNode, 0, 1>::default(),
            "off_node_sys",
            &["wire_sys"],
        )
        ...
}
```

I'll probably write a macro to make it easier.

All in all though, I'm pretty happy with the results. I'm not sure if this is the best solution but I think it's a good one. Maybe I'll remember to update this post in a month or two when the project is hopefully more or less finished.

By the way, I've recently made a Twitter but I'm getting flagged for not having followers so if you've enjoyed any of my posts consider following me: <https://twitter.com/fiiissshh>. I'll mostly post about Rust and other dev stuff.

You can also find the repository (very very early in development) here: <https://github.com/mkhan45/SIMple-Electronics>
