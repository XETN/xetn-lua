# xetn-lua

A LuaJIT web framework for [Xetn](https://github.com/codesun/xetn).

**NOTICE:** This web framework can only work based on the Lua Module of Xetn.

## Status

Under development.

Certainly, there exists many bugs.

## Module

+ [x] Request/Response
+ [x] Restful router(basic)
+ [x] Native logger
+ [x] Cookie(basic)
+ [ ] Session (redis)
+ [ ] WebSocket(pending)

## Router

`xetn-lua` has a restful router based on the pattern matching of Lua, **INSTEAD OF** regex.

Lua pattern is allowed inside router path, **EXCEPT** capture with `(` and `)`, or it will bring weird result.

If you want to capture url portion, you should use named capturer, with which you can locate the result later.

The name of capturer **MUST** starts with `:`, and it consists with alphabet, number and underscore. Here is a simple example:

```
/:name/:id/test
/std/123/test

pattern = "^/([^/]+)/([^/]+)/test$"

result = {
    name = "std",
    id = "123"
}
```

Moreover, you can define specific pattern for some named capturer, for instance, what if `id` only capture a number?

```
/:name/:id(%d+)/test

pattern "^/([^/]+)/(%d+)/test$"
```

Eventually, you **MUST NOT** add `^` and `$` manually, because router will add them automatically.

Currently, this router is elementary, and Lua pattern also has its limitation.

Apart from customized named capturer, it is recommended to define path as concrete as possible.
