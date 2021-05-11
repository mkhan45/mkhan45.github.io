---
layout: post
title: "Writing a Tiny Stack VM in Rust"
---

A few days ago I wrote a super simple postfix expression evaluator to demonstrate how stacks could be used to a friend. Afterwards, I decided to finally get around to learning how full stack VMs work so I expanded it into a full stack VM for which you could theoretically write a compiler. It turned out to be super concise and pretty fast.

This guide is meant to be supplementary to reading the code of TinyVM: <https://github.com/mkhan45/tinyvm/blob/main/src/main.rs>. If you're familiar with Rust but know nothing about Stack VMs, you should hopefully be able to understand how stack VMs work just by reading the code. Otherwise, this guide can explain some design decisions and give a higher level overview of some steps. To get an idea of what kinds of programs this VM can run, check out the [test files](https://github.com/mkhan45/tinyvm/tree/main/test_files).

So there are two main components to a stack VM: a list of instructions and a stack of values. For this stack VM, the values are just signed 64 bit integers, so in Rust the `Stack` looks like this:

```rs
struct Stack(Vec<isize>);

// Since this is just a learning project
// there's no proper error handling.
// These helper methods are just so that 
// it's easier to ignore errors.
impl Stack {
    fn push(&mut self, v: isize) {
        self.0.push(v);
    }

    fn pop(&mut self) -> isize {
        self.0.pop().expect("popped an empty stack")
    }

    fn peek(&mut self) -> isize {
        *self.0.last().expect("peeked an empty stack")
    }

    fn peek_mut(&mut self) -> &mut isize {
        self.0.last_mut().expect("peeked an empty stack")
    }
}
```

The next important part is the list of instructions. In Rust, it's very easy to represent these with enums. To start out, all we need is:

```rs
enum Inst {
    Push(isize),
    Pop,
    Add,
    Sub,
}
```

For non Rustaceans, this means that an `Inst` is either a label `Push` with an integer payload, or a `Pop`, an `Add`, or a `Sub`.

In my VM, I've made a type alias of program to a list of `Inst`:

```rs
type Program<'a> = &'a [Inst];
```

The lifetime annotations (`'a`) can safely be ignored if you don't know what they mean.

With this, we can safely `interpret()` a `Program`.

```rs
fn interpret<'a>(program: Program<'a>) -> isize {
    use Inst::*;

    // instantiate stack as an empty Vector
    let mut stack = Stack(Vec::new());

    for instruction in program {
        match instruction {
            // pushes the data to the stack
            Push(d) => stack.push(*d),
            // Pops a value off the stack
            Pop => stack.pop(),
            // Adds the top two values on the stack:
            // [3, 1, 1] -> [3, 2]
            Add => {
                let (a, b) = (stack.pop(), stack.pop());
                stack.push(a + b);
            }
            // Subtracts the top two values on the stack:
            // [3, 3, 1] -> [3, 2]
            Add => {
                let (a, b) = (stack.pop(), stack.pop());
                stack.push(b - a);
            }
        }
    }

    stack.pop()
}
```

Running `interpret(vec![Push(9), Push(3), Push(1), Add, Sub].as_slice())` returns 5. This is the result of `(- (+ 1 3) 9)`, or `9 - (1 + 3)`.

___

So this is pretty cool but it's obviously not a stack VM. It can process arithmetic expressions but that's it. Luckily, it's actually not that far off from being able to do a whole lot more. The first step is to add the `Print` instruction which just prints the value on top of the stack. This is an important milestone because it takes the program from essentially a pure function with an input and an output to a full interpreter with observable side effects.

`Print` is super easy to implement. The first step is to add the variant to the `Inst` enum:

```
enum Inst {
    Push(isize),
    ...
    Print,
}
```

Next, we tell the interpreter what to do with it:

```rs
fn interpret<'a>(program: Program<'a>) {
    use Inst::*;

    // instantiate stack as an empty Vector
    let mut stack = Stack(Vec::new());

    for instruction in program {
        match instruction {
            Push(d) => stack.push(*d),
            ...
            Print => println!("{}", stack.peek()),
        }
    }
}
```

Note that I also removed the return since we can print intermediate values anyway.

Now, we can essentially do multiple calculations and print the result:

```rs
interpret(vec![
    Push(5),
    Push(10),
    Add,
    Print,
    Push(25),
    Sub,
    Print,
    Push(10),
    Add,
    Print,
].as_slice())
```

It will print: 
```
15
-10
0
```

___

Well we can print stuff now, but the upper limit for program complexity is still quite low. In the next section, we'll take this from a simple expression evaluator to aturing complete interpreter in just two steps.

