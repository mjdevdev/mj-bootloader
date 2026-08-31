# Supporting 16 bit bootloaders build onlt, for now
# This makefile is fed into gemini for improvements and safety. You may use it safely.

BINS := stage1.bin stage2.bin
HOST_DISK := $(shell lsblk -no PKNAME $$(findmnt -n -o SOURCE /) | sed 's|^|/dev/|')
TEST_DISK := gpt-test.iso#alpine-standard-3.24.1-x86_64.iso
MJ_PART_ID := C06CDA0D-65B5-49C7-A954-54594723C555



MJ_FIRST_PART_TEST = $(shell sfdisk --dump $(TEST_DISK) 2>/dev/null | grep $(MJ_PART_ID) | awk '{print $$1}')
MJ_FIRST_PART = $(shell sudo sfdisk --dump $(HOST_DISK) 2>/dev/null | grep $(MJ_PART_ID) | awk '{print $$1}')

all: $(BINS)
	@echo "Safe build complete. Run 'make test' or 'make install' explicitly to burn bootloaders."

#TODO: write windows version of bootloader installer, with GUI

test: $(BINS) #currently only testing on gpt disks, later will add mbr support 
	@echo "Testing bootloader burn on $(TEST_DISK)..."
	@DISKTYPE=$$(sfdisk --dump $(TEST_DISK) | grep label: | awk '{print $$2}') ;\
	echo "Copying stage 1 bootloader..." ;\
	dd if=stage1.bin of=$(TEST_DISK) bs=1 count=446 conv=notrunc; \
	echo "Disk type: " $$DISKTYPE; \
	echo "Running stage 2 copy.."; \
	if [ "$$DISKTYPE" = "dos" ]; then \
		FIRST_PART_START=$$(sfdisk $(TEST_DISK) -d | awk '$$1 == "device:" {dev = $$2} dev && $$0 ~ "^" dev "[0-9p]" {print; exit}' | awk -F',|=' '{print $$2}') ; \
		if [ "$$FIRST_PART_START" -lt 63 ]; then \
			echo "ERROR: the first partition of $(TEST_DISK) leaves less than 62 sectors for bootloader (starting at sector $$FIRST_PART_START)"; \
			exit 1; \
		fi; \
		dd if=/dev/zero of=$(TEST_DISK) seek=1 bs=512 count=62 conv=notrunc; \
		dd if=stage2.bin of=$(TEST_DISK) seek=1 conv=notrunc; \
		echo "Successfully written stage 2 to mbr bootloader gap."; \
		exit 0; \
	elif [ "$$DISKTYPE" != "gpt" ]; then \
		echo "ERROR: unsupported disk type, neither gpt nor mbr."; \
		exit 1; \
	fi; \
	PART="$(MJ_FIRST_PART_TEST)"; \
	if [ -z "$$PART" ]; then \
		echo "Partition missing. Creating partition..." ; \
		echo ",2M,$(MJ_PART_ID)," | sfdisk --append $(TEST_DISK) ; \
		PART=$$(sfdisk --dump $(TEST_DISK) | grep $(MJ_PART_ID) | awk '{print $$1}') ; \
	fi; \
	if [ -z "$$PART" ]; then \
		echo "ERROR: Failed to create or find test partition! Aborting stage2 write." >&2; exit 1; \
	fi; \
	echo "Writing stage2 to $$PART..."; \
	SEEK_SECTOR=$$(sfdisk $(TEST_DISK) -l | grep "$$PART" | awk '{print $$2}'); \
	dd if=/dev/zero of=$(TEST_DISK) seek=$$SEEK_SECTOR bs=512 count=62 conv=notrunc; \
	dd if=stage2.bin of=$(TEST_DISK) seek=$$SEEK_SECTOR conv=notrunc; \
	echo "Successfully written stage 2 to $(TEST_DISK) in partition $$PART"


