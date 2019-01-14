      Module UvoirTransfer
      use globals
      use physical_constants
      use arrays
      use general_functions
      use Atomic_Physics
      use Uvoir_Physics
      use transport_general_functions
      use radioactive_decay
      use RandomNumbers
      use Mesh
      use diagnostics
      implicit none

      real(8) , save :: Esource,EpelletUvoir
      integer , save :: nphotons

      integer , allocatable , save :: Ncreate(:) , Nleak(:) , Nprob(:)

      contains

      subroutine init_uvoir
      integer :: i,j,k,nt,totpel,ino,dn,bin_type,seedsize
      real(8) :: lmin,lmax,deltal,deltav,qv
      real(8) :: ein,z
      namelist /uvoir/ N_UvoirPellets,lmin,lmax,deltal,nwavelengths,deltav,bin_type

!!    default
      spect_type_uvoir=2 !! bins by lambda 

      bin_type=1
      lmin=10.0d0
      lmax=30000.0d0
      deltal=-1.0d0
      nwavelengths=500
      deltav=-1.0d0

      open(unit=5,file=data_file)
      read(5,nml=uvoir,iostat=ino)
      close(5)

      if (bin_type.eq.1) then
        if (deltal.gt.0.0d0) then
          nwavelengths=nint(dble(lmax-lmin)/dble(deltal))
          lmax=lmin+deltal*nwavelengths
        else
          qv=(lmax/lmin)**(1.0d0/dble(nwavelengths))
        endif
        allocate (spect_bins_uvoir(nwavelengths+1))
        do i=1,nwavelengths+1
          spect_bins_uvoir(i)=lmin+(lmax-lmin)/dble(nwavelengths)*dble(i-1)
        enddo
        write(fout,*) 'Using constant wavelength binning'
      elseif(bin_type.eq.2) then
        if (deltav.gt.0.0d0) then
          qv=1.0d0+deltav/clight
          nwavelengths=nint(1.0d0+log(lmax/lmin)/log(qv))-1
          lmax=lmin*qv**dble(nwavelengths)
        else
          qv=(lmax/lmin)**(1.0d0/dble(nwavelengths))
        endif
        allocate (spect_bins_uvoir(nwavelengths+1))
        do i=1,nwavelengths+1
          spect_bins_uvoir(i)=lmin*qv**dble(i-1)
        enddo
        write(fout,*) 'Using constant velocity wavelength binning'
        write(fout,1000) lmin,lmin*qv**nwavelengths,nwavelengths
1000    format ('Lmin=',1pe10.2,' Lmax=',1pe10.2,' Nwavelengths=',I6)
      endif

      write(fout,nml=uvoir)

      spect_bins_uvoir(:)=spect_bins_uvoir(:)*angstrom
      allocate(dspect_bins_uvoir(nwavelengths))
      dspect_bins_uvoir(:)=spect_bins_uvoir(2:nwavelengths+1)-spect_bins_uvoir(1:nwavelengths)

      allocate (jnudnu(nctot),nujnudnu(nctot),edep(nctot),esca(nctot))
      allocate (temp(nctot),temp_old(nctot))
      allocate (trad(nctot),tcolor(nctot),tplasma(nctot))
      allocate (kappa_abs(nctot),kappa_scat(nctot))
      allocate (nelec(nctot),zavg(nctot))
      allocate (alpha_scat(nctot),alpha_ff(nwavelengths,nctot))
      allocate (alpha_abs_exp(nwavelengths,nctot),alpha_scat_exp(nwavelengths,nctot))
      allocate (emissivity(nwavelengths,nctot))
      allocate (ntracks(nctot))
      allocate (Ncreate(0:ntimes),Nleak(ntimes),Nprob(ntimes))
      allocate (spect_uvoir(nwavelengths,ntimes))
      allocate (bp(nwavelengths,nctot))
      ncreate=0
      nleak=0
      nprob=0
      ntracks=0
      jnudnu=0.0d0
      nujnudnu=0.0d0
      edep=0.0d0
      esca=0.0d0
      temp=0d0
      temp_old=temp
      trad=0.0d0
      tcolor=0.0d0
      tplasma=0.0d0
      nelec=0.0d0
      zavg=0.0d0
      kappa_abs=0.0d0
      kappa_scat=0.0d0
      spect_uvoir=0.0d0
      alpha_scat=0.0d0
      alpha_ff=0.0d0
      alpha_abs_exp=0.0d0
      alpha_scat_exp=0.0d0
      bp=0.0d0
      emissivity=0.0d0


      totpel=0

      Esource=0.0d0
      do nt=1,ntimes
        Esource=Esource+sum(Edep_gamma(nt,:))+sum(Edep_pos(nt,:))
        write(fout,1001) nt,sum(Edep_gamma(nt,:)),sum(Edep_pos(nt,:))
      enddo
