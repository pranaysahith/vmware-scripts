import os
import fileinput
file = open("servers.txt","r")
names = []
ips = []
port = []
for line in file:
    splitLine = line.split(",")
    names.append(splitLine[0])
    ips.append(splitLine[1].strip())
    port.append(splitLine[2].strip())
file.close()

servers = []
for x, y, z in zip(names, ips, port):
    servers.append("  server " + x + " " + y + ":" + z + " check")

servers_list = servers[0:]
new_servers = "\n".join(servers_list)

tmp_file = open("haproxy.tmp", "r")
content = tmp_file.readlines()
tmp_file.close()
content.insert(45, new_servers)
tmp_file = open("/etc/haproxy/haproxy.cfg", "w")
content = "".join(content)
tmp_file.write(content)
tmp_file.close()
os.system("sudo /etc/init.d/haproxy reload")
os.system("sudo /etc/init.d/haproxy status | head -11")