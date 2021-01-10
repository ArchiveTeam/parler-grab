dofile("table_show.lua")
dofile("urlcode.lua")
local urlparse = require("socket.url")
local http = require("socket.http")

local item_dir = os.getenv('item_dir')
local warc_file_base = os.getenv('warc_file_base')
local item_type = nil

local url_count = 0
local tries = 0
local downloaded = {}
local addedtolist = {}
local abortgrab = false

local outlinks = {}
local discovered = {}

if urlparse == nil or http == nil then
  io.stdout:write("socket not corrently installed.\n")
  io.stdout:flush()
  abortgrab = true
end

local ids = {}

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

allowed = function(url, parenturl)
  if string.match(urlparse.unescape(url), "[<>\\%*%$%^%[%],%(%){}]") then
    return false
  end

  local tested = {}
  for s in string.gmatch(url, "([^/]+)") do
    if tested[s] == nil then
      tested[s] = 0
    end
    if tested[s] == 6 then
      return false
    end
    tested[s] = tested[s] + 1
  end

  if item_type == "post"
    and string.match(url, "^https?://images%.parler%.com/") then
    return false
  end

  local match = string.match(url, "^https?://[^/]*parler%.com/profile/([^/%?&]+)")
  if match then
    discovered["profile:" .. match] = true
  end

  if string.match(url, "^https?://images%.parler%.com/")
    or string.match(url, "^https?://image%-cdn%.parler%.com/")
    or string.match(url, "^https?://video%.parler%.com/")
    or string.match(url, "^https?://api%.parler%.com/l/")
    or string.match(url, "^https?://[^/]*par%.pw/") then
    return true
  end

  if item_type == "post" then
    for s in string.gmatch(url, "([0-9a-f]+)") do
      if ids[s] then
        return true
      end
    end
    for s in string.gmatch(url, "([0-9]+)") do
      if ids[s] then
        return true
      end
    end
  elseif item_type == "profile" then
    for s in string.gmatch(url, "([0-9a-zA-Z%.%-_]+)") do
      if ids[s] then
        return true
      end
    end
  end

  return false
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  return false
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil
  
  downloaded[url] = true

  local function check(urla)
    local origurl = url
    local url = string.match(urla, "^([^#]+)")
    local url_ = string.match(url, "^(.-)%.?$")
    url_ = string.gsub(url_, "&amp;", "&")
    url_ = string.match(url_, "^(.-)%s*$")
    url_ = string.match(url_, "^(.-)%??$")
    url_ = string.match(url_, "^(.-)&?$")
    url_ = string.match(url_, "^(.-)/?$")
    if (downloaded[url_] ~= true and addedtolist[url_] ~= true)
      and allowed(url_, origurl) then
      table.insert(urls, { url=url_ })
      addedtolist[url_] = true
      addedtolist[url] = true
    end
  end

  local function checknewurl(newurl)
    if string.match(newurl, "\\[uU]002[fF]") then
      return checknewurl(string.gsub(newurl, "\\[uU]002[fF]", "/"))
    end
    if string.match(newurl, "^https?:////") then
      check(string.gsub(newurl, ":////", "://"))
    elseif string.match(newurl, "^https?://") then
      check(newurl)
    elseif string.match(newurl, "^https?:\\/\\?/") then
      check(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^\\/") then
      checknewurl(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^//") then
      check(urlparse.absolute(url, newurl))
    elseif string.match(newurl, "^/") then
      check(urlparse.absolute(url, newurl))
    elseif string.match(newurl, "^%.%./") then
      if string.match(url, "^https?://[^/]+/[^/]+/") then
        check(urlparse.absolute(url, newurl))
      else
        checknewurl(string.match(newurl, "^%.%.(/.+)$"))
      end
    elseif string.match(newurl, "^%./") then
      check(urlparse.absolute(url, newurl))
    end
  end

  local function checknewshorturl(newurl)
    if string.match(newurl, "^%?") then
      check(urlparse.absolute(url, newurl))
    elseif not (string.match(newurl, "^https?:\\?/\\?//?/?")
      or string.match(newurl, "^[/\\]")
      or string.match(newurl, "^%./")
      or string.match(newurl, "^[jJ]ava[sS]cript:")
      or string.match(newurl, "^[mM]ail[tT]o:")
      or string.match(newurl, "^vine:")
      or string.match(newurl, "^android%-app:")
      or string.match(newurl, "^ios%-app:")
      or string.match(newurl, "^%${")) then
      check(urlparse.absolute(url, "/" .. newurl))
    end
  end

  local function eval_sum(s)
    if string.match(s, '%+') then
      total = 0
      for i in string.gmatch(s, "([0-9]+)") do
        total = total + tonumber(i)
      end
      return tostring(total)
    end
    return s
  end

  if string.match(url, "^https?://video%.parler%.com/.+_small") then
    check(string.gsub(url, "_small", ""))
  end

  local match = string.match(url, "^https?://api%.parler%.com/l/([^/]+)$")
  if match then
    check("https://par.pw/l/" .. match)
  end

  if allowed(url, nil) and status_code == 200 and not (
      string.match(url, "^https?://images%.parler%.com/")
      or string.match(url, "^https?://image%-cdn%.parler%.com/")
      or string.match(url, "^https?://video%.parler%.com/")
    ) then
    html = read_file(file)
    if string.match(url, "^https?://api%.parler%.com/v3/uuidConversion/") then
      local id = string.match(html, "([0-9a-f]+)")
      ids[id] = true
      check("https://parler.com/post/" .. id)
      check("https://share.par.pw/post/" .. id)
    end
    local match = string.match(url, "^https?://[^/]*parler%.com/post/([0-9a-f]+)$")
    if match then
      check("https://share.par.pw/post/" .. match)
    end
    for newurl in string.gmatch(string.gsub(html, "&quot;", '"'), '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(string.gsub(html, "&#039;", "'"), "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, ">%s*([^<%s]+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "[^%-]href='([^']+)'") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, '[^%-]href="([^"]+)"') do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, ":%s*url%(([^%)]+)%)") do
      checknewurl(newurl)
    end
  end

  return urls