1001  format('time step=',I3,' Gamma deposition=',1pe10.2,&
             ' ergs , Positron deposition=',1pe10.2,' ergs')
      write(fout,*) 'UVOIR Source=',Esource

      do nt=1,ntimes
        do k=1,nc3
          do j=1,nc2
            do i=1,nc1
              ein=Edep_gamma(nt,ind(i,j,k))+Edep_pos(nt,ind(i,j,k))
              dn=nint(N_UvoirPellets*ein/Esource)
              totpel=totpel+dn
              ncreate(nt)=ncreate(nt)+dn
            enddo
          enddo
        enddo
      enddo
      write(fout,*) 'ncreate=',ncreate

      write(fout,*) 'UVOIR Npellets=',totpel
      EpelletUvoir=Esource/totpel
      write(fout,*) 'UVOIR Epellet=',EpelletUvoir

      allocate(photon(totpel))
      nphotons=totpel

!     seedsize=n_uvoirpellets*10+nctot*10
! last +10 in next line is for 'safety'
!     seedsize=4*(n_uvoirpellets+10)
!     allocate (nseeds(seedsize))
!     do i=1,seedsize
!       call random_number(z)
!       nseeds(i)=int(z*2147483579d0)
!     enddo

      return
      end subroutine init_uvoir

      subroutine uvoir_transport
      integer :: i,j,k,nt,np,npellets,ip,jp,kp,ierr,iphotons,nb,seedcount,myseednum
      logical :: fineiter
      logical :: inmesh,intime,isabs,isprob
      type (epacket) :: p_old
      real(8) :: nions(0:max_ion_levels,niso)
      real(8) :: partition(0:max_ion_levels,niso)
      integer :: niter,ndep,nout,nsim,ndirect,nscat,ndirectp,nscatp
      real(8) :: ne,Etotm,vm(3),conv,converge,converge1,totatoms,&
                 vol,fnorm,edot,reslow,reshigh,kappa,ein
      logical :: idiag
      character*20 :: namef
      real(8) :: frac(niso)
      REAL(8) :: tm0, TM1 , TM2 , TM3 , TM4 , TM5, tm6
!     type(rng_t), allocatable :: rng(:)
      type(rng_t) :: rng
      real(8) :: z(3),q, zz
      real(8) :: jnudnup(nctot),nujnudnup(nctot),edepp(nctot),escap(nctot)
      integer :: ntracksp(nctot),nprobp,nleakp,nseeds(4)
      real(8) :: boloutp(Ntimes)
      real(8) :: uvoir_fp(Ntimes,8)
      INTEGER ::  NTHREADS, TID, OMP_GET_NUM_THREADS,OMP_GET_THREAD_NUM,numloop

!     allocate(rng(nphotons))


      nprob=0
!     nout=0
      ndep=0
      ndirect=0
      nscat=0
!     seedcount=0

!     frac=0.0d0
!     frac(ind_fe56)=1.0d0
!     call calc_Kasens_emissivity(1.d-10,2.0d0*day,frac,101)
!     call calc_Kasens_emissivity(1.d-14,40.0d0*day,frac,101)
!     frac=0.0d0
!     frac(ind_co56)=1.0d0
!     call calc_Kasens_emissivity(1.d-14,40.0d0*day,frac,102)
!     frac=0.0d0
!     frac(1)=0.7d0
!     frac(2)=0.3d0
!     call calc_Kasens_emissivity(1.d-14,40.0d0*day,frac,103)
!     frac=0.0d0
!     frac(ind_fe56)=0.24d0
!     frac(ind_co56)=0.75d0
!     frac(ind_ni56)=0.01d0
!     call calc_Kasens_emissivity(1.d-14,40.0d0*day,frac,104)

!     stop

!!!!! First define all source photons from Gamma-ray deposition
      iphotons=0
      do nt=1,ntimes
      enddo

!     first guess for temperature
      temp(:)=6.d4
      nelec(:)=0.0d0

