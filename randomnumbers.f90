       Module RandomNumbers
       use physical_constants , only : pi
       implicit none

       public :: rng_t, rng_seed, rng_uniform

! Dimension of the state
       integer, parameter :: ns = 4

! Default seed vector
       integer, parameter, dimension(ns) :: default_seed &
          = (/ 521288629, 362436069, 16163801, 1131199299 /)

! A data type for storing the state of the RNG
        type :: rng_t
         integer, dimension(ns) :: state = default_seed
        end type rng_t

contains

! Seeds the RNG using a single integer and a default seed vector.
       subroutine rng_seed(self, seed)
         type(rng_t), intent(inout) :: self
         integer, intent(in) :: seed(4)
         self%state(1:4) = seed(1:4)
!        self%state(2:ns) = default_seed(2:ns)
       end subroutine rng_seed

! Draws a uniform real number on [0,1].
       function rng_uniform(self) result(u)
         type(rng_t), intent(inout) :: self
         real(8) :: u
         integer :: imz

         imz = self%state(1) - self%state(3)
!        write(80,*) 'state1',self%state

         if (imz < 0) imz = imz + 2147483579
!        write(80,*) 'imz1',imz

         self%state(1) = self%state(2)
         self%state(2) = self%state(3)
         self%state(3) = imz
         self%state(4) = 69069 * self%state(4) + 1013904243
!        write(80,*) 'state2',self%state
         imz = imz + self%state(4)
!        write(80,*) 'imz2',imz
         u = 0.5d0 + 0.23283064d-9 * imz
!        write(80,*) 'u'
!        write(80,1111) u
1110  format(1000(I10))
1111  format(1000(1pe14.6))
       end function rng_uniform

       subroutine init_random_numbers
       real(8) :: zrand
       real(8) :: zrandvec(1:3)
      
!      call random_seed

       call random_number(zrand)

       end subroutine init_random_numbers



       integer function choose_from_probability_distribution(pdf,rng)
       real(8) , intent(in) , dimension (:) :: pdf
       type(rng_t), optional, intent(inout) :: rng
       real(8) :: zrand,cumprob
       integer n,i

       n=size(pdf)
       i=0
       cumprob=0.0d0
       

       if(present(rng)) then
         zrand = rng_uniform(rng)
       else
         call random_number(zrand)
       endif

       if(zrand.eq.0d0) then
         choose_from_probability_distribution=1
         return
       elseif(zrand.ge.1.00001d0) then
         print*,'zrand>1 catastrophy'
         print*, zrand
       elseif(zrand.ge.1d0) then
         choose_from_probability_distribution=n
         return
       endif

       do while (zrand.ge.cumprob)
         i=i+1
         if (i.gt.n) then
           print*,'err'
           write(98,*) zrand
           write(98,*) n
           cumprob=0d0
           do i=1,n
             cumprob=cumprob+pdf(i)
             write(98,*) pdf(i) ,cumprob
           end do
           stop
         endif
         cumprob=cumprob+pdf(i)
       enddo

       choose_from_probability_distribution=i

       return
       end function choose_from_probability_distribution

       function random_unit_vec1(n,rng)
       integer , intent(in) :: n
       real(8) :: random_unit_vec1(n)
       real(8) :: z(2) , vec(3) , vnorm , phi , teta
       type(rng_t), optional, intent(inout) :: rng

       if(present(rng)) then
         z(1) = rng_uniform(rng)
         z(2) = rng_uniform(rng)
       else
         call random_number(z)
       endif

       phi=2.0d0*pi*z(1)
       z(2)=1.0d0-2.0d0*z(2)

       if (n.eq.2) z(2)=0.0d0

       teta=acos(z(2))
       
       vec(1)=sin(teta)*cos(phi)
       vec(2)=sin(teta)*sin(phi)
       vec(3)=cos(teta)

       vnorm=sqrt(sum(vec(:)**2.0d0))
       random_unit_vec1=vec(1:n)/vnorm

       return
       end function random_unit_vec1


       end Module RandomNumbers
