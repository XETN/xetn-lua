local require = require
local type = type
local print = print
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