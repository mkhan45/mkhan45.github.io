---
layout: post
title: "Writing a JSON Interpreter"
---

A few days ago, I wrote [Javascripth](https://github.com/mkhan45/javascripth), a lispy scripting language that uses JSON as its concrete syntax. It's a single phase treewalk interpreter, so its abstract syntax tree is also JSON, but technically that's true of any interpreter written in JavaScript. Here's an example of some Javascripth code to calculate the 10th fibonacci number:

```json
[
    {"def": {"fib": {"fn": [["n"],
        {"if": {"cond": {"lt": ["n", 2]},
            "then": 1,
            "else": {"+": [
                {"fib": [{"-": ["n", 1]}]},
                {"fib": [{"-": ["n", 2]}]}
            ]}
        }}
    ]}}},
    {"print": {"fib": [10]}}
]
```

It's pretty ugly. It's super slow. Writing it was painful. But it's a Turing complete programming language and its interpreter is only around a hundred lines of code.

I don't remember why I decided to write this anymore. For some reason I thought it was a good idea. It only took around two hours to write the interpreter, and then another two hours to write a solution to Project Euler's first problem. It's not really useful, I could've solved the problem by hand faster. Regardless, given its compactness, I think it's a good learning example of what a basic interpreter looks like.

&nbsp;
___
&nbsp;

I'll start by explaining the rules of the language:

1. A program is defined by a JSON array of statements, which are evaluated in order.
2. A statement is a JSON object (dictionary/map) or atom (number, boolean) which may or may not have side effects.
3. A "form" is a JSON object key-value pair. For example in the expression {"+": [5, 2]}, "+" is the form (and a function) and [5, 2] is the argument list
4. There are a few special forms including "def", "fn", etc. If the form is not one of these, it is treated as a function call

Side Note: It might be pretty simple to make it possible to create user defined forms through JavaScript, which would add a lot of power to the language.

So let's take a look at the interpreter. There's barely any data stored; just a `state` dictionary which contains global variables. The constructor just initializes a few builtin functions. All the work of the interpreter really happens in the `eval()` function. I'll go through this function block by block.

---

```js
if (typeof expr === 'number' || typeof expr === 'boolean') {
            return expr;
}

if (typeof expr === 'string') {
    return this.state[expr];
}

if (Array.isArray(expr)) {
    return expr.map(s => this.eval(s));
}
```

These conditionals evaluate atomic expressions. If an expression is a number or boolean, it's already evaluated. If it's a string, it's treated as a global variable and fetched from the dictionary, and if it's an array, each expression in the array is evaluated.

---

```js
const res = Object.keys(expr).map(key => {
    let args = expr[key];
    ...
})
```

If the expression is a dictionary, look through every key, and let the arguments be the value that corresponds with said key.

```js
 if (key === 'def') {
    for (const name in args) {
        this.state[name] = this.eval(args[name]);
    }
    return;
}
```

The first builtin form is 'def', which is used to define global variables. Different from other forms, 'def' uses a dictionary as its argument, in which each key-value pair directly corresponds to the global variable dictionary.

```js
if (key === 'fn') {
    if (Array.isArray(args)) {
        // contains argnames list
        const [argnames, expr] = args;
        const fn = new Fn(expr, argnames);
        return fn.compile(this);
    } else {
        // only contains expr
        const expr = args;
        const fn = new Fn(expr);
        return fn.compile(this);
    }
}
```

The second builtin form is 'fn', which is used to define anonymous functions. There are two ways to define anonymous functions; with a list of argument names, in which arguments must be passed in as a list, or without a list of arg names, in which case you pass in an argument dictionary. This is used for named variables and optional arguments. This code is decievingly simple because of the `Fn` class:

```js
class Fn {
    constructor(expr, argnames) {
        this.expr = expr;
        this.argnames = argnames;
    }

    compile(interpreter) {
        return args => {
            if (this.argnames) {
                let args_dict = {};
                for (let i = 0; i < this.argnames.length; i += 1) {
                    const arg_name = this.argnames[i];
                    const arg_val = args[i];
                    args_dict[arg_name] = arg_val;
                }

                args = args_dict;
            }

            const new_interpreter = new Interpreter();
            new_interpreter.state = {...interpreter.state, ...new_interpreter.state, ...args};
            return new_interpreter.eval(this.expr);
        }
    }
}
```

It looks pretty simple, but figuring out how functions work took the bulk of the time writing this interpreter. There were definitely a few different function implementations that didn't work before this. The code itself is fairly straightforward. `compile()` actually returns an anonymous function with the sole argument `args`. If the function has `argnames`, it must be called using a list of arguments in order. In this case, it constructs a list of local variables for the function by just zipping the argument names and values into a dictionary. If the function doesn't have `argnames`, this is already done. Using the dictionary of local variables, we just construct a new `Interpreter` instance whose state is just the defaults, globals from the calling scope, and then function args on top. Finally, we evaluate the expression with this new scope and return it. I can't stress enough that this really is the core of the interpreter. There's no mutation so everything that allows state to actually change in some sense is done through functions.

___

```js
if (key === 'if') {
    const cond = this.eval(args['cond']);
    if (cond) {
        return this.eval(args['then']);
    } else {
        return this.eval(args['else']);
    }
}

if (key === 'print') {
    console.log(this.eval(args));
    return;
}
```

These two forms are pretty simple.

---

```js
if (args.map)
    args = args.map(e => this.eval(e));
else
    args = this.eval(args);
```

These few lines just make sure that all the arguments are properly evaluated before getting passed in somewhere that they shouldn't be. I'm pretty sure this is is redundant in some cases and it would probably make the interpreter a lot faster if this were done properly.

---

```js
if (key in this.state && typeof this.state[key] === 'function') {
    return this.state[key](args);
}
```

If the form is not one of the builtins, then it must be a function. Functions in this language are just anonymous functions, so we can just call it on the argument dictionary normally.

I never know how to end these posts ¯\\_(ツ)_/¯
