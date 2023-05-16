#coded by winteriscomingimport
import sys
import os


print ("started romsize script...")

filename=sys.argv[1]
print ("Rom name is: " + filename)



filesize = os.path.getsize(filename)

print ("Filesize is: " + str(filesize))


Mib= 131072
maxSize=0

if filesize<=Mib*4:
    maxSize=Mib*4
    i=filesize
    print("Starting here: " + str(i))
    print("Going to here: " + str(maxSize))
    f = open(filename,'a+b')
    while i<maxSize:
        f.write(bytes([0xFF]))
        i=i+1
    f.close()
    filesize = os.path.getsize(filename)
    print ("Filesize is now: " + str(filesize))
elif filesize<=Mib*8:
    maxSize=Mib*8
    i=filesize
    print("Starting here: " + str(i))
    print("Going to here: " + str(maxSize))
    f = open(filename,'a+b')
    while i<maxSize:
        f.write(bytes([0xFF]))
        i=i+1
    f.close()
    filesize = os.path.getsize(filename)
    print ("Filesize is now: " + str(filesize))
elif filesize<=Mib*16:
    maxSize=Mib*16
    i=filesize
    print("Starting here: " + str(i))
    print("Going to here: " + str(maxSize))
    f = open(filename,'a+b')
    while i<maxSize:
        f.write(bytes([0xFF]))
        i=i+1
    f.close()
    filesize = os.path.getsize(filename)
    print ("Filesize is now: " + str(filesize))
elif filesize<=Mib*32:
    maxSize=Mib*8
    i=filesize
    print("Starting here: " + str(i))
    print("Going to here: " + str(maxSize))
    f = open(filename,'a+b')
    while i<maxSize:
        f.write(bytes([0xFF]))
        i=i+1
    f.close()
    filesize = os.path.getsize(filename)
    print ("Filesize is now: " + str(filesize))


print ("End size is: " + str(filesize/Mib)+ "Mib")
