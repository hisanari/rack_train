require "rack/request"
require "rack/response"

class App
	def call(env)
		request = Rack::Request.new(env)
		case [request.request_method, request.path_info]
		when ['GET', '/']
			Rack::Response.new("It works!", 200).finish
		when ['GET', '/hello']
			Rack::Response.new("Hello, world!", 200).finish
		else
			Rack::Response.new("Not found", 404).finish
		end
	end
end

run App.new