First, we need jumps and conditional jumps. A jump takes us from one point in the code to another, and a conditional jump jumps only if a condition is met, otherwise it just moves on.

To add this, we need to be able to access the instruction list at any point, instead of just in sequence. In Rust, just add the current instruction pointer as a mutable variable, and change the `for each` loop to a `while let` loop:

```rs
fn interpret<'a>(program: Program<'a>) {
    use Inst::*;

    // instantiate stack as an empty Vector
    let mut stack = Stack(Vec::new());
    let mut pointer = 0;

    while let Some(instruction) = program.get(pointer) {
        pointer += 1;

        match instruction {
            ...
        }
    }
}
```

Next, we add the `Jump`, `JE`, and `JNE` instructions. Jump unconditionally jumps, JE jumps if the top of the stack is equal to zero, and JNE jumps if the top of the stack is not equal to zero. Right now, we'll just specify an index in the instruction list to jump to.

The new `Inst` enum looks like:

```rs
type Pointer = usize;

enum Inst {
    Push(Pointer),
    ...
    Jump(Pointer),
    JE(Pointer),
    JNE(Pointer),
}
```

And to `interpret` the new instructions, we add:

```rs
fn interpret<'a>(program: Program<'a>) {
    use Inst::*;

    // instantiate stack as an empty Vector
    let mut stack = Stack(Vec::new());
    let mut pointer = 0;

    while let Some(instruction) = program.get(pointer) {
        pointer += 1;

        match instruction {
            ...
            Jump(p) => pointer = *p;
            JE(p) => {
                if stack.peek() == 0 {
                    pointer = *p;
                }
            }
            JNE(p) => {
                if stack.peek() != 0 {
                    pointer = *p;
                }
            }
        }
    }
}
```

This opens a world of possibilities. We can do loops pretty easily with JNE:

```rs
interpret(vec![
    Push(10),
    Print,
    Push(1),
    Sub,
    JNE(0),
].as_slice());
```

This prints all the numbers from 10 to 0:
```
10
9
8
7
6
5
4
3
2
1
```

The next step is to make it possible to access or change arbitrary stack values. After this the VM will be Turing complete.

Here are the new instructions:

```rs
enum Inst {
    ...
    Get(Pointer),
    Set(Pointer),
}
```

`Get(p)` just indexes the stack at n and copies it to the top of the stack. `Set(p)` takes the value at the top of the stack and copies it to the stack at index p.

```rs
while let Some(instruction) = program.get(pointer) {
    pointer += 1;

    match instruction {
        ...
        Get(p) => stack.push(*stack.0.get(*p).unwrap()),
        Set(p) => {
            let v = stack.pop();
            *stack.0.get_mut(*p).unwrap() = v;
        }
    }
}
```

At this point, since we can `Get` values from the stack, we want to make our `JNE` and `JE` instructions pop the comparison value:

```rs
while let Some(instruction) = program.get(pointer) {
    pointer += 1;

    match instruction {
        ...
        JE(p) => {
            if stack.peek() == 0 {
                stack.pop();
                pointer = *p;
            }
        }
        JNE(p) => {
            if stack.peek() != 0 {
                stack.pop();
                pointer = *p;
            }
        }
    }
}
```

Using these new instructions, we can write some slightly more complex programs. Here's a program to sum the first 100 integers:

```rs
interpret(vec![
    // setup
    Push(0), // the accumulator
    Push(0), // the index

    // loop
    // First, add the index to the accumulator
    // stack: [accumulator, index]
    Get(0),
    Get(1),
    // stack: [accumulator, index, accumulator, index]
    Add,
    // stack: [accumulator, index, accumulator + index]
    Set(0),
    Pop,
    // stack: [accumulator + index, index]

    // next, increment the index
    Push(1), // the increment
    // stack: [accumulator, index, 1]
    Add,
    // stack: [accumulator, index + 1]

    // finally, compare the index with 100 and jump back to the start
    // if they're not equal.
    Get(1),
    // stack: [accumulator, index, index]
    Push(100),
    Sub,
    // stack: [accumulator, index, index - 100]
    JNE(2),

    // if index - 100 == 0, print the accumulator
    Get(0),
    // stack: [accumulator, index, 0, accumulator]
    Print
].as_slice())
```

Just like that, the VM is Turing complete! It's super awkward to use though. We can jump to different portions of the code, but since we jump by line number we have to update each jump whenever we change the code. Later, we'll fix this by writing a super simple compiler that resolves text labels to line numbers.

The following code is super Rusty so I won't explain it in detail, but essentially it splits each line on space, iterates through them, and constructs a HashMap of label names to line numbers.

