import sys

def check_brackets(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading file: {e}")
        return

    stack = []
    lines = content.split('\n')
    for i, line in enumerate(lines):
        for j, char in enumerate(line):
            if char in '({[':
                stack.append((char, i + 1, j + 1))
            elif char in ')}]':
                if not stack:
                    print(f"Unexpected closing {char} at line {i + 1}, col {j + 1}")
                    continue
                opening, line_num, col_num = stack.pop()
                if (opening == '(' and char != ')') or \
                   (opening == '{' and char != '}') or \
                   (opening == '[' and char != ']'):
                    print(f"Mismatched {char} at line {i + 1}, col {j + 1} (matches {opening} at line {line_num}, col {col_num})")
    
    if stack:
        print(f"Unclosed brackets: {len(stack)}")
        for char, line_num, col_num in stack[-10:]: # Show last 10
            print(f"  {char} at line {line_num}, col {col_num}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python check_brackets.py <filepath>")
    else:
        check_brackets(sys.argv[1])
