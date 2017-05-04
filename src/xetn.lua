local require, package = require, package
local loadfile, pcall = loadfile, pcall
local type, pairs, ipairs = type, pairs, ipairs
local getmetatable, setmetatable = getmetatable, setmetatable
local os, string, table = os, string, table
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

local NOT_FOUND      = "Not Found"
local INTERNAL_ERROR = "Internal Error"

-- return type flag
local TYPE_STR  = 0x01
local TYPE_FILE = 0x02

local function pathToPattern(path)
    local kset = {}
    local S, E, L = 1, 1, 1
    local index = 1
    local partial = {}
    partial[#partial + 1] = "^"

    while true do
        S, E = path:find(":[%w_]+", L)
        -- end point
        if S == nil then break end
        -- save the named capturer with its index
        kset[path:sub(S + 1, E)] = index
        index = index + 1

        if S ~= L then
            -- save the characters between the last and current named capturer
            partial[#partial + 1] = path:sub(L, S - 1)
        end

        if path:sub(E + 1, E + 1) == "(" then
            S, E = path:find("%([^%)]+%)", E + 1)
            partial[#partial + 1] = path:sub(S, E)
        else 
            partial[#partial + 1] = "([^/]+)"
        end
        L = E + 1
    end

    if L ~= #path then
        partial[#partial + 1] = path:sub(L, #path)
    end
    partial[#partial + 1] = "$"

    return table.concat(partial), kset, index - 1
end

------------------------------------------------------------------------
--                         Xetn App Interface                         --
------------------------------------------------------------------------

local XetnApp = {}
function XetnApp:register(method, path, action)
	local arr = self.actions
	for i, v in ipairs(arr) do
		if v.__path__ == path then
			-- it will override the existed action
			arr[i][method:upper()] = action
			return self
		end
	end
	local pattern, keys, nkey = pathToPattern(path)
	local set = {
		__path__    = path,
		__pattern__ = pattern,
		__keys__    = keys,
		__nkey__    = nkey
	}
	set[method:upper()] = action
	arr[#arr + 1] = set
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
setmetatable(XetnAppRef, { __index = XetnApp })

function new()
	XetnAppRef.actions = {}
	return XetnAppRef
end

function getLogger()
	return log
end

local function findAction(router, path, method, params)
	local actionMap = nil
	-- process router in register order
	for _, v in ipairs(router) do
		if v.__nkey__ == 0 then
			-- plain compare
			if path == v.__path__ then
				actionMap = v
				break
			end
		else
			-- pattern match
			local result = { path:match(v.__pattern__) }
			if #result == v.__nkey__ then
				for k, i in pairs(v.__keys__) do
					params[k] = result[i]
				end
				actionMap = v
				break
			end
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
function execute(app, req, res)
	print("APP PATH => " .. app)
	req = { __raw__ = req }
	res = { __raw__ = res }
	setmetatable(req, { __index = Req.Meta })
	setmetatable(res, { __index = Res.Meta })
	-- check if there already exists the specific app
	local err
	local isOK = true
	if XetnAppMap[app] == nil then
		local func
		-- register the root of app, so app can use its module correctly
		package.path = string.format("%s;%s/?.lua", package.path, app)
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
