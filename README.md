# Zorecom
Simple remote management virtualbox command tool based on zenity.

# Usage
Since the script does not use <code>sshpass</code> or <code>expert script</code>, please use ssh-copy-id or manually set the openssh authorization before using it.

<code>bash$ ./zorecom</code>

# Implements
* Add remote host <code>user password ip port</code>
* Empty one or more remote hosts and the Virtualbox Vm present on the host
* Add Vitualbox Vm to one or more remote hosts
* View the Virtualbox Vm that exists on one or more remote hosts.<br/>
<code>Name Status System Type Number of CPUs Memory Size Remote Host Address</code>
* Start, stop, pause, resume, restart, Virtualbox Vm on one or more remote hosts
* Take snapshots and screenshots of vmm on one or more remote hosts
* Restore a snapshot (not completed)
* Batch configuration changes to vm on multiple remote hosts

# Example
##### Add new a remote host
![Add new remote host](https://i.imgur.com/rXUCTH2.png)
##### Select one or more remote hosts to execute the command
![Select one or more remote hosts to execute the command](https://i.imgur.com/JPdKhmC.png)
##### View Virtualbox vm that exist on multiple remote hosts
![Imgur](https://i.imgur.com/3pBUZwj.png)

##### Take a screenshot of one or more remote Virtualbox vm
![Imgur](https://i.imgur.com/4Ew580l.png)

##### Create a remote Virtualbox vm
![Imgur](https://i.imgur.com/6b9lkii.png)<br/>
![Imgur](https://i.imgur.com/m2bsvEW.png)<br/>
![Imgur](https://i.imgur.com/2JdlIYP.png)

##### Restart a remote Virtualbox vm

![Imgur](https://i.imgur.com/0iTDnSg.png)
# License
This project is licensed under the GNU General Public License v3.0 - see the [LICENSE.md](https://github.com/ZoZhang/Zorecom/blob/master/LICENSE) file for details

