#!/usr/bin/env python3
"""Reject backend UI dependencies while retaining legacy argv recognition data."""
import ast
from pathlib import Path
import re
import sys

# Keep the existing lexical guard outside the one structural compatibility case.
ROOT = Path(__file__).resolve().parents[2]
UI_REFERENCE = re.compile(r'\brofi\b|haku_pick\.sh|picker open')


def check_text(path, source):
    """Mask only the launcher name in an exact legacy argv equality comparison."""
    comparisons = {}
    if path.endswith('.py'):
        for node in ast.walk(ast.parse(source)):
            if (not isinstance(node, ast.Compare) or len(node.ops) != 1
                    or not isinstance(node.ops[0], ast.Eq)
                    or not isinstance(node.left, ast.Subscript)
                    or not isinstance(node.left.slice, ast.Constant) or node.left.slice.value != 'argv'):
                continue
            right = node.comparators[0]
            if (not isinstance(right, ast.List) or len(right.elts) != 3
                    or not all(isinstance(item, ast.Constant) for item in right.elts)
                    or [item.value for item in right.elts] != ['rofi', '-show', 'drun']):
                continue
            launcher = right.elts[0]
            if launcher.lineno == launcher.end_lineno:
                comparisons.setdefault(launcher.lineno, []).append((launcher.col_offset, launcher.end_col_offset))
    errors = []
    for number, line in enumerate(source.splitlines(), 1):
        # AST columns count UTF-8 bytes, including labels preceding the literal.
        data = bytearray(line.encode())
        for start, end in comparisons.get(number, []):
            data[start:end] = b' ' * (end - start)
        if UI_REFERENCE.search(data.decode()):
            errors.append(f'{path}:{number}: UI/picker dependency in backend')
    return errors


def main():
    """Check backend source files without importing or executing their code."""
    errors = []
    for path in sorted((ROOT / 'src/core/backend').rglob('*')):
        if path.suffix in ('.py', '.sh') and path.is_file():
            errors.extend(check_text(str(path.relative_to(ROOT)), path.read_text()))
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print('Backend UI boundary: PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