install: $(BINS) #currently only testing on gpt disks, later will add mbr support 
	@echo "WARNING: You are writing directly to a hardware drive $(HOST_DISK) and burning bootloader on it."
	@echo "You might brick your device. Press any other keys to abort, or y/Y to continue..."; \
	read CONFIRM; \
	if [ "$$CONFIRM" != "y"  ] && [ "$$CONFIRM" != "Y" ]; then \
		echo aborting.; \
		exit 0; \
	fi; \
	echo "Requesting sudo permissions for disk analysis..."; \
	sudo -v || exit 1; \
	echo "Burning to your disk:$(HOST_DISK)..."; \
	DISKTYPE="$$(sudo sfdisk --dump $(HOST_DISK) | grep label: | awk '{print $$2}')";\
	echo "Copying stage 1 bootloader..." ; \
	sudo dd if=stage1.bin of=$(HOST_DISK) bs=1 count=446 conv=notrunc; \
	echo "Disk type: " $$DISKTYPE; \
	echo "Running stage 2 copy.."; \
	if [ "$$DISKTYPE" = "dos" ]; then \
		FIRST_PART_START=$$(sudo sfdisk $(HOST_DISK) -d | awk '$$1 == "device:" {dev = $$2} dev && $$0 ~ "^" dev "[0-9p]" {print; exit}' | awk -F',|=' '{print $$2}') ; \
		if [ "$$FIRST_PART_START" -lt 63 ]; then \
			echo "ERROR: the first partition of $(HOST_DISK) leaves less than 62 sectors for bootloader (starting at sector $$FIRST_PART_START)"; \
			exit 1; \
		fi; \
		sudo dd if=/dev/zero of=$(HOST_DISK) seek=1 bs=512 count=62 conv=notrunc; \
		sudo dd if=stage2.bin of=$(HOST_DISK) seek=1 conv=notrunc; \
		echo "Successfully written stage 2 to mbr bootloader gap."; \
		exit 0; \
	elif [ "$$DISKTYPE" != "gpt" ]; then \
		echo "ERROR: unsupported disk type, neither gpt nor mbr."; \
		exit 1; \
	fi; \
	PART="$(MJ_FIRST_PART)"; \
	if [ -z "$$PART" ]; then \
		echo "Partition missing. Creating partition..." ; \
		echo ",2M,$(MJ_PART_ID)," | sfdisk --append $(HOST_DISK) ; \
		PART=$$(sudo sfdisk --dump $(HOST_DISK) | grep $(MJ_PART_ID) | awk '{print $$1}') ; \
	fi; \
	if [ -z "$$PART" ]; then \
		echo "ERROR: Failed to create or find test partition! Aborting stage2 write." >&2; exit 1; \
	fi; \
	echo "Writing stage2 to $$PART..."; \
	SEEK_SECTOR=$$(sudo sfdisk $(HOST_DISK) -l | grep "$$PART" | awk '{print $$2}'); \
	sudo dd if=/dev/zero of=$(HOST_DISK) seek=$$SEEK_SECTOR bs=512 count=62 conv=notrunc; \
	sudo dd if=stage2.bin of=$(HOST_DISK) seek=$$SEEK_SECTOR conv=notrunc; \
	echo "Successfully written stage 2 to $(HOST_DISK) in partition $$PART"

# To enable production install, remove the '#' symbol from the start of the lines below:
# install: $(BINS)
# 	@echo "WARNING: You are writing directly to your host OS drive!"
# 	@echo "Press Ctrl+C to abort, or Enter to continue..."; read _
# 	HOST_DISK=$$(lsblk -no PKNAME $$(findmnt -n -o SOURCE /) | sed 's|^|/dev/|'); \
# 	if [ -z "$$HOST_DISK" ]; then echo "ERROR: Could not find host disk!" >&2; exit 1; fi; \
# 	sudo dd if=stage1.bin of=$$HOST_DISK bs=1 count=446 status=progress conv=notrunc; \
# 	PART="$(MJ_FIRST_PART)"; \
# 	if [ -z "$$PART" ]; then \
# 		echo ",2M,$(MJ_PART_ID)," | sudo sfdisk --append $$HOST_DISK; \
# 		PART=$$(sudo sfdisk --dump $$HOST_DISK | grep $(MJ_PART_ID) | awk '{print $$1}'); \
# 	fi; \
# 	if [ -z "$$PART" ]; then echo "ERROR: Partition target resolution failed!" >&2; exit 1; fi; \
# 	sudo dd if=stage2.bin of=$$PART status=progress

