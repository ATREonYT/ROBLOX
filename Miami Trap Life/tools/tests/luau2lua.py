# Crude Luau -> Lua 5.4 for unit-testing pure modules (enough for our Rules/Config files).
import re, sys
def split_top(s):
    parts=[];depth=0;cur=''
    for ch in s:
        if ch in '({[<': depth+=1
        if ch in ')}]>': depth-=1
        if ch==',' and depth==0: parts.append(cur);cur=''
        else: cur+=ch
    if cur.strip(): parts.append(cur)
    return parts
def fix_sig(line):
    m=re.search(r'function\s*([\w.:]*)\s*\(',line)
    if not m: return line
    i=m.end();depth=1;j=i
    while j<len(line) and depth:
        if line[j]=='(': depth+=1
        elif line[j]==')': depth-=1
        j+=1
    params=line[i:j-1]
    names=[p.split(':')[0].strip() for p in split_top(params)]
    rest=line[j:]
    rest=re.sub(r'^\s*:\s*.*$','',rest) if not re.search(r'\bend\b|\breturn\b',rest) else re.sub(r'^\s*:\s*[^\s]+','',rest)
    return line[:i]+', '.join(n for n in names if n)+')'+rest
def ifexpr(line):
    # if A then B else C  (single, non-nested) inside an expression
    m=re.search(r'(=|\(|,|return|\.\.)\s*if (.+?) then (.+?) else ([^,)]+)',line)
    if m and not line.strip().startswith('if'):
        a,b,c=m.group(2),m.group(3),m.group(4)
        return line[:m.start()]+m.group(1)+f' __ifx({a}, function() return {b} end, function() return {c} end)'+line[m.end():]
    return line
def conv(src):
    out=[]
    for line in src.split('\n'):
        if line.startswith('--!') or line.startswith('export type'): continue
        line=fix_sig(line)
        line=re.sub(r'local (\w+)\s*:\s*[^=]+=', r'local \1 =', line)
        line=re.sub(r'::\s*[\w?.]+','',line)
        m=re.match(r'^(\s*)([\w.\[\]"]+) (\+|-|\*|/|\.\.)= (.+)$',line)
        if m: line=f'{m.group(1)}{m.group(2)} = {m.group(2)} {m.group(3)} ({m.group(4)})'
        line=ifexpr(line)
        line=re.sub(r'\bin ((?!pairs|ipairs)[^\n]+?) do\b', r'in __iter(\1) do', line)
        out.append(line)
    return '\n'.join(out)
if __name__=='__main__':
    print(conv(open(sys.argv[1]).read()))
