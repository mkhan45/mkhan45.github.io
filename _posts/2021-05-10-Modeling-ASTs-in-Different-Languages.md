---
layout: post
title: "Modeling an AST in Different Languages"
---

Abstract Syntax Trees (ASTs) are an interesting data structure because their representation varies widely across type systems. While I'm writing about ASTs specifically here, in this post an AST is essentially a proxy for any sort of polymorphic tree. Modeling a polymorphic tree structure is one thing, but traversing said tree often requires a set of mutually recursive functions (or a single pattern matching one) which is also interesting.

Last week I implemented a super simple expression AST in a few different languages: C, C++, Elixir, Haskell, Java, Python, Rust, Scala, and Zig. You can find the repo here: <https://github.com/mkhan45/expr_eval>.

___

In general, the implementation was more idiomatic in functional languages; the following Haskell explains itself to any Haskell novice, but it's probably impenetrable to anyone only familiar with imperative languages.

```hs
data Op = Add | Sub | Mul | Div

data Expr
    = Atomic Int
    | Binary Op Expr Expr

eval :: Expr -> Int
eval (Atomic v) = v
eval (Binary Add lhs rhs) = (eval lhs) + (eval rhs)
eval (Binary Sub lhs rhs) = (eval lhs) - (eval rhs)
eval (Binary Mul lhs rhs) = (eval lhs) * (eval rhs)
eval (Binary Div lhs rhs) = (eval lhs) `div` (eval rhs)

main = do
    print $ eval (Binary Add (Atomic 3) (Binary Mul (Atomic 2) (Atomic 5)))
```

On the other hand, I would assume the following Scala to be pretty understandable to any developer with a bit of OOP knowledge. Despite the syntactical differences, it's almost semantically identical to the Haskell.

```scala
abstract class BinOp
case object Add extends BinOp
case object Sub extends BinOp
case object Mul extends BinOp
case object Div extends BinOp

abstract class Expr
case class AtomicExpr(value: Int) extends Expr
case class BinaryExpr(op: BinOp, lhs: Expr, rhs: Expr) extends Expr

object Main {
    def eval(expr: Expr): Int = {
        expr match {
            case AtomicExpr(value) => value

            case BinaryExpr(op, lhs, rhs) =>
                op match {
                    case Add => eval(lhs) + eval(rhs)
                    case Sub => eval(lhs) - eval(rhs)
                    case Mul => eval(lhs) * eval(rhs)
                    case Div => eval(lhs) / eval(rhs)
                }
        }
    }

    def main(args: Array[String]) = {
        println(eval(BinaryExpr(Add, AtomicExpr(1), AtomicExpr(2))))
    }
}
```

Next, we'll take a look at the Java version, which emulates sum types using abstract classes. I've cut the constructors out of the snippet to remove some noise.

```java
enum BinOp { Add, Sub, Mul, Div }

public abstract class Expr {
    abstract int eval();

    static class AtomicExpr extends Expr {
        int val;

        int eval() {
            return val;
        }
    }

    static class BinaryExpr extends Expr {
        BinOp op;
        Expr lhs;
        Expr rhs;

        int eval() {
            return switch (op) {
                case Add -> lhs.eval() + rhs.eval();
                case Sub -> lhs.eval() - rhs.eval();
                case Mul -> lhs.eval() * rhs.eval();
                case Div -> lhs.eval() / rhs.eval();
            };
        }
    }

    public static void main(String[] args) {
        Expr e = new BinaryExpr(BinOp.Mul, new AtomicExpr(5), new AtomicExpr(10));
        System.out.println(e.eval());
    }
}
```

Looking at the Java makes it clear why Scala's implementation of sum types uses abstract classes. It carries the usual verbosity of Java but it's relatively easy to work with. Adding a new class and constructor etc. for every new type of node gets old really fast though. 

