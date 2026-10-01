local ss=game:GetService("ServerStorage")
local old=ss:FindFirstChild("ClaudeExport") if old then old:Destroy() end
local svcs={"ServerScriptService","ReplicatedStorage","ReplicatedFirst","StarterGui","StarterPlayer","StarterPack","ServerStorage","Lighting","SoundService","Teams","TextChatService","Workspace"}
local kinds={"Folder","Model","Configuration","ValueBase","RemoteEvent","RemoteFunction","UnreliableRemoteEvent","BindableEvent","BindableFunction","Tool","LayerCollector","ProximityPrompt","ClickDetector","Sound"}
local out,tree,n={},{},0
for _,name in ipairs(svcs) do
 local ok,svc=pcall(function() return game:GetService(name) end)
 if ok and svc then
  for _,d in ipairs(svc:GetDescendants()) do
   if d:IsA("LuaSourceContainer") then
    n=n+1
    local okS,src=pcall(function() return d.Source end)
    local rc=""
    if d:IsA("Script") then local okR,r=pcall(function() return d.RunContext.Name end) if okR and r~="Legacy" then rc=", RunContext="..r end end
    table.insert(out,"\n\n===== "..d:GetFullName().." ("..d.ClassName..rc..") =====\n"..(okS and src or "[could not read]"))
   elseif #tree<4000 then
    for _,k in ipairs(kinds) do if d:IsA(k) then table.insert(tree,d:GetFullName().." ("..d.ClassName..")") break end end
   end
  end
 end
end
local text="HOOD EXPORT: "..n.." scripts"..table.concat(out).."\n\n===== OBJECT TREE =====\n"..table.concat(tree,"\n")
local eq="==" while text:find("]"..eq.."]",1,true) do eq=eq.."=" end
local folder=Instance.new("Folder") folder.Name="ClaudeExport" folder.Parent=ss
local parts=0
for i=1,#text,150000 do
 parts=parts+1
 local body="--["..eq.."[\n"..text:sub(i,i+149999).."\n]"..eq.."]"
 local m=Instance.new("ModuleScript") m.Name="Part"..parts
 local okW=pcall(function() m.Source=body end)
 m.Parent=folder
 if not okW then pcall(function() game:GetService("ScriptEditorService"):UpdateSourceAsync(m,function() return body end) end) end
end
game:GetService("Selection"):Set({folder})
print("Claude export done: "..n.." scripts in "..parts.." part(s) at ServerStorage > ClaudeExport")
