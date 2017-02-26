require 'socket'
require 'yaml'

class Client
  def self.get srv, file, port
    server = TCPSocket.new srv, port

    server.puts "lore #{VERSION}"
    message = { get: { path: file, cached: nil } }.to_yaml + "...\n"
    server.puts message

    resp = YAML.load( server.gets("\n...") )
    puts resp

  end
end
