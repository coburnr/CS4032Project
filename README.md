#CS4032 Project
*Student Name:* Robin Coburn

*Student Number:* 11534207

##Project Features
+   File server
+   Directory server
+   Lock server
+   Client-side caching

##Overview
Using the local filesystem with a "root" directory called "ServerFiles". Everything done on localhost. Directory server runs on port 80 and will startup 4 file servers on ports 81->84 
by default and 1 lock server running on port 79. Client stubs connect to directory server and request the directory server's 
working directory, the stub will then store this and use it for verifying directory navigation.

All clients run a stub which handles all client's interaction with the file system, clients interact with the stub 
using cd, ls, read, write, delete, lock, unlock commands and the stub makes connections to the directory server, file 
servers and lock server based on the client's input. All servers accept client connection, read & process the request, respond and finally close the connection. Client stubs 
therefore connect & disconnect from each server every time they need to interact with them.

##Directory Server
The directory server's main job is to distribute files around file servers and to direct clients to the file server 
containing the file that they want. It also gives the client a way of viewing file system contents and navigating throughout 
the file system.

On startup, the directory server runs 4 file servers then reads all files in all subfolders of the /ServerFiles 
directory and evenly distributes files to file servers. File servers then handle all client interaction with 
these files. On request of a file, the client stub will send a FILE request to the directory server, looking to find 
out connection details for the file server that is handling the file.

Clients can navigate through the file system using cd, view directory contents using ls and create new directories using crdir.
 This is handled by the client stub with
CD and LS requests to the directory server which contain the client's current directory according to their stub and 
the directory they want to navigate to/view the contents of. The client must be in the same directory as a file in order 
for their FILE request to succeed as this also uses the client's current directory to locate the file.

Directory server also handles lock requests by checking with the lock server if the file can be locked and if so, giving the 
client connection details to the locking server to handle the lock. If another client requests a file that has been locked 
the directory server will ask the lock server if the file is locked and if so, notify the requesting client.

##File Server
File servers handle all read, write, delete & cache verification for the files they they are assigned to handle by the 
directory server. These also take a NEW request to create a new file, but it's the same thing as a WRITE so it's assumed 
if clients want to make a new file they'll know to just make a new one by writing to it, instead of explicitly asking for an empty file. 
When a new file is created the directory server will assign it to a file server randomly(hopefully evenly-ish distributed) and the file server
will then handle the file from then on.

There isn't much else to say about the file servers. Read, write, delete requests are fairly self explanatory. Cache 
verification will be discussed later-on. 

##Lock Server
The lock server produces tokens that are used as locks. When a client requests to lock a file, the directory server will 
tell the lock server to generate a token and store it. The directory server then responds with the locking server's connection 
details and the token it has generated. From then on any attempted writes to the file will be blocked unless the client can 
connect to the lock server and verify the token with it. Other clients can still read locked files but do not have permission 
to write to them.

Unlock requests are handled by the lock server which will invalidate & remove the token & notify the directory server. For all interaction 
with the lock server the client must hold a valid lock for the file it's requesting. Although hopefully clients will unlock files when they are
finished with them, the locks only last for 5 minutes. This is done by recording the time on the lock server that the lock is obtained 
and every 3 seconds checking to see if 5 minutes is up. When 5 minutes are up the lock is invalidated & destroyed as if the client had sent an 
unlock request. Therefore if a client wants extended exclusive access to a file, it must lock the file once every 5 minutes. This is a worst-case 
scenario however and ideally clients will just unlock files when they are done with them.

##Client-side Caching
Client-side caching is implemented in the client stub. If the client requests to read a file the file is stored in the stub and every 10 seconds the 
stub will ping the file server who is in charge of the file to verify that it's cached copy is still valid. If a file is changed on the file server 
it will respond to a ping with an INVALIDATE CACHE command to the stub, which then removes the file from the cache and if it is requested again will need 
to contact the server to get an up to date copy. If no invalidate cache message is recieved then the cached file is still considered to be 
up to date and will therefore be served to the client if they request it again, instead of making a fresh connection to the file server.



