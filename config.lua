
-- https://luacheck.readthedocs.io/en/stable/warnings.html
ignore = {"111", -- Setting an undefined global variable.
          "113", -- Accessing an undefined global variable.
          "631", -- Line is too long.
          "611", -- A line consists of nothing but whitespace.
          "612", -- A line contains trailing whitespace.
          "614"} -- Trailing whitespace in a comment.
