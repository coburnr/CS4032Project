require 'socket'

class FileServer
  @port
  @server
  @files
  @id
  @running

  attr_accessor :files

  def initialize(port,files,id)
    @id = id
    @port = port
    @files = files
    @server = TCPServer.new 'localhost', port
    @running = true

  end

  def run
    while @running do
      client = @server.accept
      Thread.new do
        handle(client)
      end
    end
  end

  def handle(client)
      message = client.gets("\n\n")
      case message
        when /\AREAD: (\S+)\n\n/ then
          if File.exists?($1)
            file = File.open($1,'r')
            response = file.read + "\n\n"
            file.close
            client.puts("OK: #{$1}\nTIME: #{Time.now}\nDATA: "+response)
            client.close
          else
            client.puts "ERROR: FI01\nDESCRIPTION: FILE NOT FOUND\n\n"
            client.close
          end

        when /\AWRITE: (\S+)\n(.*)\n\n/
          file_t = getfilebyname($1)
          if !file_t.locked
            file = File.open($1,'w')
            file.write($2)
            file.close
            client.puts("OK: #{$1}\nWRITTEN TO FILE\n\n")
            client.close
          else
            client.puts("LOCKED\n\n")
            client.close
          end

        when /\ANEW: (\S+)\n(.*)\n\n/
          file = File.open($1,'w')
          file.write($2)
          file.close
          client.close

        when /\ADELETE: (\S+)\n\n/
          if File.exists? $1
            File.delete($1)
            client.puts "OK\nFILE DELETED\n\n"
            client.close
          else
            client.puts "ERROR: FI01\nDESCRIPTION: FILE NOT FOUND\n\n"
            client.close
          end

        when /\APING\nFILE: (\S+)\nTIME: (.*)\n\n/m
          if File.mtime($1) > Time.parse($2)
            client.puts "INVALIDATE CACHE\n\n"
            client.close
          else
            client.puts "OK\nCACHE: #{$1}\n\n"
            client.close
          end

        else
          client.puts("ERROR: 0000\nDESCRIPTION: UNRECOGNIZED COMMAND\n\n")
          client.close

      end
  end

  def getfilebyname(name)
    @files.each do |f|
      return f if f.name == name
    end
    nil
  end
end