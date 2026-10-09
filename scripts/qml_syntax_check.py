#!/usr/bin/env python3
import sys

def check_file(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading {path}: {e}")
        return False

    stack = []
    i = 0
    line_num = 1
    in_string = False
    string_char = ''
    in_single_comment = False
    in_multi_comment = False
    in_template = False

    while i < len(content):
        char = content[i]

        if char == '\n':
            if in_string and not in_template:
                print(f"Error in {path}:{line_num}: Raw newline inside string")
                return False
            if in_single_comment:
                in_single_comment = False
            line_num += 1
            i += 1
            continue

        if in_single_comment:
            i += 1
            continue

        if in_multi_comment:
            if char == '*' and i + 1 < len(content) and content[i+1] == '/':
                in_multi_comment = False
                i += 2
            else:
                i += 1
            continue

        if in_string or in_template:
            if char == '\\':
                i += 2
                continue
            if char == string_char:
                in_string = False
                in_template = False
            i += 1
            continue

        # Not in string or comment
        if char == '/' and i + 1 < len(content):
            if content[i+1] == '/':
                in_single_comment = True
                i += 2
                continue
            elif content[i+1] == '*':
                in_multi_comment = True
                i += 2
                continue

        if char in ('"', "'"):
            in_string = True
            string_char = char
            i += 1
            continue
            
        if char == '`':
            in_template = True
            in_string = True
            string_char = char
            i += 1
            continue

        if char in ('{', '[', '('):
            stack.append((line_num, char))
        elif char in ('}', ']', ')'):
            if not stack:
                print(f"Error in {path}:{line_num}: Unmatched '{char}'")
                return False
            last_line, last_char = stack.pop()
            matches = {'{': '}', '[': ']', '(': ')'}
            if matches[last_char] != char:
                print(f"Error in {path}:{line_num}: Mismatched '{char}', expected '{matches[last_char]}' from line {last_line}")
                return False

        i += 1

    if stack:
        last_line, last_char = stack[-1]
        print(f"Error in {path}: Unclosed '{last_char}' starting at line {last_line}")
        return False
        
    if in_multi_comment:
        print(f"Error in {path}: Unclosed '/*' comment")
        return False

    return True

all_good = True
for f in sys.argv[1:]:
    if not check_file(f):
        all_good = False

if not all_good:
    sys.exit(1)
else:
    print("All QML files are well-formed (brackets/strings).")
    sys.exit(0)