!!!!! Main loop
      do nt=1,ntimes
          call cpu_time(tm0)
       write(99,*) 'begin timestep',nt
        fineiter=.false.
        niter=0
        write(fout,*  ) '----------------------------------------------'
        write(fout,600) nt,times(nt)/day,times(nt+1)/day

!!      change atoms array according to Ni56 decay chain
        do i=1,nctot
           totatoms=atoms(ind_fe56,i)+atoms(ind_co56,i)+atoms(ind_ni56,i)
           call Ni56DecayChain(totatoms,teff(nt),atoms(ind_ni56,i),atoms(ind_co56,i),atoms(ind_fe56,i))
        enddo

        do while (.not.fineiter)
          call cpu_time(tm1)
          niter=niter+1
          write(fout,401) niter
          edep(:)=0.0d0
          esca(:)=0.0d0
          jnudnu(:)=0.0d0
          nujnudnu(:)=0.0d0
          edepp(:)=0.0d0
          escap(:)=0.0d0
          jnudnup(:)=0.0d0
          nujnudnup(:)=0.0d0
          temp_old(:)=temp(:)

!$OMP PARALLEL  PRIVATE(I,nions,partition,fnorm,reslow,reshigh) SHARED(alpha_abs_exp,alpha_ff,emissivity)

!$OMP DO SCHEDULE(DYNAMIC,1)
          do i=1,nctot
!     calculate ionization levels and cross sections
            call sahaionization(atoms(1:niso,i)*rhooft(rhov(i),teff(nt)),iso(1:niso)%z, &
            temp(i),nelec(i),nions(0:max_ion_levels,1:niso), &
             partition(0:max_ion_levels,1:niso),zavg(i))

!     calculate opacities
            call calc_planck_int(bp(:,i),fnorm,reslow,reshigh,spect_bins_uvoir(:),temp(i))
            call calc_freefree_abs(alpha_ff(:,i),temp(i),nelec(i),&
                  nions(0:niso,1:max_ion_levels),spect_bins_uvoir(:))
            call expansion_opacity_LTE(alpha_abs_exp(:,i),alpha_scat_exp(:,i),teff(nt),temp(i),&
                 nions(0:max_ion_levels,1:niso),partition(0:max_ion_levels,1:niso),spect_bins_uvoir(:))

            alpha_scat(i)=sigma_thomson*nelec(i)

!           alpha_scat(i)=0.0d0
!           alpha_abs_exp(:,i)=0.0d0
!           alpha_scat_exp(:,i)=0.0d0
!           vol=1.0d0/rhooft(rhov(i),teff(nt))
!           alpha_ff(:,i)=0.1d0*mass(i)/vol

            emissivity(:,i)=(alpha_abs_exp(:,i)+alpha_ff(:,i))*bp(:,i)
            emissivity(:,i)=emissivity(:,i)/sum(emissivity(:,i))

          enddo
!$OMP END DO NOWAIT

!$OMP END PARALLEL
          call cpu_time(tm2)

!     UVOIR photons emsision due to gamma absorption and positron deposition at this timestep
!     emission is calculated every iterations due to changing in emissivity.
          iphotons=sum(ncreate(0:nt-1))
          do k=1,nc3
            do j=1,nc2
              do i=1,nc1
                ein=Edep_gamma(nt,ind(i,j,k))+Edep_pos(nt,ind(i,j,k))
                npellets=nint(N_UvoirPellets*ein/Esource)
                do np=1,npellets
                  iphotons=iphotons+1
!                 call rng_seed(rng, 932117 + seedcount+(k-1)*nc1*nc2+(j-1)*nc1+(i-1))
!                 myseednum=seedcount+(k-1)*nc1*nc2+(j-1)*nc1+(i-1)
!                 call rng_seed(rng,nseeds(4*(myseednum-1)+1:4*myseednum))
                  call random_number(zz)
                  nseeds(1)=int(zz*2147483579d0)
                  call random_number(zz)
                  nseeds(2)=int(zz*2147483579d0)
                  call random_number(zz)
                  nseeds(3)=int(zz*2147483579d0)
                  call random_number(zz)
                  nseeds(4)=int(zz*2147483579d0)
                  call rng_seed(rng,nseeds)
                  photon(iphotons)=new_uvoir(nt,i,j,k,EpelletUvoir,rng)
                enddo
              enddo
            enddo
          enddo
