from pathlib import Path
s=Path('lib/main.dart').read_text(encoding='utf-8')
pairs={'(':')','[':']','{':'}'}
openers=set(pairs.keys())
closers={v:k for k,v in pairs.items()}
stack=[]
for i,ch in enumerate(s):
    if ch in openers:
        stack.append((ch,i))
    elif ch in closers:
        if not stack:
            print('Unmatched closer',ch,'at',i)
            break
        last,idx=stack.pop()
        if closers[ch]!=last:
            print('Mismatched',last,'opened at',idx,'but closer',ch,'at',i)
            break
else:
    if stack:
        print('Unclosed opener',stack[-1][0],'at',stack[-1][1])
    else:
        print('All balanced')
