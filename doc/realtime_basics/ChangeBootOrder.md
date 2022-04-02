# Changing kernel boot order

Author: [Tobit Flatscher](https://github.com/2b-t) (August 2021 - April 2022)



## 1. Changing the boot order in Grub

Likely after installing your new kernel you will want to boot automatically into the real-time kernel and not have to press `ESC` upon starting every single time. This can be done by **changing the Grub boot order** either [manually](https://askubuntu.com/a/110738) or by [using the graphical tool by Daniel Richter](https://askubuntu.com/a/100246) (recommended). Latter can be installed with the following commands

````sh
$ sudo add-apt-repository ppa:danielrichter2007/grub-customizer
$ sudo apt-get update
$ sudo apt-get install grub-customizer
````

and then launched

````sh
$ sudo grub-customizer
````

Select the desired kernel as default under `General/predefined`, close the GUI and restart your computer.