!         seedcount=seedcount+nc1*nc2*nc3

          ntracks(:)=0
          nsim=0
          nleak(nt)=0
          nprob(nt)=0
          nprobp=0
          nleakp=0

          if (niter.eq.2) fineiter=.true.

          call cpu_time(tm3)

          boloutp=0d0
          uvoir_fp=0d0
          ndirectp=0
          nscatp=0
          numloop=sum(ncreate(0:nt))

!         write(70,*) 'before photons, niter: ',niter
!         write(70,*) 'loop length is: ',sum(ncreate(0:nt))
!         write(70,*) ncreate(0:nt)

!$OMP PARALLEL PRIVATE(np,p_old,inmesh,intime,isabs,isprob,idiag,jnudnup,nujnudnup,edepp,escap,ntracksp,tid) SHARED(niter,ncreate)
!     Obtain and print thread id
!      TID = OMP_GET_THREAD_NUM()

!     Only master thread does this
!      IF (TID .EQ. 0) THEN
!        NTHREADS = OMP_GET_NUM_THREADS()
!        write(60,*) 'Number of threads = ', NTHREADS
!      END IF
!           write(60,*) niter


!$OMP DO SCHEDULE(DYNAMIC,1) REDUCTION(+:nsim,jnudnu,nujnudnu,edep,esca,ntracks,nprobp,nleakp,boloutp,uvoir_fp,ndirectp,nscatp) 

!         do np=1,sum(ncreate(0:nt))
          do np=1,numloop
!           write(60,*) np,niter
!      IF (TID .EQ. 0) THEN
!          write(97,*) np,niter
!           if(niter.eq.1) then
!            write(97,*) np
!            print*, niter, np
!           elseif(niter.eq.2) then
!            write(98,*) np
!            print*, niter, np
!           endif
!      END IF

            if (photon(np)%t.lt.times(nt+1) .and. photon(np)%active) then

              p_old=photon(np)

              nsim=nsim+1
              idiag=.false.
!             call rng_seed(rng, 932117 + seedcount + np)
!             myseednum=seedcount+np
!             call rng_seed(rng,nseeds(4*(myseednum-1)+1:4*myseednum))
!             call track_uvoir(photon(np),nt,inmesh,intime,isabs,isprob,idiag)
              call track_uvoir(photon(np),nt,inmesh,intime,isabs,isprob,idiag,jnudnup,nujnudnup,edepp,escap,ntracksp)
!             jnudnup=0d0
!             jnudnup(1)=1d0
!             jnudnup(3)=1d0
!             jnudnup(5)=1d0
              jnudnu=jnudnu+jnudnup
!             jnudnu=jnudnu+1d0
              nujnudnu=nujnudnu+nujnudnup
!             if(maxval(jnudnup).gt.0d0) write(80,*) 'got'
              edep=edep+edepp
              esca=esca+escap
              ntracks=ntracks+ntracksp

              if (fineiter) then
                if (isprob) then
                  nprobp=nprobp+1
                  photon(np)%active=.false.
                endif

                if (.not.inmesh) then
                  call integrate_bolometric(photon(np),boloutp,2)
                  call diag_integrate_uvoir_bands(photon(np),spect_bins_uvoir(:),uvoir_fp,2)
!                 call write_to_spectrum(photon(np),spect_uvoir,spect_bins_uvoir,spect_type_uvoir)

!                 nout=nout+1
                  nleakp=nleakp+1
                  photon(np)%active=.false.
                  if (photon(np)%direct) then
                    ndirectp=ndirectp+1
                  else
                    nscatp=nscatp+1
                  endif
                endif
              else
                photon(np)=p_old
              endif
! not active
!           else
!             write(92,*) 'not active'
            endif
!           if(np.eq.sum(ncreate(0:nt))) then
!         write(95,*) 'new'
!         write(95,*) jnudnu
!         write(96,*) 'new'
!         write(96,*) jnudnup
!           end if

          enddo
!$OMP END DO NOWAIT

!$OMP END PARALLEL
!         write(90,*) 'new'
!         write(90,*) jnudnu
!         write(91,*) 'new'
!         write(91,*) jnudnup
          if(fineiter) then
!           stop
            bolout=bolout+boloutp
            call diag_summ_uvoir(uvoir_fp)
            ndirect=ndirect+ndirectp
            nscat=nscat+nscatp
            nprob(nt)=nprobp
            nleak(nt)=nleakp
          endif

          call cpu_time(tm4)
          converge=-1.0d0
          converge1=0.0d0