end

wget.callbacks.httploop_result = function(url, err, http_stat)
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. "  \n")
  io.stdout:flush()

  --if string.match(url["url"], "^https?://api%.parler%.com/v3/uuidConversion/") then
  --  ids[string.match(url["url"], "([0-9]+)$")] = true
  --end

  local match = string.match(url["url"], "^https?://[^/]*parler%.com/post/([0-9a-f]+)$")
  if match then
    ids[match] = true
    item_type = "post"
  end

  local match = string.match(url["url"], "^https?://[^/]*parler%.com/profile/([0-9a-zA-Z%.%-_]+)$")
  if match then
    ids[match] = true
    item_type = "profile"
  end

  if string.match(url["url"], "^https?://share%.par%.pw/post/") then
    return wget.actions.EXIT
  end

  if status_code >= 300 and status_code <= 399 then
    local newloc = urlparse.absolute(url["url"], http_stat["newloc"])
    if string.match(url["url"], "^https?://api%.parler%.com/l/")
      and not allowed(newloc, nil) then
      outlinks[newloc] = true
    end
    if downloaded[newloc] == true or addedtolist[newloc] == true
      or not allowed(newloc, url["url"]) then
      tries = 0
      return wget.actions.EXIT
    end
  end
  
  if status_code >= 200 and status_code <= 399 then
    downloaded[url["url"]] = true
  end

  if abortgrab == true then
    io.stdout:write("ABORTING...\n")
    io.stdout:flush()
    return wget.actions.ABORT
  end

  if status_code == 0
    or (status_code > 400 and status_code ~= 404) then
    io.stdout:write("Server returned " .. http_stat.statcode .. " (" .. err .. "). Sleeping.\n")
    io.stdout:flush()
    local maxtries = 12
    if not allowed(url["url"], nil) then
      maxtries = 3
    end
    if tries >= maxtries then
      io.stdout:write("I give up...\n")
      io.stdout:flush()
      tries = 0
      if maxtries == 3 then
        return wget.actions.EXIT
      else
        return wget.actions.ABORT
      end
    else
      os.execute("sleep " .. math.floor(math.pow(2, tries)))
      tries = tries + 1
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end

wget.callbacks.finish = function(start_time, end_time, wall_time, numurls, total_downloaded_bytes, total_download_time)
  local discos = {
    ["parler-fai8ohqu0phi9loh"]=discovered,
    ["urls-t05crln9brluand"]=outlinks
  }
  for k, d in pairs(discos) do
    local items = nil
    for item, _ in pairs(d) do
      print('found item', item)
      if items == nil then
        items = item
      else
        items = items .. "\0" .. item
      end
    end

    if items ~= nil then
      local tries = 0
      while tries < 10 do
        local body, code, headers, status = http.request(
          "http://blackbird-amqp.meo.ws:23038/" .. k .. "/",
          items
        )
        if code == 200 or code == 409 then
          break
        end
        os.execute("sleep " .. math.floor(math.pow(2, tries)))
        tries = tries + 1
      end
      if tries == 10 then
        abortgrab = true
      end
    end
  end
end

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if abortgrab == true then
    return wget.exits.IO_FAIL
  end
  return exit_status
end

