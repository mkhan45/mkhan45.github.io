One of the most important aspects of a programming language is its complexity. Languages that are too simple are often thought of as unexpressive and long winded, while languages that are too complicated are hard to learn and result in incomprehensive codebases. As such, programming language designers have to take a stance on complexity eventually. For example, simplicity is arguably Go's most important feature, whereas C++ seems to add pretty much any language feature that becomes popular. 

The perceived complexity of a programming language isn't just a function of how many language features it has or how many ways there are to accomplish the same task. In both of these metrics, Rust is close to C++, but language complexity isn't one of the main popular criticisms of Rust. While Rust is commonly criticized for being difficult to learn and being generally slow to write ( both side effects of its memory management model), most common C++ criticisms have to do with either having too many features or a specific feature which makes the program less clear. Python, like Rust, is a very featureful language which is not commonly thought of as complicated. Part of this is because of its target use case; low level programmers have much more reason to care about simplicity than most Python developers. However, regardless of the community, Python also gets less criticism for its complexity than C++ because of its lanuage design.

Rust's and Python's complexity are less harmful than C++'s because new features are much more carefully implemented so that even when there's multiple ways to accomplish the same task, one of these ways is very clearly better. Rust especially forces developers towards a uniform path with its ownership model.

___

Take the following problem from [Exercism](https://exercism.io):
> An anagram is a rearrangement of letters to form a new word. Given a word and a list of candidates, select the sublist of anagrams of the given word.

> Given "listen" and a list of candidates like "enlists" "google" "inlets" "banana" the program should return a list containing "inlets".

The newest C++ solution (only the relevant method and a helper) is:
```c++
vector<string> anagram::matches (vector<string> candidates)
{
    vector<string> res;

    for (auto& candidate: candidates)
    {
        string candidate_lower = candidate;
        std::transform (candidate.begin(), candidate.end(), candidate_lower.begin(), ::tolower);
        if(match(candidate_lower)) {
            res.push_back(candidate);
        }
    }

    return res;
}
bool anagram::match (std::string word){
    return is_permutation(input.begin(),input.end(),word.begin()) && word.size() == length && word != input;
}
```
It's fairly sane IMO, and even if you're new to C++ it's pretty understandable.

Here's the top rated solution's relevant method (`is_anagram` is pretty much the same as `anagram::match` above)
```c++
std::vector<std::string> matches(std::vector<std::string> candidates) {
    std::vector<std::string> matched;
    std::copy_if(std::begin(candidates), std::end(candidates), std::back_inserter(matched), [this](auto candidate) { 
            std::string loweredCandidate;
            std::transform(std::begin(candidate), std::end(candidate), std::back_inserter(loweredCandidate), ::tolower);
            return is_anagram(this->m_str, loweredCandidate); 
    });
    return matched;
}
```
It's short, concise, and incomprehensible. I'm fairly certain that the author wouldn't write this in an actual codebase though. As always, it's pretty easy to understand what's going on once you understand the pieces, but C++'s awkward iterator and lambda implementation means that most C++ developers avoid them and consequently wouldn't be able to understand this code very quickly. Many of the C++ solutions to this problem used iterators only for `std::is_permutation`, and hardly any used anonymous functons.

The top rated Rust solution to the same problem is:
```rust
pub fn anagrams_for<'a>(word: &str, candidates: &'a [&'a str]) -> Vec<&'a str> {
  let word = word.to_lowercase();
  let sorted_word = sort(&word);
  candidates
    .iter()
    .cloned()
    .filter(|&candidate| {
      let can = candidate.to_lowercase();
      sort(&can) == sorted_word && can != word
    })
    .collect::<Vec<&'a str>>()
}
```

This solution also uses iterators/anonymous functions, and so does every other solution of the five or six I clicked on. Iterators and closures are pretty ergonomic in Rust; they're easy to read, make dealing with the borrow checker easier sometimes, and on top of that iterators are generally faster than normal for loops. 

The top rated Python solution for is_anagram (comments removed) is:
```python
def detect_anagrams(original, candidates):
	return [candidate for candidate in candidates if is_an_anagram(original, candidate)]

def is_an_anagram(original, candidate):
	original = original.lower()
	candidate = candidate.lower()
	return original != candidate and sorted(original) == sorted(candidate)
```

Pretty much every Python solution uses the same process here. Of course, Python hides most of the complexity.

___

These `is_anagram` solutions demonstrate some important aspects of each language. While C++ has a short, concise way to solve the problem, hardly anyone uses the features required to understand it, namely iterators. For that reason, most C++ devs will opt to solve is_anagram primarily using normal for loops. 

On the other hand, Rust also has iterators, and almost everyone used them to solve the problem. Python has even more ways to sove the problem, but almost everyone just uses a list comprehension.

On the other side of the spectrum, there's languages like C and Go, which emphasize simplicity over anything else. Go only has one way to solve the problem; it would take intentional obfuscation to make a solution that's opaque to other Go developers.

What makes a programming language too complicated isn't the number of features it has, it's the number of features the language has but people don't use.

> Within C++, there is a much smaller and cleaner language struggling to get out. – Bjarne Stroustrup, creator of C++
