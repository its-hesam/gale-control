local input, output = arg[1], arg[2]
if not input or not input:match('^/tmp/gale%-format%-[%w]+/input$') or output ~= input:gsub('/input$', '/output') then os.exit(1) end
local ok = pcall(function()
 local f=assert(io.open(input,'rb'));local text=f:read('*a');f:close();assert(#text<=1048576)
 local yaml=require('lyaml');local root=yaml.load(text);assert(type(root)=='table' and type(root.proxies)=='table')
 local visited, nodes, bytes = {}, 0, 0
 local function quoted(s) return '"'..s:gsub('[%z\1-\31\\"]',function(c) if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' else return string.format('\\u%04x',string.byte(c)) end end)..'"' end
 local encode
 encode=function(v,depth)
  nodes=nodes+1;assert(nodes<=20000 and depth<=32)
  local t=type(v);local result
  if v==yaml.null or v==nil then result='null'
  elseif t=='string' then result=quoted(v)
  elseif t=='boolean' then result=v and 'true' or 'false'
  elseif t=='number' then assert(v==v and v~=math.huge and v~=-math.huge);result=tostring(v)
  elseif t=='table' then
   assert(not visited[v]);visited[v]=true;local list,n=true,0;for k in pairs(v) do n=n+1;if type(k)~='number' or k%1~=0 or k<1 then list=false end end
   if list and n~=#v then list=false end
   local fields={};if list then for i=1,n do fields[#fields+1]=encode(v[i],depth+1) end;result='['..table.concat(fields,',')..']'
   else for k,x in pairs(v) do assert(type(k)=='string');fields[#fields+1]=quoted(k)..':'..encode(x,depth+1) end;result='{'..table.concat(fields,',')..'}' end
   visited[v]=nil
  else error('unsupported YAML value') end
  bytes=bytes+#result;assert(bytes<=8388608);return result
 end
 local json=encode(root,0);assert(#json<=2097152);local f=assert(io.open(output,'wb'));f:write(json);f:close()
end)
if not ok then os.exit(1) end
