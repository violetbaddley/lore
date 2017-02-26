require 'socket'
require 'thread'
require_relative 'connection.rb'

class Sharepoint
  def initialize name, backing, port
    @name = name
    @backing = backing
    @network = TCPServer.new '127.0.0.1', port

    @dispatch = SizedQueue.new(MAX_CLIENTS)
    @thread_pool = Array.new(MAX_CLIENTS) do
      Thread.new do
        puts "Waiting for actions"
        while task = @dispatch.pop
          puts "Got action"
          task.call
        end
      end
    end

  end

  def offer
    loop do
      client = @network.accept
      puts 'GOT CLIENT'
      assert_local client
      client.set_encoding 'ASCII-8BIT'  # Better for raw data xfer; passes utf-8 through transparently
      @dispatch << proc do

        begin
          assert_version client
          Connection.handle client, @backing

        rescue EOFError => e
          $stderr.puts "Client closed"
        rescue => e
          $stderr.puts "Encountered error, closing."
          $stderr.puts e.message, e.backtrace
        ensure
          client.close
        end

      end
    end

    self
  end

  def close
    @network.close
    @dispatch.close
    @thread_pool.each(&:join)
  end

  def assert_version sock
    if sock.gets("\n", 30).chomp != "lore #{VERSION}"
      raise "Client/server version mismatch; server on v#{VERSION}"
    end
  end

  def assert_local sock
    _, _, peername, peeraddr = sock.peeraddr(:hostname)
    if peeraddr != '127.0.0.1' && peeraddr != "::1"
      raise "Non-local client (#{peeraddr} #{peername}) attempting to connect! Refusing."
    end
  end

end
