require "socket"
require "logger"


require "rack/rewindable_input"

class App
  def call(env)
    if env["PATH_INFO"] == "/"
      [200, {}, ["It works!"]]
    else
      [404, {}, ["Not Found"]]
    end
  end
end

class ForkServer
  def self.run(app, **options)
    new(app, options).start
  end

  def initialize(app, options)
    @app = app
    @options = options
    @logger = Logger.new($stdout)
  end

  def start
    @logger.info "ForkServer starting..."
    server = TCPServer.new(@options[:Port].to_i)
    loop do
      client = server.accept
      child_pid = fork do
        server.close

        request_line = client.gets&.chomp
        %r[^GET (?<path>.+) HTTP/1.1$].match(request_line)
        path = Regexp.last_match(:path)

        unless path
          client.puts "HTTP/1.1 501 Not Implemented"
          client.close
          next
        end

        request_headers = {}
        while %r[^(?<name>[^:]+):\s+(?<value>.+)$].match(client.gets.chomp)
          request_headers[Regexp.last_match(:name)] = Regexp.last_match(:value)
        end

        env = ENV.to_hash.merge(
          Rack::REQUEST_METHOD    => "GET",
          Rack::SCRIPT_NAME       => "",
          Rack::PATH_INFO         => path,
          Rack::SERVER_NAME       => @options[:Host],
          Rack::RACK_INPUT        => Rack::RewindableInput.new(client),
          Rack::RACK_ERRORS       => $stderr,
          Rack::QUERY_STRING      => "",
          Rack::REQUEST_PATH      => path,
          Rack::RACK_URL_SCHEME   => "http",
          Rack::SERVER_PROTOCOL   => "HTTP/1.1",
          )
        status, headers, body = @app.call(env)

        client.puts "HTTP/1.1 #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]}"

        headers.each do |name, value|
          client.puts "#{name}: #{value}"
        end
        client.puts
        body.each do |line|
          client.puts line
        end

        @logger.info "GET #{path} => #{status}"
      ensure
        client.close
      end
      Process.waitpid(child_pid)

      client.close
    end
  end
end

Rackup::Handler.register "fork_server", ForkServer

run App.new