"""Lua 5.3 mock tests. Not an IL2CPP/iOS device test."""
from pathlib import Path
from lupa.lua53 import LuaRuntime
root=Path(__file__).parent
source=(root/'ResourceOperation.lua').read_text()
def run(id=0,amount=0,setup=''):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
      balances={[1]=25,[2]=30,[3]=40}; calls=0; lazyLoads=0
      SaveRootData={UserData={Property={}}}
      ECheckerboardType={Main=10}; FunctionSource={GM='gm'}
      ModuleManager={PropertySystem={
        GetPropertyCount=function(self,id) return balances[id] end,
        CheckChangeData=function(self,id,n,anim,board,source)
          assert(anim==nil and board==10 and source=='gm')
          calls=calls+1; balances[id]=balances[id]+n
        end
      }}
      setmetatable(ModuleManager,{__index=function() lazyLoads=lazyLoads+1; error('unexpected lazy load') end})
    ''')
    lua.execute(setup)
    s=lua.execute(source.replace('__RESOURCE_ID__',str(id)).replace('__RESOURCE_AMOUNT__',str(amount)))
    return s,lua
s,l=run();assert s.startswith('READY|') and l.globals().calls==0
for i in (1,2,3):
    s,l=run(i,10);assert s.startswith('OK|') and l.globals().calls==1
    assert l.globals().balances[i]==({1:25,2:30,3:40}[i]+10)
s,l=run(1,10,'ModuleManager.PropertySystem.CheckChangeData=function() calls=calls+1 end')
assert s.startswith('UNCHANGED|') and l.globals().calls==1
s,l=run(1,10,'ModuleManager.PropertySystem=nil');assert s.startswith('WAIT|') and l.globals().lazyLoads==0
s,l=run(1,10,'SaveRootData.UserData=nil');assert s.startswith('WAIT|') and l.globals().calls==0
for i,n in [(4,10),(1,0),(1,101),(1,1.5)]:
    try:run(i,n)
    except Exception:pass
    else:raise AssertionError((i,n))
native=(root/'PetsRuntime.c').read_text()+(root/'PetsMenu.m').read_text()
for forbidden in ['NSBundle','bundleIdentifier','CFBundle','LC_UUID','target_uuid','uuid_ok','memcmp(']:
    assert forbidden not in native,forbidden
assert 'il2cpp_runtime_invoke' in native and 'il2cpp_class_get_methods' in native
assert 'GM.AddItem' not in source
print('PASS: three resources, argument order, readiness without lazy loading, unchanged, input bounds; no app identity/version/UUID gates in new source (mock/source checks only)')