```rs
// find_label takes a line split by spaces and the label it represents,
// or None if it does not represent a label.
fn find_label<'a>(i: Pointer, s: &'a [&'a str]) -> Option<Label> {
    if let ["label", l] = s {
        Some((l, i))
    } else {
        None
    }
}

let input = ...; // a String

let line_splits = input
        .split('\n')
        .map(|s| s.split_whitespace().collect::<Vec<_>>())
        .filter(|s| !matches!(s.as_slice(), [] | ["--", ..]))
        .collect::<Vec<_>>();

let labels: HashMap<&str, usize> = line_splits
    .iter()
    .enumerate()
    .filter_map(|(i, s)| find_label(i, s.as_slice()))
    .collect();
```

Now we need to use this info to actually compile the instructions. This is also pretty Rusty but it's very concise.

```rs
fn parse_instruction(s: &[&str], labels: &Labels) -> Instruction {
    use Instruction::*;

    match s {
        ["Push", x] => Push(x.parse::<isize>().unwrap()),
        ["Pop"] => Pop,
        ["Add"] => Add,
        ["Sub"] => Sub,
        ["Mul"] => Mul,
        ["Div"] => Div,
        ["Jump", l] => Jump(*labels.get(l).unwrap()),
        ["JE", l] => JE(*labels.get(l).unwrap()),
        ["JNE", l] => JNE(*labels.get(l).unwrap()),
        ["Get", p] => Get(p.parse::<Pointer>().unwrap()),
        ["Set", p] => Set(p.parse::<Pointer>().unwrap()),
        ["Print"] => Print,
        ["label", ..] => Noop,
        l => panic!("Invalid instruction: {:?}", l),
    }
}
```

You might notice that lines starting with label get compiled to a Noop. This is just to make the line numbers easy to keep track of; you could do without it if you sort out all the off by one errors.

we map this function over the list of lines to actually "compile" the text to instructions:

```rs
let instructions: Vec<Instruction> = line_splits
    .iter()
    .map(|s| parse_instruction(s.as_slice(), &labels, &procedures))
    .collect();
```

now we can easily interpret the compiled instructions with `interpret(instructions.as_slice())`. Using this, we can easily rewrite the sum example from before:

```
Push 0
Push 0

label loop
    -- [accumulator, index]
    Get 0
    Get 1
    -- [accumulator, index, accumulator, index]
    Add
    -- [accumulator, index, accumulator + index]
    Set 0
    Pop
    -- [accumulator + index, index]

    -- [accumulator, index]
    Push 1
    Add
    -- [accumulator, index + 1]

    -- [accumulator, index]
    Get 1
    Push 100
    Sub
    -- [accumulator, index, index - 100]
    JNE loop
Pop

Get 0
Print
```

---

Labels are pretty neat. Now let's add procedures.

Procedures in this VM are basically just labels that jump back to the point that they were called at. This makes reasoning about logic a whole lot easier. It also means that we have to implement a call stack. A call stack is just a list of stack frames, and at first our stack frame just looks like this:

```rs
struct StackFrame {
    pub ip: usize, // ip is a common acronym for instruction pointer
}
```

Since our Call Stack is just a stack of call frames, it looks like this:

```rs
type CallStack = Vec<StackFrame>;
```

The first step is just to initialize our call stack at the start of the interpret function.

```rs
fn interpret<'a>(program: Program<'a>) {
    ...
    let mut stack = Stack(Vec::new());
    let mut call_stack = CallStack::new();
    ...
}
```

Next, we'll add some instructions:

```rs
enum Instruction {
    ...
    Call(Pointer),
    Ret,
}
```

Call is the instruction we'll use to enter a procedure. It's basically a jump, but it also pushes the call location to the call stack. Ret just pops the call stack and returns to the location the procedure was called from.

```rs
match instruction {
    ...
    Call(p) => {
        call_stack.push(StackFrame {
            ip: pointer
        });
        pointer = *p;
    }
    Ret => pointer = call_stack.pop.unwrap().ip,
}
```

You might've noticed that Call accepts a pointer as an argument. We don't want to be specifying procedures by a pointer in our code though, so we'll add another compile step just like we did with labels. This is a bit more involved because we need to know where the end of a procedure is as well as where it starts, otherwise we won't be able to skip the procedure when we run into it in the code without it being called. 

There are better ways to do this, but in TinyVM procedure declarations are resolved to a Jump. We use the End marker to just mark the end of a procedure declaration.

```
Proc proc_name // line n
    ...   
End // line n + l

...

Call proc_name
```

Gets resolved to

```
Jump (n + 1)
    // procedure contents
    ...
...

Call (n)
```

This code is also a hairy and Rust specific, so I won't explain the details.

