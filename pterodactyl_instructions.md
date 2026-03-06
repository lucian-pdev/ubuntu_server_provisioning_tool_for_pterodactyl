# Using pterodactyl
###############################################################
###                 Terminology                            ###
###############################################################

Panel — This refers to Pterodactyl Panel itself, and is what allows you to add additional nodes and servers to the system.

Node — A node is a physical machine that runs an instance of Wings.

Wings — The newer service written in Go that interfaces with Docker and the Panel to provide secure access for controlling servers via the Panel.

Server — In this case, a server refers to a running instance that is created by the panel. These servers are created on nodes, and you can have multiple servers per node.

Docker — Docker is a platform that lets you separate the application from your infrastructure into isolated, secure containers.

Docker Image — A Docker image contains everything needed to run a containerized application. (e.g. Java for a Minecraft Server).

Container — Each server will be running inside an isolated container to enforce hardware limitations (such as CPU and RAM) and avoid any interference between servers on one node. These are created by Docker.

Nest — Each nest is usually used as a specific game or service, for example: Minecraft, Teamspeak or Terraria and can contain many eggs.

Egg — Each egg is usually used to store the configuration of a specific type of game, for example: Vanilla, Spigot or Bungeecord for Minecraft.

Yolks — A curated collection of core docker images that can be used with Pterodactyl's Egg system.

###############################################################
###                 WARNINGS                                ###
###############################################################

WARNING: Do NOT port-forward the panel. It is meant for LAN access only.
Only forward game server ports.

lucian-pdev, the pterodactyl and ubuntu teams do not take any responsability for your security.

Make sure your PC and the server are on the same LAN/subnet.

IMPORTANT: Your panel admin password and your SSH password are setup by the ISO bundling script.
If you forgot what you wrote there, 
the simplest method is to make a new ISO, make sure to write your credentials and reinstall the OS.
Pen and paper are still saving time in the 21st century.

###############################################################
###                 Setup steps                             ###
###############################################################

### NOTICE: This system assumes the server will be provided an IPv4 local IP subjected to NAT on the local router.
If you wish to use IPv6, NAT is "mostly" redundant so replace all entries with the static IPv6 you wish to assign.

1. a. access from CLI     # for situations where machine access is needed
ssh <your_ssh_username>@<machine_ip>
password: <your_ssh_password>

1. b. access from webpage # the main access to the app
web browser -> access [IP_of_machine] directly
login with '<your_panel_admin_username>' and '<your_panel_admin_password>'

1. c. click on "admin menu", the cogweel (settings) in the top right.

2. Create the Nodes:
Management -> Locations -> Create new --> any description, it's to create logical separation
Nodes -> Create node --> \
Name: [anything]
FQDN: [lan_IP_address]
Communicate Over SSL: Use HTTP Connection

Total Memory: [the RAM that Pterodactyl is allowed to use for all servers on the MACHINE ] 
    # watch out to allow enough for OS, Ptero and it's dependencies.
Total Disk Space: [the storage space alloted for all servers on the MACHINE]
    # limit in order to keep enough free for the rest of the systems, logs, Eggs etc.
    # remember NODE = physical machine

Overallocation for Memory and Disk Space: 0 will prevent creating new servers if it would put the node over the limit.

# the choice options will be reset if the creation errors for any reason, click them again before you save!

3. Configuring the node
Node -> choose yours -> configuration -> copy the config in the block

Open a powershell or linux terminal and 
$ ssh ubuntu@[local_ip_of_machine]
password is "user"

commands, after # are comments, do not copy comments:
$ sudo su                 # pass = user
$ cd /etc/pterodactyl

$ cat > config.yml << "EOF"           # this will either open a new line or hit enter to do so, depends on terminal
[paste the entire config block from the webpage here]
EOF                     # the signal of "this is where the document ends", do not put any spaces before or after EOF

$ systemctl restart wings

4. Allocate network ports
Go to Panel -> Nodes - > [Select yours] -> Allocation
Assign [local_ip address] and Ports [the_ports_required_by_your_game_server]
# Check the documentation of the software or the Egg you are using.

5. Download egg (config file)
https://github.com/pterodactyl/game-eggs/tree/main/

6. create new nest for [server_type]
Needs name and description, after that return to the overall Nests menu.

7. Import Egg file, upload your egg with the file browser, associate the egg to the nest and save

8. Creating the server:
Fill in:

    Name: [your choice here]

    Owner: admin

    Node: your node

    Allocation: pick [local_IP]:[port needed by your choice of server]  if not already set 

    Application feature : leave as is

    CPU: 0  # will automatically regulate

    Memory: 4096 or more

    Disk: 10000 or more

    Egg: [your choice] 

    Skip to Service Variables

        Server Name : testing-game_1 # this shows in the steam server browser!

        Server Password: [your choice]

        Public or private

Create the server.

9. Checking the status from the panel

Go to Servers -> Choose it -> 
at the top, in the row below the name of the server, where are "About, Manage, Delete and Symbol_to_open_in_new_tab" ->
Open then new tab

###############################################################
###                 Where to find logs                      ###
###############################################################

Checking server logs

If something doesn’t start correctly, you can check logs from the panel:

    Open the server in the panel

    Click Console

    The live output shows startup errors

# For deeper debugging:
# Shows Wings logs.
$ sudo journalctl -u wings -f

# Shows container logs.
$ docker ps
$ docker logs <container_id>