!         seedcount = seedcount + sum(ncreate(0:nt))
!$OMP PARALLEL  PRIVATE(I,vol,nb,edot,conv)

!$OMP DO SCHEDULE(DYNAMIC,1)

!$OM& REDUCTION(+:converge1) REDUCTION(MAX:converge)
          do i=1,nctot
            vol=1.0d0/rhooft(rhov(i),teff(nt))

            do nb=1,nuvoir_bands
               emissivity(nb,i)=mean_emissivity(alpha_abs_exp(:,i)+alpha_ff(:,i),&
                         bp(:,i),mass(i)/vol,uvoir_band_names(nb))
            enddo

            tplasma(i)=-1.0d0
            edot=max(edep(i)+(edep_gamma(nt,i)+edep_pos(nt,i))/vol/dt(nt)/4.0d0/pi,1.d-10)
            kappa_abs(i)=edep(i)/(jnudnu(i)+1.d-32)/(mass(i)/vol)
            kappa_scat(i)=esca(i)/(jnudnu(i)+1.d-32)/(mass(i)/vol)

            trad(i)=radiation_temperature(jnudnu(i),1)
            tcolor(i)=color_temperature(jnudnu(i),nujnudnu(i))
            if (ntracks(i).gt.0) then
              tplasma(i)=plasma_temperature(edot,alpha_abs_exp(:,i)+alpha_ff(:,i),spect_bins_uvoir(:),trad(i))
            else
              tplasma(i)=mintemp
            endif

            temp(i)=max(tplasma(i),mintemp)
            conv=abs(temp(i)-temp_old(i))/(temp_old(i)+epstemp)
            if (ntracks(i).gt.100) then
              converge=max(converge,conv/(2.0d0/sqrt(ntracks(i)+eps)))
            endif
            converge1=converge1+conv*ntracks(i)
!           write(fout,501) i,zavg(i),temp_old(i)/1000.0d0,temp(i)/1000.0d0,&
!             tcolor(i)/1000.0d0,tplasma(i)/1000.0d0,&
!             conv/(2.0d0/sqrt(ntracks(i)+eps)),ntracks(i)
!           write(fout,502) kappa_abs(i),kappa_scat(i)
          enddo
!$OMP END DO NOWAIT

!$OMP END PARALLEL
          converge1=converge1/dble(sum(ntracks(:)))
          write(fout,503) converge,converge1

          call cpu_time(tm5)
       write(99,*) 'finished iteration:', niter
       write(99,*) 'saha: ',tm2-tm1
       write(99,*) 'preparing: ',tm3 -tm2
       write(99,*) 'tracking: ',tm4-tm3
       write(99,*) 'finishing: ',tm5-tm4
        enddo

        write(fout,601) nsim,sum(ncreate(1:nt))
        write(fout,602) nleak(nt),sum(nleak(1:nt))
        write(fout,603) nprob(nt),sum(nprob(1:nt))

        call diag_write_profiles(nt)

          call cpu_time(tm6)
        write(99,*) 'all timestep',tm6-tm0
      enddo
! 0 is beginning of time step.
! 1 beginning of iteration.
! 2 finished saha etc.
! 3 finished preparing photons, right before staring to track them.
! 4 finished tracking photons.
! 5 finished iteration.
! 6 finished timesteps.

      namef='spectrum_uvoir'
!     call diag_write_spectrum(namef,spect_uvoir,spect_bins_uvoir)

401   format('***** Iteration # ',I3,' *****')
501   format('#',I3,' <z>=',F5.2,'  Told=',F7.2,'  Tr=',F7.2,&
             '  Tc=',F7.2,'  Tp=',F7.2,'  conv=',1pe9.2,&
             '  Ntrk=',I8)
502   format('kappa_abs=',1pe10.2,'  kappa_scat=',1pe10.2)
503   format('Temperature converge/2sig=',1pe10.2,' weighted conv=',1pe10.2)
600   format('time step number ',I3,' from t=',F6.2,&
                                 ' days to t=',F6.2,' days')
601   format('simulated ',I10,' packets out of total ',I10,' created ')
602   format('leaked    ',I10,' packets out of total ',I10,' leaked  ')
603   format('problem in',I10,' packets out of total ',I10,' problems')

