# ---- g95 + openmpi @ clip --------- 
MPI=/opt/mpi/openmpi-1.2.6_g95
COMPILER=ifort
#COMPILER=g95
OPTIMIZATION=-openmp -O2 -cpp -fpe0 # -traditional-cpp -ffree-line-length-huge -fsloppy-char -fzero -fbounds-check
#OPTIMIZATION=-openmp -O0 -g -traceback -check bounds
#OPTIMIZATION=-C -O0 -check all -debug -traceback -fpe0 #-ftrace=full -traditional-cpp -ffree-line-length-huge -fsloppy-char -fzero -fbounds-check
#OPTIMIZATION=-O0 -g -fbounds-check -ftrace=full#-ftrace=full -traditional-cpp -ffree-line-length-huge -fsloppy-char -fzero -fbounds-check
#
MIKBUL=no
ifeq ($(MIKBUL),yes)
LINK_FLAGS=-L/usr/lib64 -L$(MPI)/lib -I$(MPI)/include   
DYNAMIC_LINK_FLAGS=-lopen-pal -lmpi -lmpi_f90 -lmpi_f77 -lmpi_cxx
ISMIKBUL= -DMIKBUL
endif

all: UriLight.exe

OBJ= globals.o physical_constants.o arrays.o general_functions.o transport_general_functions.o radioactive_decay.o randomnumbers.o mesh.o gammatransfer.o uvoirtransfer.o diagnostics.o gamma_physics.o atomic_physics.o uvoir_physics.o

UriLight.exe: $(OBJ) UriLight.o
	$(COMPILER) $(OPTIMIZATION) -o UriLight.exe UriLight.o $(OBJ) $(LINK_FLAGS) $(DYNAMIC_LINK_FLAGS) $(ISMIKBUL)
globals.o: globals.f90 
	$(COMPILER) $(OPTIMIZATION) -c globals.f90

physical_constants.o: physical_constants.f90 
	$(COMPILER) $(OPTIMIZATION) -c physical_constants.f90

randomnumbers.o: randomnumbers.f90 physical_constants.o
	$(COMPILER) $(OPTIMIZATION) -c randomnumbers.f90

arrays.o: arrays.f90 globals.o randomnumbers.o
	$(COMPILER) $(OPTIMIZATION) -c arrays.f90

general_functions.o: general_functions.f90 
	$(COMPILER) $(OPTIMIZATION) -c general_functions.f90

radioactive_decay.o: radioactive_decay.f90 randomnumbers.o physical_constants.o
	$(COMPILER) $(OPTIMIZATION) -c radioactive_decay.f90

atomic_physics.o: atomic_physics.f90 physical_constants.o general_functions.o
	$(COMPILER) $(OPTIMIZATION) -c atomic_physics.f90

mesh.o: mesh.f90 general_functions.o randomnumbers.o physical_constants.o globals.o atomic_physics.o
	$(COMPILER) $(OPTIMIZATION) -c mesh.f90

transport_general_functions.o: transport_general_functions.f90 mesh.o general_functions.o randomnumbers.o physical_constants.o globals.o
	$(COMPILER) $(OPTIMIZATION) -c transport_general_functions.f90

diagnostics.o: diagnostics.f90 mesh.o general_functions.o arrays.o globals.o
	$(COMPILER) $(OPTIMIZATION) -c diagnostics.f90

gamma_physics.o: gamma_physics.f90 physical_constants.o
	$(COMPILER) $(OPTIMIZATION) -c gamma_physics.f90

uvoir_physics.o: uvoir_physics.f90 physical_constants.o atomic_physics.o
	$(COMPILER) $(OPTIMIZATION) -c uvoir_physics.f90

gammatransfer.o: gammatransfer.f90 globals.o arrays.o general_functions.o transport_general_functions.o radioactive_decay.o randomnumbers.o mesh.o diagnostics.o gamma_physics.o
	$(COMPILER) $(OPTIMIZATION) -c gammatransfer.f90

uvoirtransfer.o: uvoirtransfer.f90 globals.o arrays.o general_functions.o transport_general_functions.o radioactive_decay.o randomnumbers.o mesh.o diagnostics.o atomic_physics.o physical_constants.o uvoir_physics.o
	$(COMPILER) $(OPTIMIZATION) -c uvoirtransfer.f90

UriLight.o: UriLight.f90 $(OBJ)
	$(COMPILER) $(OPTIMIZATION) -c UriLight.f90

clean:
	 \rm fort.* out profile-* totals spectrum_uvoir luminocity ejecta_profile run.e* run.o* magnitude
clean_all:
	 \rm *.o fort.* out profile-* totals spectrum_uvoir luminocity ejecta_profile run.e* run.o* magnitude

