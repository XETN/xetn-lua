local require, loadfile, pcall = require, loadfile, pcall
local pairs = pairs
local getmetatable, setmetatable = getmetatable, setmetatable
local os = os
local type = type
local print = print

-- forbid os.exit()
os.exit = function()
	print("CALL EXIT")
end

module("xetn")

local Req = require("request")
local Res = require("response")
local log = require("xetn.lua.log")

-- supported method flags
local METHOD_GET    = "GET"
local METHOD_POST   = "POST"
local METHOD_PUT    = "PUT"
local METHOD_DELETE = "DELETE"

local NOT_FOUND = "Not Found"
local INTERNAL_ERROR = "Internal Error"

-- return type flag
local TYPE_STR  = 0x01
local TYPE_FILE = 0x02

local function pathToPattern(path)
    local name, pair = {}, {}
    local s, e = 0, 0
    local index = 1
    -- match the syntax like (xxxx), (xxx%)xxx)
    s, e = path:find("%(.-[^%%]%)", e)
    while s ~= nil do
        -- if the character before ( is %, then it is unacceptable
        if s == 1 or path:sub(s - 1, s - 1) ~= "%" then
            pair[index] = s
            index = index + 1
        end
        s, e = path:find("%(.-[^%%]%)", e)
    end
    e = 0
    index = 1
    -- match the syntax like :aaaa, :aaa_aaa
    s, e = path:find(":[%w_]+", e)
    while s ~= nil do
        name[index] = s
        index = index + 1
        s, e = path:find(":[%w_]+", e)
    end
    index = 1
    local i, j = 1, 1
    while i <= #name and j <= #pair do
        if pair[j] > name[i] then
            name[i] = index
            i = i + 1
        else
            j = j + 1
        end
        index = index + 1
    end
    while i <= #name do
        name[i] = index
        i = i + 1
        index = index + 1
    end

    index = 1
    local key = {}
    for k in path:gmatch(":([%w_]+)") do
        key[k] = name[index]
        index = index + 1
    end
    pattern = path:gsub(":[%w_]+", "%([^/]+%)")
    return pattern, key
end

------------------------------------------------------------------------
--                         Xetn App Interface                         --
------------------------------------------------------------------------

local XetnApp = {}
function XetnApp:register(method, path, action)
	if self.actions[path] == nil then
		local pattern, keys = pathToPattern(path)
		self.actions[path] = {
			pattern = pattern,
			keys = keys
		}
	end
	self.actions[path][method:upper()] = action
	return self
end

function XetnApp:get(path, action)
	return self:register(METHOD_GET, path, action)
end

function XetnApp:post(path, action)
	return self:register(METHOD_POST, path, action)
end

function XetnApp:put(path, action)
	return self:register(METHOD_PUT, path, action)
end

function XetnApp:delete(path, action)
	return self:register(METHOD_DELETE, path, action)
end

------------------------------------------------------------------------
--                           Xetn Interface                           --
------------------------------------------------------------------------

local XetnAppRef = {
	actions = nil
}
setmetatable(XetnAppRef, {__index = XetnApp})

function new()
	XetnAppRef.actions = {}
	return XetnAppRef
end

function getLogger()
	return log
end

local function findAction(router, path, method, params)
	local actonMap = nil
	for _, v in pairs(router) do
		local result = { path:match(v.pattern) }
		if #result ~= 0 then
			for k, i in pairs(v.keys) do
				params[k] = result[i]
			end
			actionMap = v
			break
		end
	end
	if actionMap == nil then
		return nil
	end
	return actionMap[method]
end

local function dispatch(router, req, res)
	req.params = {}
	local action = findAction(router, req:path(), req:method(), req.params)
	-- TODO initialize res
	res:version(1.1)
	local result
	local isOK = action ~= nil
	if isOK then
		isOK, result = pcall(action, req, res)
	end
	if req:contentLength() and req.__body__ == nil then
		req:skipBody() -- avoid the problem of RST
	end

	if isOK == false then
		if action == nil then
			res:status(404)
			res:contentLength(#NOT_FOUND)
			return { type = TYPE_STR, target = NOT_FOUND }
		else
			res:status(500)
			res:contentLength(#INTERNAL_ERROR)
			print("ERR: " .. result)
			return { type = TYPE_STR, target = INTERNAL_ERROR }
		end
	elseif type(result) == "string" then 
		res:status(200)
		res:contentLength(#result)
		return { type = TYPE_STR, target = result }
	end
end

local XetnAppMap = {}
function execute(app, req, res, net)
	print("APP PATH => " .. app)
	req = { __raw__ = req, __net__ = net }
	res = { __raw__ = res, __net__ = net }
	setmetatable(req, { __index = Req.Meta })
	setmetatable(res, { __index = Res.Meta })
	-- check if there already exists the specific app
	local err
	local isOK = true
	if XetnAppMap[app] == nil then
		local func
		func, err = loadfile(app .. "/init.lua")
		isOK = func ~= nil
		if isOK then
			isOK, err = pcall(func)
		end
		XetnAppMap[app] = XetnAppRef.actions
		XetnAppRef.actions = nil
	end
	if isOK == false then
		print("ERR: " .. err)
		-- loading file failed
		res:version(1.1)
		res:status(500)
		res:contentLength(#INTERNAL_ERROR)
		print("ERR: " .. err)
		return {
			type = TYPE_STR,
			target = INTERNAL_ERROR
		}
	end
	return dispatch(XetnAppMap[app], req, res)
end