!     deallocate(rng)
      return
      end subroutine uvoir_transport

      function new_uvoir(nt,i,j,k,Etot,rng)
      integer , intent (in) :: nt,i,j,k
      real(8) , intent (in) :: Etot
      type(rng_t), intent(inout) :: rng
      type (epacket) :: new_uvoir
      real(8) :: z,v(3)
      integer :: ierr

!     call random_number(z)
      z = rng_uniform(rng)
      new_uvoir%t=times(nt)*z+times(nt+1)*(1.0d0-z)
      new_uvoir%r=random_location(i,j,k,teff(nt),rng)
      new_uvoir%n=random_unit_vec1(3,rng)
      new_uvoir%lam=photon_emission_LTE(emissivity(:,ind(i,j,k)),spect_bins_uvoir(:),rng)
      new_uvoir%hnu=lam2hnu(new_uvoir%lam)
      v=vofr(new_uvoir%r,teff(nt))

      new_uvoir%hnu=comoving2lab_transform_E(new_uvoir%hnu,new_uvoir%n,v,1)
      new_uvoir%lam=lam2hnu(new_uvoir%hnu)
      new_uvoir%Etot=comoving2lab_transform_E(Etot,new_uvoir%n,v,1)
      new_uvoir%n=comoving2lab_transform_n(new_uvoir%n,v,1)

      new_uvoir%direct=.true.
      new_uvoir%rng=rng

      return
      end function new_uvoir

      subroutine track_uvoir(p,nt,inmesh,intime,isabs,isprob,idiag,jnudnup,nujnudnup,edepp,escap,ntracksp)
!     type(rng_t), intent(inout) :: rng
      integer , intent (in) :: nt
      type (epacket) , intent (inout) :: p
      logical , intent (out) :: inmesh,intime,isabs,isprob
      logical , intent (in) :: idiag
      real(8) , intent (out) :: jnudnup(nctot),nujnudnup(nctot),edepp(nctot),escap(nctot)
      integer, intent(out) :: ntracksp(nctot)
      integer :: n,i,j,k,i1,j1,k1,ierr,m,nout,m1,cell
      real(8) :: v(3),vm(3),nm(3),rhom,Etotm,rcut(3),tcut,hnum,z,rad,lamm
      real(8) :: q,f,cost,phi,depfac,cmfac
      real(8) :: ds,ds_time,ds_edge,ds_event
      real(8) :: alpha_a,alpha_s,alpha_tot

      inmesh=.true.
      intime=.true.
      isprob=.false.
      isabs=.false.
      jnudnup=0.0d0
      nujnudnup=0.0d0
      edepp=0.0d0
      escap=0.0d0
      ntracksp=0

      n=0
      nout=0

      call findijk(p%r,teff(nt),i,j,k)

      ntracksp(ind(i,j,k))=ntracksp(ind(i,j,k))+1

      depfac=1.0d0/4.0d0/pi/dt(nt)

      do while (inmesh .and. intime .and. .not.isabs)

        ds_time=(times(nt+1)-p%t)*clight

        call cut_nearest_surface(p%r,p%n,p%t,nt,i,j,k,ds_edge,rcut,tcut,i1,j1,k1,isprob)

        if (isprob) exit

        cell=ind(i,j,k)

        vm=vofr(p%r,teff(nt))
        rhom=rhooft(rhov(cell),teff(nt))

        hnum=comoving2lab_transform_E(p%hnu,p%n,vm,2)
        Etotm=comoving2lab_transform_E(p%Etot,p%n,vm,2)
        lamm=lam2hnu(hnum)

        cmfac=(Etotm/p%Etot)

        m=find_index1(lamm,spect_bins_uvoir(:),ierr)

        if (ierr.gt.0) then
        nout=1
        endif

        alpha_s=alpha_scat(cell)+alpha_scat_exp(m,cell)
        alpha_a=alpha_ff(m,cell)+alpha_abs_exp(m,cell)

        alpha_tot=cmfac*(alpha_a+alpha_s)

!       call random_number(z)
        z = rng_uniform(p%rng)

        ds_event=-log(z)/(alpha_tot)

        ds=min(ds_time,ds_edge,ds_event)

        p%r=p%r+p%n*ds
        p%t=p%t+ds/clight

