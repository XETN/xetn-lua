local require = require
local type = type
local table, string = table, string
local tonumber = tonumber
local print = print
module("request")

local __internal__ = require("xetn.lua.http")

Meta = {}

function Meta:method()
    return __internal__.getMethod(self.__raw__):upper()
end

function Meta:path()
    return __internal__.getPath(self.__raw__)
end

function Meta:header(field)
    return __internal__.getHeader(self.__raw__, field)
end

function Meta:version()
    return __internal__.getVersion(self.__raw__)
end

function Meta:contentLength()
    local ret = __internal__.getHeader(self.__raw__, "Content-Length");
    if ret ~= nil then
        ret = tonumber(ret)
    end
    return ret
end

function Meta:query()
    if self.__args__ == nil then
        -- TODO decode it
        self.__args__ = __internal__.getQuery(self.__raw__)
    end
    return self.__args__
end

function Meta:args(key)
    local query = self:query()
	if query == nil then
		return nil
	end

    local result = nil
    local pattern = key .. "=([^=&:;@#?]*)"
    -- the URL is already verified by the HTTP parser
    for v in query:gmatch(pattern) do
        if result == nil then
            result = v
        else
            if type(result) == "string" then
                result = {[1] = result}
            end
            result[#result + 1] = v
        end
    end
    return result
end

function Meta:body()
    if self.__body__ == nil then
        local content = {}
        local len = self:contentLength()
        if len == nil then
            return nil
        end
        while len > 0 do
            local c = __internal__.getBody(self.__net__, len)
            if c ~= nil then
                len = len - #c
                content[#content + 1] = c
            end
        end
        self.__body__ = table.concat(content)
    end
    return self.__body__
end

function Meta:skipBody()
    if self.__body__ == nil then
        local len = self:contentLength()
        if len == nil then
            return
        end
        while len > 0 do
            local l = __internal__.skipBody(self.__net__, len)
            --print("L->", l)
            if l ~= nil then
                len = len - l
            end
        end
    end
end

function Meta:data(key)
    local body = self:body()
    if body == nil then
        return nil
    end

    local result = nil
    local pattern = key .. "=([^=&:;@#?]*)"
    -- the URL is already verified by the HTTP parser
    for v in body:gmatch(pattern) do
        if result == nil then
            result = v
        else
            if type(result) == "string" then
                result = {[1] = result}
            end
            result[#result + 1] = v
        end
    end
    return result
end

function Meta:cookie(key)
    local cookie = self.__cookie__
    if cookie == nil then
        cookie = __internal__.getHeader(self.__raw__, "Cookie")
        if cookie == nil then
            return nil
        end
        self.__cookie__ = cookie
    end
    --local key = "[%w%^%$%%%*%+%-%.!#&'_`|~]+"
    local val = "[%w%^%$%%%*%+%-%.%(%)%[%]%?!#&'_`|~/:<=>@{}]+"
    local pattern = string.format("%s=(%s)", key, val)
    return cookie:match(pattern)
end
