local exports = {}

function exports.pos_to_str(pos, sep)
	sep = sep or " "
	return pos.x .. sep .. pos.y .. sep .. pos.z
end

function exports.emit_allowed_check(checks, plname, event)
	for _, check in pairs(checks) do
		if not check(plname, event) then
			return false
		end
	end
	return true
end

function exports.emit_event(handlers, event)
	for _, handler in pairs(handlers) do
		handler(event)
	end
end

return exports
