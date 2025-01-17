################################################################################
##
## Filename:	Makefile
##
## Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
##
## Purpose:	A master project makefile.  It tries to build all targets
##		within the project, mostly by directing subdirectory makes.
##
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2019, Gisselquist Technology, LLC
##
## This program is free software (firmware): you can redistribute it and/or
## modify it under the terms of  the GNU General Public License as published
## by the Free Software Foundation, either version 3 of the License, or (at
## your option) any later version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
## for more details.
##
## You should have received a copy of the GNU General Public License along
## with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
## target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
##
## License:	GPL, v3, as defined and found on www.gnu.org,
##		http://www.gnu.org/licenses/gpl.html
##
##
################################################################################
##
##
.PHONY: all
all:	check-install archive datestamp rtl sim sw
# all:	datestamp archive rtl sw sim bench bit
#
# Could also depend upon load, if desired, but not necessary
BENCH := # `find bench -name Makefile` `find bench -name "*.cpp"` `find bench -name "*.h"`
SIM   := `find sim -name Makefile` `find sim -name "*.cpp"` `find sim -name "*.h"` `find sim -name "*.c"`
RTL   := `find rtl -name "*.v"` `find rtl -name Makefile`
NOTES := `find . -name "*.txt"` `find . -name "*.html"`
SW    := `find sw -name "*.cpp"` `find sw -name "*.c"`	\
	`find sw -name "*.h"`	`find sw -name "*.sh"`	\
	`find sw -name "*.py"`	`find sw -name "*.pl"`	\
	`find sw -name "*.png"`	`find sw -name Makefile`
DEVSW := `find sw/board -name "*.cpp"` `find sw/board -name "*.h"` \
	`find sw/board -name Makefile`
PROJ  :=
BIN   := 
AUTODATA := `find auto-data -name "*.txt"`
CONSTRAINTS := #
YYMMDD:=`date +%Y%m%d`
SUBMAKE:= $(MAKE) --no-print-directory -C
OCD := openocd
VERSACFG := ecp5-versa.cfg

#
#
# Check that we have all the programs available to us that we need
#
#
.PHONY: check-install
check-install: check-perl check-autofpga check-verilator check-gpp

.PHONY: check-perl
	$(call checkif-installed,perl,)

.PHONY: check-autofpga
check-autofpga:
	$(call checkif-installed,autofpga,-V)

.PHONY: check-verilator
check-verilator:
	$(call checkif-installed,verilator,-V)

.PHONY: check-gpp
check-gpp:
	$(call checkif-installed,g++,-v)

#
#
#
# Now that we know that all of our required components exist, we can build
# things
#
#
#
# Create a datestamp file, so that we can check for the build-date when the
# project was put together.
#
.PHONY: datestamp
datestamp: check-perl
	@bash -c 'perl mkdatev.pl > lastbuild.v'
	$(call copyif-changed,lastbuild.v,rtl/builddate.v)
	@grep "^.define" rtl/builddate.v

#
#
# Make a tar archive of this file, as a poor mans version of source code control
# (Sorry ... I've been burned too many times by files I've wiped away ...)
#
ARCHIVEFILES := $(BENCH) $(SW) $(RTL) $(SIM) $(NOTES) $(PROJ) $(BIN) $(CONSTRAINTS) $(AUTODATA) # README.md
.PHONY: archive
archive:
	tar --transform s,^,$(YYMMDD)-zipversa/, -chjf $(YYMMDD)-zipversa.tjz $(ARCHIVEFILES)

#
#
# Build our main (and toplevel) Verilog files via autofpga
#
.PHONY: autodata
autodata: datestamp check-autofpga
	$(SUBMAKE) auto-data
	$(call copyif-changed,auto-data/toplevel.v,rtl/toplevel.v)
	$(call copyif-changed,auto-data/main.v,rtl/main.v)
	$(call copyif-changed,auto-data/iscachable.v,rtl/iscachable.v)
	$(call copyif-changed,auto-data/build.lpf,rtl/zipversa.lpf)
	$(call copyif-changed,auto-data/regdefs.h,sw/host/regdefs.h)
	$(call copyif-changed,auto-data/regdefs.cpp,sw/host/regdefs.cpp)
	$(call copyif-changed,auto-data/board.h,sw/zlib/board.h)
	$(call copyif-changed,auto-data/board.h,sw/rv32/board.h)
	$(call copyif-changed,auto-data/board.ld,sw/board/board.ld)
	$(call copyif-changed,auto-data/bkram.ld,sw/board/bkram.ld)
	# $(call copyif-changed,auto-data/sdram.ld,sw/board/sdram.ld)
	$(call copyif-changed,auto-data/rtl.make.inc,rtl/make.inc)
	$(call copyif-changed,auto-data/testb.h,sim/verilated/testb.h)
	$(call copyif-changed,auto-data/main_tb.cpp,sim/verilated/main_tb.cpp)

#
#
# Verify that the rtl has no bugs in it, while also creating a Verilator
# simulation class library that we can then use for simulation
#
.PHONY: verilated
verilated: check-verilator
	+@$(SUBMAKE) rtl

.PHONY: rtl
rtl: verilated

#
#
# Build a simulation of this entire design
#
.PHONY: sim
sim: rtl check-gpp
	+@$(SUBMAKE) sim/verilated

#
#
# A master target to build all of the support software
#
.PHONY: sw
sw: sw-host sw-rv32
.PHONY: rv sw-rv
rv: sw-rv32
sw-rv: sw-rv32

#
#
# Build the host support software
#
.PHONY: sw-host
sw-host: check-gpp
	+@$(SUBMAKE) sw/host


#
#
# Build the hardware specific newlib library
#
.PHONY: sw-zlib
sw-zlib: check-zip-gcc
	+@$(SUBMAKE) sw/zlib

#
#
# Build the board software.  This may (or may not) use the software library.
# sw/board contains the software when using the ZipCPU
#
.PHONY: sw-board
sw-board: check-zip-gcc sw-zlib
	+@$(SUBMAKE) sw/board

# sw/rv32 contains the software when using the picoRV32
.PHONY: sw-rv32
sw-rv32:
	+@$(SUBMAKE) sw/rv32

#
# Load the design onto the board
#
.PHONY: load
load: rtl
	$(OCD) -f $(VERSACFG) -c "transport select jtag; init; svf rtl/zipversa.svf; exit"


#
#
# Copy a file from the auto-data directory that had been created by
# autofpga, into the directory structure where it might be used.
#
define	copyif-changed
	@bash -c 'cmp $(1) $(2); if [[ $$? != 0 ]]; then echo "Copying $(1) to $(2)"; cp $(1) $(2); fi'
endef

#
#
# Check if the given program is installed
#
define	checkif-installed
	@bash -c '$(1) $(2) < /dev/null >& /dev/null; if [[ $$? != 0 ]]; then echo "Program not found: $(1)"; exit -1; fi'
endef


.PHONY: clean
clean:
	+$(SUBMAKE) auto-data     clean
	+$(SUBMAKE) sim/verilated clean
	+$(SUBMAKE) rtl           clean
	+$(SUBMAKE) sw/zlib       clean
	+$(SUBMAKE) sw/board      clean
	+$(SUBMAKE) sw/host       clean
