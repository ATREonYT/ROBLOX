--!strict
local Format = {}
local suffixes={'','K','M','B','T','Qa','Qi'}
function Format.compact(value: number): string
 assert(value == value and math.abs(value) < math.huge, 'Expected finite number')
 local sign=if value<0 then '-' else ''
 local n=math.abs(value)
 local group=1
 while n>=1000 and group<#suffixes do n/=1000; group+=1 end
 if group==1 then return sign..tostring(math.floor(n)) end
 n=math.floor(n*10+0.5)/10
 if n>=1000 and group<#suffixes then n/=1000;group+=1 end
 local label=string.format('%.1f',n):gsub('%.0$','')
 return sign..label..suffixes[group]
end
return Format