```rs
type Procedures<'a> = BTreeMap<&'a str, (Pointer, Pointer)>;

// find_procedures takes a list of lines split on space and
// returns the procedures declared.
fn find_procedures<'a>(lines: &'a [Vec<&str>]) -> Procedures<'a> {
    let mut ip = 0;
    let mut res = Procedures::new();

    while ip < lines.len() {
        if let ["Proc", proc_name] = lines[ip].as_slice() {
            let start_ip = ip;
            while lines[ip] != &["End"] {
                ip += 1;
            }
            res.insert(proc_name, (start_ip, ip + 1));
        } else {
            ip += 1;
        }
    }

    res
}
```

We use this map just like we used the label one in the `parse_instruction` function.

```rs
fn parse_instruction(s: &[&str], labels: &Labels, procedures: &Procedures) -> Instruction {
    ...

    match s {
        ...
        ["Proc", proc] => Jump(procedures.get(proc).unwrap().1),
        ["Call", proc] => Call(procedures.get(proc).unwrap().0 + 1),
        ["Ret"] => Ret,
        ["label", ..] | ["End"] => Noop,

    }
}
```

With that, we can write some simple procedures

```
-- assumes [a, b, c] top of stack
Proc addMul
    Add
    Mul
    Ret
End
```

This procedure takes a stack [..., a, b, c] and turns it into [..., a * b + c].

The issue here is that it's really difficult to do nontrivial calculations since we don't know what index on the stack to access variables at. For example, how would we write a procedure to square the value on top of the stack? We would have to `Get` the top value, but we don't know it's index.

In TinyVM, this is solved by adding another parameter to each stack frame; the stack offset, or the length of the stack when it was called. We then add two new instructions; `GetArg` and `SetArg`. These two instructions reference stack indices *before* the stack offset. For example, in the square procedure, we would use `GetArg 0` to  access the value that was on top of the stack before the procedure was called. We also have to update Get and Set to only access indices *after* the stack offset.

```
Proc square
    -- stack is [..., x]
    GetArg 0
    -- stack is [..., x, x]
    Mul
    -- stack is [..., x * x]
    Ret
End
```

We can also write some way more interesting procedures. Here's factorial:

```
Proc fibStep
    GetArg 0
    GetArg 1
    -- [a, b, | b, a]
    Add
    -- [a, b, | b + a]
    GetArg 0
    -- [a, b, | b + a, b]
    SetArg 1
    Pop
    -- [b, b, | b + a]
    SetArg 0
    Pop
    -- [b, b + a | ]
    Ret
End
```

This procedure turns stack [..., a, b] into [..., b, b + a]. It's used to calculate the nth fibonacci number iteratively:

```
Push 0
Push 1
Push 1

-- [i, a, b]
label loop
    Call fibStep
    -- [i, a, b]
    Get 0
    Push 1
    -- [i, a, b, i, 1]
    Add
    -- [i, a, b, i + 1]
    Set 0
    Pop
    -- [i + 1, a, b]
    -- [i, a, b]
    Get 0
    Push 40
    Sub
    -- [i, a, b, i - 40]
    JNE loop
    Pop
-- [i, a, b]

Print
```

Implementing this is pretty straightforward logically but a bit prone to off by one errors. First, we just update our StackFrame struct:

```rs
struct StackFrame {
    pub stack_offset: Pointer,
    pub ip: Pointer,
}
```

Next, we update our Call, Get, Set, GetArg, and SetArg functions.

```rs
fn interpret<'a>(program: Program<'a>) {
    ...
    match instruction {
        // the .map_or just makes sure that the stack offset is treated as zero 
        // when the stack is empty.
        Get(i) => stack.push(*stack.get(*i + call_stack.last().map_or(0, |s| s.stack_offset))),
        Set(i) => {
            *stack
                .0
                .get_mut(*i + call_stack.last().map_or(0, |s| s.stack_offset))
                .unwrap() = stack.peek()
        }
        GetArg(i) => stack.push(
            *stack
                .0
                .get(call_stack.last().unwrap().stack_offset - 1 - *i)
                .unwrap(),
        ),
        SetArg(i) => {
            let offset_i = call_stack.last().unwrap().stack_offset - 1 - *i;
            let new_val = stack.peek();
            *stack.get_mut(offset_i) = new_val;
        }
        Call(p) => {
            call_stack.push(StackFrame {
                stack_offset: stack.0.len(),
                ip: pointer,
            });
            pointer = *p;
        }
    }
}
```

And that's it! Using this VM, you could write pretty much any computation. As an exercise, you could implement user input to add a lot more functionality. You could also try implementing a compiler for this VM. It runs quite quickly since it only supports one type of value.

---

Recently I've made a Twitter account where I'm tweeting a lot about my projects. Consider following me [@fiiissshh](https://twitter.com/fiiissshh).