[The Rust version](https://github.com/mkhan45/expr_eval/blob/main/rust/expr.rs) of the expression evaluator is almost the same as Scala, so I won't include the code here. Because sum types are first class, declaring and traversing the tree are both pretty ergonomic. However, because of the lack of a garbage collector, dealing with references is a lot more verbose and adds a lot of syntactical noise due to either lifetimes or boxes. It's fast though, so let's look at C, C++, and Zig next.

I'll start with C. The implementation is a lot longer than previous ones, if not necessarily harder to write, so I've cut out some of the less relevant parts in the following snippet. I also reformatted the enums definitions to one line. The full file is here: <https://github.com/mkhan45/expr_eval/blob/main/c/expr.c>.

```c
typedef enum expr_ty { Atomic, Binary } expr_ty;

typedef enum bin_op { Add, Sub, Mul, Div } bin_op;

typedef struct atomic_expr {
    int val;
} atomic_expr_t;

typedef struct binary_expr {
    enum bin_op op;
    struct expr* lhs;
    struct expr* rhs;
} binary_expr_t;

typedef struct expr {
    expr_ty ty;
    union {
        atomic_expr_t atomic;
        binary_expr_t* binary;
    };
} expr_t;

int eval_binary_expr(const binary_expr_t* expr) {
    switch (expr->op) {
        case Add: return eval_expr(expr->lhs) + eval_expr(expr->rhs);
        case Sub: return eval_expr(expr->lhs) - eval_expr(expr->rhs);
        case Mul: return eval_expr(expr->lhs) * eval_expr(expr->rhs);
        case Div: return eval_expr(expr->lhs) / eval_expr(expr->rhs);
    }
}

int eval_expr(const expr_t* expr) {
    switch (expr->ty) {
        case Atomic: return expr->atomic.val;
        case Binary: return eval_binary_expr(expr->binary);
    }
}

int main() {
    expr_t* expr = new_binary(Add, new_atomic(12), new_binary(Mul, new_atomic(3), new_atomic(5)));
    printf("%d\n", eval_expr(expr));
    free_expr(expr);
}
```

This code uses the tagged union pattern to emulate proper sum types. It's pretty easy to reason about although you have to be sure to manage your memory properly. Being able to access the union's data without pattern matching over it is a double edged blade; bad things will happen if you mess it up. In practice this is one of the least impactful safety issues with C.

The Zig version is almost the same except that Zig has some language features to make tagged unions more ergonomic. This makes it visually pretty similar to the Rust version even if it is semantically the same as the C version.

```java
const std = @import("std");

const BinOp = enum { add, sub, mul, div };

const ExprTy = enum { atomic, binary };

const BinaryExpr = struct {
    op: BinOp,
    lhs: *const Expr,
    rhs: *const Expr,
};

const Expr = union(ExprTy) {
    atomic: isize,
    binary: BinaryExpr,
};

fn eval(expr: *const Expr) isize {
    return switch (expr.*) {
        ExprTy.atomic => |v| v,
        ExprTy.binary => |b| {
            const lhs = eval(b.lhs);
            const rhs = eval(b.rhs);
            return switch (b.op) {
                BinOp.add => lhs + rhs,
                BinOp.sub => lhs - rhs,
                BinOp.mul => lhs * rhs,
                BinOp.div => @divFloor(lhs, rhs),
            };
        }
    };
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const expr = Expr { 
        .binary = BinaryExpr { 
            .op = BinOp.add,
            .lhs = &Expr { 
                .binary = BinaryExpr {
                    .op = BinOp.mul,
                    .lhs = &Expr { .atomic = 5 },
                    .rhs = &Expr { .atomic = 3 }
                }
            },
            .rhs = &Expr { .atomic = 2 },
        }
    };

    try stdout.print("{d}\n", .{eval(&expr)});
}
```

This is my first Zig program after Hello World and I was surprised at how much I liked it. Defining the actual polymorphic tree structure still requires multiple `struct` definitions, which makes it kind of clunky for more complicated ASTs, but traversing the tree is quite nice.

Finally, we'll look at C++. C++ being what it is, there are three ways to do this and I'm not sure which would be considered most idiomatic.

The first way is to model it after C using tagged unions. This method has most of the drawbacks of the C implementation, but because of smart pointers it can be significantly safer. IMO, this is the best way to do it in C++.

The second way is to model it after Java using abstract classes. Well C++ doesn't actually have abstract classes but it does have virtual methods and inheritance, so it's close enough. This is how the `clang` compiler models its AST.

```cpp
enum BinOp { Add, Sub, Mul, Div };

struct OhNo {};

class Expr {
    public:
        virtual int eval() const { throw OhNo{}; };
        virtual ~Expr() = default;
};

class AtomicExpr : public Expr {
    public:
        int val;

        AtomicExpr(const int val) { this->val = val; }
        int eval() const override {
            return this->val;
        }
};

class BinaryExpr : public Expr {
    public:
        BinOp op;
        std::unique_ptr<Expr> lhs;
        std::unique_ptr<Expr> rhs;

        BinaryExpr(const BinOp op, Expr* lhs, Expr* rhs) {
            this->op = op;
            this->lhs = std::unique_ptr<Expr>(lhs);
            this->rhs = std::unique_ptr<Expr>(rhs);
        }

        int eval() const override {
            switch (this->op) {
                case Add: return lhs->eval() + rhs->eval();
                case Sub: return lhs->eval() - rhs->eval();
                case Mul: return lhs->eval() * rhs->eval();
                case Div: return lhs->eval() / rhs->eval();
                default: throw "Unimplemented";
            }
        }
};

int main() {
    const Expr* e = new BinaryExpr(Mul, new AtomicExpr(5), new BinaryExpr(Add, new AtomicExpr(3), new AtomicExpr(1)));
    std::cout << e->eval() << std::endl;
    delete e;
}
```

This code is semantically the same as Java. It's a bit verbose but no worse than Rust. However, it's filled with pitfalls. 

You might've noticed the `throw OhNo {}` in the default implementation of `eval()`. Because C++ doesn't have abstract classes, the base `Expr` class might be instantiated, which is illegal. One way to partially fix this would be to make `AtomicExpr` the base class but that's not terribly intuitive. Another pitfall here is that method dispatch is somewhat tricky in C++. Overridden methods have to be called through a pointer for the override to actually work, so it's easy to write code which mistakenly calls `Expr::eval` when `BinaryExpr::eval` or `AtomicExpr::eval` should be called instead.

The final way to implement this program in C++ is using `std::variant`. [`std::variant` is a bad time](https://bitbashing.io/std-visit.html). Here's what it looks like:

```cpp
enum BinOp { Add, Sub, Mul, Div };

struct AtomicExpr;
struct BinaryExpr;

using Expr = std::variant<AtomicExpr, BinaryExpr>;

struct AtomicExpr { 
    int val; 
    AtomicExpr(int val) : val(val) {}
};

struct BinaryExpr { 
    BinOp op;
    std::shared_ptr<Expr> lhs;
    std::shared_ptr<Expr> rhs;

    BinaryExpr(BinOp op, Expr lhs, Expr rhs) {
        this->op = op;
        this->lhs = std::make_shared<Expr>(lhs);
        this->rhs = std::make_shared<Expr>(rhs);
    }
};

int eval(const Expr& e);

struct EvalVisitor {
    int result;

    void operator()(const AtomicExpr& e) {
        result = e.val;
    }

    void operator()(const BinaryExpr& e) {
        int lhs = eval(*e.lhs);
        int rhs = eval(*e.rhs);

        switch (e.op) {
            case Add: result = lhs + rhs; break;
            case Sub: result = lhs - rhs; break;
            case Mul: result = lhs * rhs; break;
            case Div: result = lhs / rhs; break;
        }
    }
};

int eval(const Expr& e) {
    auto visitor = EvalVisitor { 0 };
    std::visit(visitor, e);
    return visitor.result;
}

int main() {
    Expr e = BinaryExpr(Add, AtomicExpr(3), BinaryExpr(Mul, AtomicExpr(5), AtomicExpr(8)));
    std::cout << eval(e) << std::endl;
}
```

Constructing the actual variant structure is pretty easy. Traversing it with `std::visit` is not. Instead of using a Visitor struct, I could've used templates and dynamic closures, but, either way, sum types are clearly not C++'s strength. The error messages when using `std::variant` are difficult to understand.

___

Overall, there were three main categories:

1. First class sum types
    - This includes the functional languages, Haskell, Scala, and Rust.
    - This way is definitely the most ergonomic.
2. Abstract Classes / Polymorphism
    - This is primarily Java, though maybe Scala counts to some extent. There's also C++, except that the C++ version using virtual methods was less ergonomic than simple tagged unions.
3. Tagged unions
    - This is the approach for C and Zig, and my preferred approach with C++ too.

Then there's `std::variant`, which tries to be as nice as first class some types but fails miserably.

Notably, I didn't write about my Python or Elixir implementation. Because they're dynamically typed, it's pretty easy to model a polymorphic tree. The issue is that there's no compile time safety, but that's no different from normal with dynamic languages.

I think it's clear that functional-inspired languages with first class sum types are by far better for modeling ASTs. However, both Scala and Rust have implemented proper algebraic data types into otherwise mostly imperative styles; the only other functional language feature that sum types kind of necessitate is pattern matching, which also fits fairly well into imperative languages. I expect first class sum types in any modern language nowadays. With that said, Zig's alternative works really well. It fits Zig's goal of not hiding implementation details and discards only minimal safety guarantees in order to do so.
