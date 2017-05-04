local require = require
local type = type
local print = print
local string = string
local os = os
module("response")

local __internal__ = require("xetn.lua.http")

Meta = {}

function Meta:body(body)
    __internal__.setBody(self.__raw__, body)
end

function Meta:status(code)
    __internal__.setStatus(self.__raw__, code)
end

function Meta:header(field, value)
    __internal__.putHeader(self.__raw__, field, value)
end

function Meta:date(time)
	__internal__.setDate(self.__raw__, time)
end

function Meta:contentLength(value)
    __internal__.putHeader(self.__raw__, "Content-Length", value)
end

function Meta:version(ver)
    if type(ver) == "string" then
        if ver:upper() == "HTTP/1.0" then
            ver = 1.0
        else
            ver = 1.1
        end
    elseif type(ver) ~= "number" then
        -- HTTP/1.1 is the default choice
        ver = 1.1
    end
    __internal__.setVersion(self.__raw__, ver)
end

function Meta:cookie(key, val, expire)
    local cookie
    -- getDomain & getPath functions can only be used internally
    local domain = __internal__.getDomain(self.__raw__)
    local path   = __internal__.getPath(self.__raw__)
    if expire == nil then
        cookie = string.format("%s=%s; domain=%s; path=%s",
            key, val, domain, path)
    else
        local exp = os.time() + expire
        cookie = string.format("%s=%s; domain=%s; path=%s; expires=%s",
            key, val, domain, path,
            os.date("!%a, %d %b %Y %H:%M:%S GMT", exp))
    end
    __internal__.putHeader(self.__raw__, "Set-Cookie", cookie)
end