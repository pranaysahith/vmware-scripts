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
servers = "\n".join(servers)
template_file = open("haproxy.tmp", "r")
content = template_file.readlines()
template_file.close()
content.insert(45, servers)
generated_file = open("/etc/haproxy/haproxy.cfg", "w")
content = "".join(content)
generated_file.write(content)
generated_file.close()
os.system("sudo /etc/init.d/haproxy reload")
os.system("sudo /etc/init.d/haproxy status | head -11")