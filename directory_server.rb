require 'socket'
require 'time'
require File.dirname(__FILE__) + '/file_server'
require File.dirname(__FILE__) + '/lock_server'

class DirectoryServer
@files
@file_servers
@server
@no_servers
@running

def initialize
  @running = true
  @files = Array.new
  @file_servers = Array.new
  @no_servers = 4
  @server = TCPServer.new 80
  load_files
  initialize_servers
  @lock_server = LockServer.new 'localhost', 79 , self
  Thread.new do
    @lock_server.run
  end


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
        when /\AREQ CURRDIR\n\n/
          client.puts Dir.pwd.chomp+"\n\n"
          client.close
        when /\ACD: (\S+)\nCURRDIR: (\S+)\n\n/
          if Dir.exists?($2+'/'+$1)
            client.puts "OK\nDIR: #{$2+'/'+$1}\n\n"
            client.close
          else
            client.puts "ERROR: DI00\nDESCRIPTION: INVALID DIRECTORY\n\n"
            client.close
          end

        when/\ACD: ..\nCURRDIR: (.*)\/(\S+)\n\n/
          client.puts "OK\nDIR: #{$1}\n\n"
          client.close

        when /\ALS\nCURRDIR: (\S+)\n\n/
          response = "OK\nLIST: "
          Dir.entries($1).each do |e|
            response = response+e+"\n"
          end
          client.puts response+"\n\n"
          client.close

        when /\AFILE: (\S+)\n\n/
          file = getfilebyname($1)
          if file == nil
            file = ServerFile.new($1,Random.new.rand(0..@no_servers-1))
            @files << file
            @file_servers[file.server_id].files << file
          end
          response = "OK\nSERVER_ID: #{file.server_id}\nPORT: #{81+file.server_id}\nIP: localhost\n\n"
          client.puts response
          client.close

        when/\ALOCK: (\S+)\n\n/
          file = getfilebyname($1)
          if file.locked == false
            file.locked = true
            @file_servers[file.server_id].getfilebyname($1).locked=true
            token = @lock_server.gentoken
            @lock_server.clientlocks << [$1,token,Time.now]
            response = "OK\nLOCKED: #{$1}\nTOKEN: #{token}\nPORT: 79\nIP: localhost\n\n"
            client.puts response
            client.close
          else
            client.puts "FILE ALREADY LOCKED\n\n"
            client.close
          end

        when/\ACRDIR: (\S+)\n\n/
          Dir.mkdir($1)
          client.puts "DIRECTORY CREATED\n\n"
          client.close


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

  def prop_unlock(filename)
    file = getfilebyname(filename)
    file.locked = false
    @file_servers[file.server_id].getfilebyname(filename).locked=false
  end

  def load_files
    Dir.chdir(Dir.pwd+'/ServerFiles')
    files_t = Dir.glob(Dir.pwd+'/**/*').select{
        |e| File.file? e
    }

    server_id = 0
    files_t.each do |f|
      file = ServerFile.new(f,server_id)
      server_id+=1
      @files << file
    end
  end

  def initialize_servers
  #array of servers, each one gets port, id & list of files
    i = 0
    while i < @no_servers
      serverfiles = Array.new
      @files.each do |f|
        serverfiles << f if f.server_id == i
      end

      server = FileServer.new(81+i,serverfiles,i)
      @file_servers << server
      i+=1
      Thread.new do
        server.run
      end
    end


  end
end

class ServerFile
  @name
  @server_id
  @locked

  attr_accessor :name,:server_id, :locked
  def initialize(name,id)
    @name = name
    @server_id = id
    @locked = false
  end
end

DirectoryServer.new