require 'securerandom'
require 'socket'

class LockServer

  attr_accessor :clientlocks

def initialize(host,port,directory_server)
  @clientlocks = Array.new
  @server = TCPServer.new host, port
  @directory_server = directory_server
  @running = true
end

  def run
    Thread.new do
      while @running do
        sleep(3)
          @clientlocks.each do |clientlock|
            if Time.now.to_f - clientlock[2].to_f > 300
              delete_lock(clientlock)
              @directory_server.prop_unlock(clientlock[0])
            end
          end
      end
    end

    while @running do
      client = @server.accept
      Thread.new do
        Thread.abort_on_exception = true
        handle(client)
      end
    end
  end

  def handle(client)
    message = client.gets("\n\n")
    case message
      when/\AWRITE: (\S+)\nTOKEN: (\S+)\n(.*)\n\n/
        if validate($1,$2)
          file = File.open($1,'w')
          file.write $3
          file.close
          client.puts("OK: #{$1}\nWRITTEN TO FILE\n\n")
          client.close
        else
          client.puts "ERROR: LO00\nDESCRIPTION: INVALID TOKEN/FILE COMBINATION\n\n"
          client.close
        end

      when/\AUNLOCK: (\S+)\nTOKEN: (\S+)\n\n/
        if validate($1,$2)
          if unlock($1,$2)
            client.puts "OK\nUNLOCKED\n\n"
            client.close
          else
            client.puts "ERROR:LO01\nDESCRIPTION: INVALID TOKEN/FILE COMBINATION\n\n"
            client.close
          end
        else
          client.puts "ERROR: LO00\nDESCRIPTION: INVALID TOKEN/FILE COMBINATION\n\n"
          client.close
        end

      else
        client.puts("ERROR: 0000\nDESCRIPTION: UNRECOGNIZED COMMAND\n\n")
        client.close
    end
  end

  def unlock(filename,token)
    if validate(filename,token)
        delete_lock([filename,token])
        @directory_server.prop_unlock(filename)
    end
    false
  end

def delete_lock(lock)
  @clientlocks.each do |clientlock|
    if clientlock[0] == lock[0] && clientlock[1] == lock[1]
      @clientlocks.delete(clientlock)
    end
  end
end

  def validate(filename,token)
    @clientlocks.each do |clientlock|
      return true if clientlock[0]==filename && clientlock[1] == token
    end
    false
  end

  def gentoken
    SecureRandom.hex
  end
end