$(BINS): %.bin: %.asm
	nasm $^ -o $@ -f bin

#ifeq ($(MJ_FIRST_PART),)
#INSTALL: $(BINS)
#	@echo "UNDER TESTING.."
#	sudo dd if=stage1.bin of=$$(lsblk -no PKNAME $$(findmnt -n -o SOURCE /) | sed 's|^|/dev/|') bs=1 count=446 status=progress conv=notrunc
#	echo ",2M,$(MJ_PART_ID)," | sudo sfdisk --append $$(lsblk -no PKNAME $$(findmnt -n -o SOURCE /) | sed 's|^|/dev/|')
#else
#INSTALL: $(BINS)
#	@echo "UNDER TESTING.."
#	sudo dd if=stage1.bin of=$$(lsblk -no PKNAME $$(findmnt -n -o SOURCE /) | sed 's|^|/dev/|') bs=1 count=446 status=progress conv=notrunc
#	sudo dd if=stage2.bin of=$(MJ_FIRST_PART) status=progress
#endif

BINS := stage1.bin stage2.bin

#ALL: $(BINS) 
#	@echo in progress

#iso: $(BINS) # like a bootable usb stick with bootloader only, used to rescue your device and force install bootloader
	

$(BINS): %.bin: %.asm #nasm only
	nasm $^ -o $@ -f bin		

#
#
# TEST_DISK := alpine-standard-3.24.1-x86_64.iso
# 
# MJ_PART_ID := C06CDA0D-65B5-49C7-A954-54594723C555
# 
# MJ_FIRST_PART = $(shell sudo sfdisk --dump `lsblk -no PKNAME $(findmnt -n -o SOURCE /) | sed 's|^|/dev/|'` | grep $(MJ_PART_ID) | awk '{print $1}')
# 
# MJ_FIRST_PART_TEST = $(shell sfdisk --dump $(TEST_DISK) | grep $(MJ_PART_ID) | awk '{print $1}')
# 
# # ,2M,$(MJ_PART_ID),
# 
# all: INSTALL_TEST #DANGEROUS
# 
# ifeq ($(MJ_FIRST_PART_TEST),)
# INSTALL_TEST: $(BINS)
# 	dd if=stage1.bin of=$(TEST_DISK) bs=1 count=446 status=progress conv=notrunc
# 	echo ",2M,$(MJ_PART_ID)," | sfdisk --append $(TEST_DISK)
# 	dd if=stage2.bin of=$(MJ_FIRST_PART_TEST) status=progress
# else
# INSTALL_TEST: $(BINS)
# 	dd if=stage1.bin of=$(TEST_DISK) bs=1 count=446 status=progress conv=notrunc
# 	dd if=stage2.bin of=$(MJ_FIRST_PART_TEST) status=progress
# endif
# 
# #ifeq ($(MJ_FIRST_PART),)
# #INSTALL: $(BINS)
# #	@echo "UNDER TESTING.."
# #	sudo dd if=stage1.bin of=$$(lsblk -no PKNAME $$(findmnt -n -o SOURCE /) | sed 's|^|/dev/|') bs=1 count=446 status=progress conv=notrunc
# #	echo ",2M,$(MJ_PART_ID)," | sudo sfdisk --append $$(lsblk -no PKNAME $$(findmnt -n -o SOURCE /) | sed 's|^|/dev/|')
# #else
# #INSTALL: $(BINS)
# #	@echo "UNDER TESTING.."
# #	sudo dd if=stage1.bin of=$$(lsblk -no PKNAME $$(findmnt -n -o SOURCE /) | sed 's|^|/dev/|') bs=1 count=446 status=progress conv=notrunc
# #	sudo dd if=stage2.bin of=$(MJ_FIRST_PART) status=progress
# #endif
# 
# BINS := stage1.bin stage2.bin
# 
# #ALL: $(BINS) 
# #	@echo in progress
# 
# #iso: $(BINS) # like a bootable usb stick with bootloader only, used to rescue your device and force install bootloader
# 	
# 
# $(BINS): %.bin: %.asm #nasm only
# 	nasm $^ -o $@ -f bin		
# 
# #stage1.bin:
# #	nasm stage1.asm -o stage1.bin -f bin
# ==============================================================================
