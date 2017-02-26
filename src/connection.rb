require 'socket'
require 'thread'
require 'yaml'
require 'pathname'
require 'digest/sha1'

class Connection

  @@safely = Mutex.new

  def self.handle client, backing
    self.new(client, backing).handle_control
  end



  def initialize client, backing
    @client = client
    @backing = Pathname.new(backing).realpath
    @id = 30.times.map { ('a'..'z').to_a.sample }.join
    @data_q = Queue.new
  end

  attr_reader :id

  def handle_control
    loop do
      next_request = @client.gets("\n...", 4096)
      raise EOFError.new if next_request.nil?

      message = YAML.load next_request
      next unless message.is_a? Hash  # Probably a blank message

      resp = if get_m = message[:get]
        get_path = get_m[:path]
        get_hash = get_m[:cached]
        raise 'No path' unless get_path.is_a? String
        raise 'Bad hash' unless get_hash.nil? || (get_hash.is_a?(String) && get_hash.length == 30)
        do_get get_path, get_hash

      elsif get_m = message[:keep_alive]
        { status: 'up-to-date' }

      else
        raise 'Message not understood'
             end

      @client.write(resp.to_yaml + "...\n")

    end
  end

  def do_get path, hash
    path = verify_resource path
    f_contents = File.open(path.to_s, 'rb') { |iost| iost.read }  # TODO: Refactor this for big files
    f_hash = Digest::SHA1.hexdigest f_contents

    resp = if f_hash == hash
             { status: 'up-to-date' }

           else
             { status: 'new',
                contents: f_contents }

           end

    resp[:flags] = { atime: path.atime,
                      birthtime: path.birthtime,
                      ctime: path.ctime,
                      mtime: path.mtime,
                      executable: path.executable? }

    resp
  end

  def verify_resource path
    proposed = (@backing + path).cleanpath  # Resolves ../ in path
    if proposed.to_path.start_with?(@backing.to_path)
      if proposed.owned?
        return proposed
      else
        raise 'We don’t own that file'
      end
    else
      raise 'Path would reach outside mountpoint'
    end
  end



end
