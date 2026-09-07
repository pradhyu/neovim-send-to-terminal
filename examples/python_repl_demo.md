# 🐍 Python & IPython REPL Interactive Demo

This file demonstrates running Python code and tutorials with REPL prompt stripping and indentation preservation.

---

## 1. Python Standard REPL Prompts (`>>> ` and `... `)

Place cursor on the block below and press `<leader>sb` (or `<leader>ss` on individual lines):

```python
>>> def calculate_fibonacci(n):
...     a, b = 0, 1
...     result = []
...     for _ in range(n):
...         result.append(a)
...         a, b = b, a + b
...     return result
>>> calculate_fibonacci(8)
```

*Expected behavior:* The prompts `>>> ` and `... ` are stripped, while the 4-space syntactic indentation of the Python code is strictly preserved!

---

## 2. IPython Prompts (`In [1]: `)

```python
In [1]: import json
In [2]: data = {"plugin": "neovim-send-to-terminal", "stars": 9999}
In [3]: print(json.dumps(data, indent=2))
```

---

## 3. List Comprehensions & Multi-Line Data

```python
numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
squares = [x**2 for x in numbers if x % 2 == 0]
print("Even squares:", squares)
```
