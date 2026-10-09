#!/usr/bin/env python3
import sys
import os

def check_file(path):
    with open(path, 'r') as f:
        content = f.read()
    
    # Simple brace counter (ignoring strings and comments for now)
    # Just to provide something as requested
    stack = []
    lines = content.split('\n')
    for i, line in enumerate(lines):
        for char in line:
            if char == '{':
                stack.append((i+1, '{'))
            elif char == '}':
                if not stack or stack[-1][1] != '{':
                    print(f"Error in {path}:{i+1}: Unmatched '}}'")
                    return False
                stack.pop()
    if stack:
        print(f"Error in {path}: Unclosed '{{' starting at line {stack[-1][0]}")
        return False
    return True

all_good = True
for f in sys.argv[1:]:
    if not check_file(f):
        all_good = False

if not all_good:
    sys.exit(1)
else:
    print("All QML files have matched braces.")
    sys.exit(0)
