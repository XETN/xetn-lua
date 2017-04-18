local xetn = require("xetn")
local log = xetn.getLogger()
local app = xetn.new();

app:get("/lua/test/:id", function(req, res)
	return "<h1>Welcom, " .. req.params.id .. "</h1>"
end)

app:get("/lua/:command/:type", function(req, res)
	if req:query() then
		log.record(log.INFO, "QUERY -> " .. req:query())
		local args = req:args("name")
		if type(args) == "string" then
			print(string.format("name => %q", args))
		else
			print("name =>")
			for i, e in ipairs(args) do
				print(string.format("\t[%d] = %q", i, e))
			end
		end
	end
	return string.format("<h1>Command: %s</h1><h2>Type: %s</h2>",
		req.params.command, req.params.type)
end):post("/lua/:command/:type", function(req, res)
	return string.format("<h1>%s-%s-%s</h1>", req:method(),
		req.params.command, req.params.type)
end)
