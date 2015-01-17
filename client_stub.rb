require 'socket'

class ClientStub
  @current_directory
  @cached_files
  @locked_files

  def initialize
    @cached_files = Array.new
    @locked_files = Array.new
    @running = true

    Thread.new do
    while @running do
      sleep(1)
      check_cache
    end
    end

    directory_connection = TCPSocket.open 'localhost',80
    directory_connection.puts "REQ CURRDIR\n\n"
    resp = directory_connection.gets("\n\n")
    directory_connection.close
    @current_directory = resp.chomp.chomp

    while @running do
      run
    end

  end

  def run
    command = gets.chomp
    case command
      when /\Acd (\S+)/
        directory_connection = TCPSocket.open 'localhost',80
        directory_connection.puts "CD: #{$1}\nCURRDIR: #{@current_directory}\n\n"
        resp = directory_connection.gets("\n\n")
        directory_connection.close

        if /\AOK\nDIR: (.*)\/(\S+)\n\n/ === resp
          @current_directory = @current_directory+'/'+$2
          puts $2
        elsif /\AERROR: (\S+)\nDESCRIPTION: (.*)\n\n/ === resp
          puts "Error #{$1}: #{$2}"
        end

      when /\Als/
        directory_connection = TCPSocket.open 'localhost',80
        directory_connection.puts "LS\nCURRDIR: #{@current_directory}\n\n"
        resp = directory_connection.gets("\n\n")
        directory_connection.close

        if /\AOK\nLIST: .\n..\n(.*)/m === resp
          print $1
        end

      when/\Aread (\S+)/
        filename = $1
        file = lookup_cache(filename)
        if file != nil
          puts file.name
          puts file.data
        else
          directory_connection = TCPSocket.open 'localhost',80
          directory_connection.puts "FILE: #{@current_directory+'/'+filename}\n\n"
          resp = directory_connection.gets("\n\n")
          directory_connection.close

          if /\AOK\nSERVER_ID: (\S+)\nPORT: (\S+)\nIP: (\S+)\n\n/ === resp
            file_server_connection = TCPSocket.open $3,$2
            file_server_connection.puts "READ: #{@current_directory+'/'+filename}\n\n"
            resp = file_server_connection.gets("\n\n")
            file_server_connection.close
            server_id = $1
            port = $2
            ip = $3

            if/\AOK: (\S+)\nTIME: (.*)\nDATA: (.*)\n\n/m === resp
              file = ClientFile.new(filename,server_id,port,ip,$2,$3)
              @cached_files << file
              puts file.data
            elsif /\AERROR: (\S+)\nDESCRIPTION: (.*)\n\n/ === resp
              puts "Error #{$1}: #{$2}"
            end
          end
        end

      when /\Awrite (\S+) (.*)/
        filename = $1
        data = $2
        directory_connection = TCPSocket.open 'localhost',80
        directory_connection.puts "FILE: #{@current_directory+'/'+filename}\n\n"
        resp = directory_connection.gets("\n\n")
        directory_connection.close
        if /\AOK\nSERVER_ID: (\S+)\nPORT: (\S+)\nIP: (\S+)\n\n/ === resp
          file_server_connection = TCPSocket.open $3,$2
          file_server_connection.puts "WRITE: #{@current_directory+'/'+filename}\n#{data}\n\n"
          resp = file_server_connection.gets("\n\n")
          file_server_connection.close

          if /\AOK: (.*)\nWRITTEN TO FILE\n\n/===resp
            puts "Written to file\n"
            file = lookup_cache(filename)
            if file != nil
              @cached_files.delete(file)
            end

          elsif/\ALOCKED\n\n/===resp
            file = lookup_locked(filename)
            if file != nil
              lock_server_connection = TCPSocket.open 'localhost',79
              lock_server_connection.puts "WRITE: #{file[0]}\nTOKEN: #{file[1]}\n#{data}\n\n"
              resp = lock_server_connection.gets("\n\n")
              lock_server_connection.close
              if /\AOK: (.*)\nWRITTEN TO FILE\n\n/===resp
                puts "Written to file\n"
              end
            else
              puts "File is locked by another user, please try again in 5 minutes\n"
            end
          end
        end

      when /\Alock (\S+)/
        directory_connection = TCPSocket.open 'localhost',80
        directory_connection.puts "LOCK: #{@current_directory+'/'+$1}\n\n"
        resp = directory_connection.gets("\n\n")
        directory_connection.close

        if /\AOK\nLOCKED: (\S+)\nTOKEN: (\S+)\nPORT: (\d+)\nIP: (\S+)\n\n/ === resp
          @locked_files << [$1,$2]
          puts "File locked, you now have exclusive access\n"
        elsif /\AFILE ALREADY LOCKED\n\n/ === resp
          puts "File is already locked by another user. Please try again later.\n"
        end

      when/\Aunlock (\S+)/
        file = lookup_locked($1)
        if file == nil
          puts "Cannot unlock file that is not locked\n"
        else
          lock_server_connection = TCPSocket.open 'localhost',79
          lock_server_connection.puts "UNLOCK: #{file[0]}\nTOKEN: #{file[1]}\n\n"
          resp = lock_server_connection.gets("\n\n")
          lock_server_connection.close
          if /\AOK\nUNLOCKED\n\n/ === resp
            @locked_files.delete(file)
            puts "File unlocked"
          else
            puts "Unable to unlock file"
          end
        end

      when/\Adelete (\S+)/
        filename = $1
        directory_connection = TCPSocket.open 'localhost',80
        directory_connection.puts "FILE: #{@current_directory+'/'+filename}\n\n"
        resp = directory_connection.gets("\n\n")
        directory_connection.close

        if /\AOK\nSERVER_ID: (\S+)\nPORT: (\S+)\nIP: (\S+)\n\n/ === resp
          file_server_connection = TCPSocket.open $3,$2
          file_server_connection.puts "DELETE: #{@current_directory+'/'+filename}\n\n"
          resp = file_server_connection.gets("\n\n")
          file_server_connection.close

          if /\AOK\nFILE DELETED\n\n/===resp
            puts "File deleted\n"
            file = lookup_cache(filename)
            if file != nil
              @cached_files.delete(file)
            end
          elsif /\AERROR: (\S+)\nDESCRIPTION: (.*)\n\n/ === resp
            puts "Error #{$1}: #{$2}"
          end
        end

      when /\Acrdir (\S+)/
        directory_connection = TCPSocket.open 'localhost',80
        directory_connection.puts "CRDIR: #{@current_directory+'/'+$1}\n\n"
        resp = directory_connection.gets("\n\n")
        directory_connection.close
        if /\ADIRECTORY CREATED\n\n/ === resp
          puts "Directory created"
        else
          puts "Unable to create directory"
        end

      else
        puts "Unrecognized command\n"

    end
  end

  def check_cache
    @cached_files.each do |cached|
      file_server_connection = TCPSocket.open cached.server_host,cached.server_port
      file_server_connection.puts "PING\nFILE: #{cached.name}\nTIME: #{cached.time}\n\n"
      resp = file_server_connection.gets("\n\n")

      if /\AINVALIDATE CACHE\n\n/ === resp
        @cached_files.delete(cached)
      end
    end
  end

  def lookup_locked(filename)
    @locked_files.each do |locked|
      if locked[0].include?(filename)
        return locked
      end
    end
    nil
  end

  def lookup_cache(filename)
    @cached_files.each do |cached|
      if cached.name.include?(filename)
        return cached
      end
    end
    nil
  end
end


class ClientFile
  @name
  @server_id
  @server_port
  @server_host
  @time
  @data

  attr_accessor :name,:server_host,:server_port,:time,:data

  def initialize (name,server_id,server_port,server_host,time,data)
    @name = name
    @server_id = server_id
    @server_port = server_port
    @server_host = server_host
    @time = time
    @data = data
  end
end

ClientStub.new