!       calc estimators for radiation energy density (Erad) and energey deposition (Edep)
!       Note: estimators are calculated in comoving frame. As ds and p%Etot are defined
!       in lab frame, an appropriate transformation is made by multypling by cmfac
        jnudnup(cell)=jnudnup(cell)+depfac*rhom*p%Etot*ds*cmfac**2.0d0
        nujnudnup(cell)=nujnudnup(cell)+depfac*rhom*(p%hnu/planck)*p%Etot*ds*cmfac**3.0d0
        edepp(cell)=edepp(cell)+depfac*rhom*alpha_a*p%Etot*ds*cmfac**2.0d0
        escap(cell)=escap(cell)+depfac*rhom*alpha_s*p%Etot*ds*cmfac**2.0d0

        if (ds.eq.ds_time) then
          intime=.false.
        elseif (ds.eq.ds_edge) then
          i=i1
          j=j1
          k=k1
          if (i.gt.nc1 .or. j.gt.nc2 .or. k.gt.nc3) inmesh=.false.
          if (i.lt.1   .or. j.lt.1   .or. k.lt.1)   inmesh=.false.
          if (inmesh)  ntracksp(ind(i,j,k))=ntracksp(ind(i,j,k))+1
        elseif (ds_event.eq.ds) then
          vm=vofr(p%r,teff(nt))
          hnum=comoving2lab_transform_E(p%hnu,p%n,vm,2)
          Etotm=comoving2lab_transform_E(p%Etot,p%n,vm,2)
