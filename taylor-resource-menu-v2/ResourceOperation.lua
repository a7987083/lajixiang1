-- Substituted by native code with validated integer IDs and quantities only.
local id, amount = __RESOURCE_ID__, __RESOURCE_AMOUNT__
local p, gm, data = PropertySystem, GM, SaveRootData
if type(p) ~= 'table' or type(p.GetPropertyCount) ~= 'function'
   or type(p.CheckChangeData) ~= 'function' or type(gm) ~= 'table'
   or type(gm.AddItem) ~= 'function' or type(data) ~= 'table'
   or type(data.UserData) ~= 'table' or type(data.UserData.Property) ~= 'table'
then return 'WAIT|游戏资源尚未初始化' end
if AntiCheatingHelper and AntiCheatingHelper.IsHaveCheat
   and AntiCheatingHelper:IsHaveCheat() then
   return 'BLOCKED|游戏已标记数据异常，停止资源操作'
end
if id == 0 then
    return string.format('READY|钻石 %s  体力 %s  星星 %s',
        tostring(p:GetPropertyCount(1)), tostring(p:GetPropertyCount(2)),
        tostring(p:GetPropertyCount(3)))
end
assert(id == 1 or id == 2 or id == 3, '不支持的资源')
assert(amount >= 1 and amount <= 100 and amount == math.floor(amount), '数量须为1至100整数')
local before = p:GetPropertyCount(id)
assert(type(before) == 'number', '无法读取原余额')
-- Use the existing game route. Never disable validation, change flags or force cloud sync.
gm.AddItem(id, amount)
local after = p:GetPropertyCount(id)
local delta = after - before
if AntiCheatingHelper and AntiCheatingHelper.IsHaveCheat
   and AntiCheatingHelper:IsHaveCheat() then
    return string.format('BLOCKED|游戏拒绝变更：%s → %s', before, after)
end
if delta == amount then
    return string.format('OK|%s → %s（增加 %s，本地值已确认）', before, after, delta)
end
return string.format('UNCHANGED|%s → %s（实际增加 %s，预期 %s）', before, after, delta, amount)
