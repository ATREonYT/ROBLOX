# Crude Luau block/bracket balance check (catches missing/extra `end`, unclosed brackets):  python3 tools/tests/balance.py $(find src -name "*.lua")
import re, sys
# crude Luau block/bracket balance checker: strips strings & comments, then counts block keywords.
def strip(src):
    out=[];i=0;n=len(src)
    while i<n:
        c=src[i]
        if src.startswith('--',i):
            m=re.match(r'--\[(=*)\[',src[i:])
            if m:
                end=src.find(']'+m.group(1)+']',i)
                out.append('\n'*src[i:end].count('\n')); i=end+len(m.group(1))+2; continue
            j=src.find('\n',i); i=n if j<0 else j; continue
        m=re.match(r'\[(=*)\[',src[i:])
        if m:
            end=src.find(']'+m.group(1)+']',i)
            out.append(' S '+'\n'*src[i:end].count('\n')); i=end+len(m.group(1))+2; continue
        if c in '"\'`':
            j=i+1
            while j<n and src[j]!=c:
                if src[j]=='\\': j+=1
                if src[j]=='\n' and c!='`': print("  unterminated string line",src[:i].count('\n')+1)
                j+=1
            out.append(' S '); i=j+1; continue
        out.append(c); i+=1
    return ''.join(out)
def check(path):
    s=strip(open(path,encoding='utf-8').read())
    stack=[];errs=[]
    for ln,line in enumerate(s.split('\n'),1):
        for tok in re.findall(r'[A-Za-z_][A-Za-z0-9_]*|[(){}\[\]]',line):
            if tok=='then':
                if stack and stack[-1][0]=='ifexpr': stack.pop()
                continue
            if tok in('function','do','repeat','(', '{','['):
                if tok=='do' and stack and stack[-1][0]=='loop': stack[-1]=('do',ln); continue
                stack.append((tok,ln))
            elif tok in('while','for'):
                stack.append(('loop',ln))
            elif tok=='if':
                # if-expression (no matching end) when preceded by = ( , return etc. heuristic: check following 'then' ... 'else' on same expression; treat 'if' as statement only at line start
                first=re.match(r'\s*([A-Za-z_]+)',line)
                stack.append(('if' if first and first.group(1)=='if' and line.strip().startswith('if') and line.count(' if ')==0 or (first and first.group(1)=='if') else 'ifexpr',ln))
            elif tok=='end':
                # pop until a block opener
                if not stack: errs.append(f'{ln}: extra end'); continue
                t,l=stack.pop()
                if t in('(', '{','['): errs.append(f'{ln}: end closes {t} from {l}')
            elif tok=='until':
                if not stack or stack[-1][0]!='repeat': errs.append(f'{ln}: bad until')
                else: stack.pop()
            elif tok in(')','}',']'):
                o={')':'(','}':'{',']':'['}[tok]
                if not stack or stack[-1][0]!=o: errs.append(f'{ln}: unmatched {tok} (top {stack[-1] if stack else None})'); 
                else: stack.pop()
    if stack: errs.append(f'unclosed: {stack[-5:]}')
    return errs
for p in sys.argv[1:]:
    e=check(p)
    if e: print(p); [print('  ',x) for x in e[:8]]