!         call random_number(z)
          z = rng_uniform(p%rng)
          if (z.lt.alpha_s/(alpha_s+alpha_a)) then !! scattering
            nm(:)=random_unit_vec1(3,p%rng)
            Etotm=Etotm
          else                                     !! absorption and reemission`
            nm(:)=random_unit_vec1(3,p%rng)
            Etotm=Etotm
            lamm=photon_emission_LTE(emissivity(:,ind(i,j,k)),spect_bins_uvoir(:),p%rng)
            hnum=lam2hnu(lamm)
          endif
          p%hnu=comoving2lab_transform_E(hnum,nm,vm,1)
          p%lam=lam2hnu(p%hnu)
          p%Etot=comoving2lab_transform_E(Etotm,nm,vm,1)
          p%n=comoving2lab_transform_n(nm,vm,1)
        endif
      n=n+1      
      enddo

      return
      end subroutine track_uvoir

      real(8) function photon_emission_LTE(eta,spect_bins,rng)
      real(8) , intent(in) :: eta(:),spect_bins(:)
      type(rng_t), optional, intent(inout) :: rng
      real(8) :: emissivity(size(eta))
      real(8) :: z
      integer :: i
      

      if(present(rng)) then
        i=choose_from_probability_distribution(eta,rng)
        z = rng_uniform(rng)
      else
        i=choose_from_probability_distribution(eta)
        call random_number(z)
      endif
      
      photon_emission_LTE=spect_bins(i)*z+spect_bins(i+1)*(1.0d0-z)

      return
      end function photon_emission_LTE

      real(8) function lam2hnu(x)
      real(8) , intent(in) :: x
      
      lam2hnu=clight*planck/x

      return
      end function lam2hnu

      subroutine calc_Kasens_emissivity(ro,t,fracs,nfile)
      real(8) , intent(in) :: ro,t,fracs(niso)
      integer , intent(in) :: nfile
      real(8) :: ni(niso),nions(0:max_ion_levels,niso)
      real(8) :: partition(0:max_ion_levels,niso)
      real(8) :: ne,vol,xmass,tmp,totatoms,zavg,fnorm,reslow,reshigh
      real(8) :: fac(6),fac1(6),fac2(6),phi(6),phin(6),lam
      character(3) :: color(6)
      integer :: i,k,nc


      xmass=1.0d0
      vol=xmass/ro

      totatoms=xmass/(sum(iso(1:niso)%A*fracs(1:niso)))
      ni(:)=fracs(:)*totatoms/vol

      do i=1,49
      print*,'nfile,i=',nfile,i
      tmp=1000.0d0+dble(i-1)*500.0d0
      call sahaionization(ni(1:niso),iso(1:niso)%z, &
         tmp,ne,nions(0:max_ion_levels,1:niso), &
         partition(0:max_ion_levels,1:niso),zavg)
      call calc_planck_int(bp(:,1),fnorm,reslow,reshigh,spect_bins_uvoir(:),tmp)
      call expansion_opacity_LTE(alpha_abs_exp(:,1),alpha_scat_exp(:,1),t,tmp,&
       nions(0:max_ion_levels,1:niso),partition(0:max_ion_levels,1:niso),spect_bins_uvoir(:))
      call calc_freefree_abs(alpha_ff(:,1),tmp,ne,&
                  nions(0:niso,1:max_ion_levels),spect_bins_uvoir(:))

      fac1(:)=0.0d0
      fac2(:)=0.0d0
      phi(:)=0.0d0
      color(1)='B'
      color(2)='V'
      color(3)='I'
      color(4)='J'
      color(5)='H'
      color(6)='K'
      do k=1,nwavelengths
        lam=(spect_bins_uvoir(k)+spect_bins_uvoir(k+1))/2.0d0
        do nc=1,6
        phi(nc)=spectroscopic_filter(lam,color(nc),phin(nc))
        fac1(nc)=fac1(nc)+bp(k,1)*(alpha_scat_exp(k,1)+alpha_abs_exp(k,1))*phi(nc)
        fac2(nc)=fac2(nc)+phi(nc)*dspect_bins_uvoir(k)
        enddo
        if (tmp.eq.15000.0d0 .and. nfile.eq.103) then
          write(nfile+100,1111) lam/angstrom,bp(k,1)/dspect_bins_uvoir(k),&
          (alpha_scat_exp(k,1)+alpha_abs_exp(k,1)),alpha_ff(k,1),phi(1:6)
        endif
      enddo
        fac(:)=fac1(:)/fac2(:)/ro
        write(nfile,1111) tmp,zavg,fac(:)
      enddo

1111    format(10(1pe14.6))

      return
      end subroutine calc_Kasens_emissivity

      real(8) function mean_emissivity(alpha,bp,ro,color)
      real(8) , intent(in) :: alpha(:),bp(:),ro
      character(3) , intent(in) :: color
      real(8) :: lam,fac,phi,phin
      integer :: n
    
      fac=0.0d0
      phi=0.0d0

      do n=1,nwavelengths
        lam=(spect_bins_uvoir(n)+spect_bins_uvoir(n+1))/2.0d0
        phi=spectroscopic_filter(lam,color,phin)
        fac=fac+bp(n)*alpha(n)*phi
      enddo
      mean_emissivity=fac/phin/ro

      return
      end function mean_emissivity

      subroutine calc_alpha(ro,temp,t,fracs,nfile)
      real(8) , intent(in) :: ro,temp,t,fracs(niso)
      integer , intent(in) :: nfile
      real(8) :: ni(niso),nions(0:max_ion_levels,niso)
      real(8) :: partition(0:max_ion_levels,niso)
      real(8) :: ne,vol,xmass,tmp,totatoms,zavg,fnorm,reslow,reshigh
      real(8) :: fac(6),fac1(6),fac2(6),phi(6),phin(6),lam
      character(3) :: color(6)
      integer :: i,k,nc


      xmass=1.0d0
      vol=xmass/ro

      totatoms=xmass/(sum(iso(1:niso)%A*fracs(1:niso)))
      ni(:)=fracs(:)*totatoms/vol

      call sahaionization(ni(1:niso),iso(1:niso)%z, &
         temp,ne,nions(0:max_ion_levels,1:niso), &
         partition(0:max_ion_levels,1:niso),zavg)
      call calc_planck_int(bp(:,1),fnorm,reslow,reshigh,spect_bins_uvoir(:),temp)
      call expansion_opacity_LTE(alpha_abs_exp(:,1),alpha_scat_exp(:,1),t,temp,&
       nions(0:max_ion_levels,1:niso),partition(0:max_ion_levels,1:niso),spect_bins_uvoir(:))
      call calc_freefree_abs(alpha_ff(:,1),temp,ne,&
                  nions(0:niso,1:max_ion_levels),spect_bins_uvoir(:))

      do k=1,nwavelengths
        lam=(spect_bins_uvoir(k)+spect_bins_uvoir(k+1))/2.0d0
        write(nfile+100,1111) lam/angstrom,bp(k,1)/dspect_bins_uvoir(k),&
          (alpha_scat_exp(k,1)+alpha_abs_exp(k,1)),alpha_ff(k,1)
      enddo
1111  format(10(1pe14.6))

      return
      end subroutine calc_alpha


      end Module UvoirTransfer
