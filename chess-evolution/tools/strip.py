# Prints a comment-stripped copy of a Luau file (same code, fewer bytes) for pasting into Studio.
import sys,re
for line in open(sys.argv[1]):
    s=line.rstrip('\n')
    t=s.strip()
    if t.startswith('--') and not t.startswith('--!'):
        continue
    if not t:
        continue
    # drop trailing comments that are safe (no quotes/backticks on the line)
    if ' -- ' in s and '"' not in s and '`' not in s and "'" not in s:
        s=s.split(' -- ')[0].rstrip()
    print(s)
