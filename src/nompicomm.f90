! $Id: nompicomm.f90,v 1.129 2006-07-28 11:54:26 ajohan Exp $

!!!!!!!!!!!!!!!!!!!!!!!
!!!  nompicomm.f90  !!!
!!!!!!!!!!!!!!!!!!!!!!!

!!!  Module with dummy MPI stuff.
!!!  This allows code to be run on single cpu machine

module Mpicomm

  use Cparam
  use Cdata, only: iproc,ipx,ipy,ipz,lroot

  implicit none

  include 'mpicomm.h'

  interface mpirecv_real
    module procedure mpirecv_real_scl
    module procedure mpirecv_real_arr
    module procedure mpirecv_real_arr2
  endinterface

  interface mpirecv_int
    module procedure mpirecv_int_scl
    module procedure mpirecv_int_arr
  endinterface
  
  interface mpisend_real
    module procedure mpisend_real_scl
    module procedure mpisend_real_arr
    module procedure mpisend_real_arr2
  endinterface
  
  interface mpisend_int
    module procedure mpisend_int_scl
    module procedure mpisend_int_arr
  endinterface

  interface mpibcast_logical
    module procedure mpibcast_logical_scl
    module procedure mpibcast_logical_arr
  endinterface

  interface mpibcast_int
    module procedure mpibcast_int_scl
    module procedure mpibcast_int_arr
  endinterface

  interface mpibcast_real
    module procedure mpibcast_real_scl
    module procedure mpibcast_real_arr
  endinterface

  interface mpibcast_double
    module procedure mpibcast_double_scl
    module procedure mpibcast_double_arr
  endinterface

  interface mpibcast_char
    module procedure mpibcast_char_scl
    module procedure mpibcast_char_arr
  endinterface

  interface mpireduce_sum_double
    module procedure mpireduce_sum_double_scl
    module procedure mpireduce_sum_double_arr
  endinterface

! Not possible because array version is used with
! a multi dimensional array!
!  interface mpireduce_sum
!    module procedure mpireduce_sum_scl
!    module procedure mpireduce_sum_arr
!  endinterface

  interface mpireduce_sum_int
    module procedure mpireduce_sum_int_scl
    module procedure mpireduce_sum_int_arr
  endinterface

  interface mpireduce_max
    module procedure mpireduce_max_scl
    module procedure mpireduce_max_arr
  endinterface

  interface mpiallreduce_max
    module procedure mpiallreduce_max_scl
    module procedure mpiallreduce_max_arr
  endinterface

  interface mpireduce_min
    module procedure mpireduce_min_scl
    module procedure mpireduce_min_arr
  endinterface

  interface mpireduce_or
    module procedure mpireduce_or_scl
    module procedure mpireduce_or_arr
  endinterface

  contains

!***********************************************************************
    subroutine mpicomm_init()
!
!  Before the communication has been completed, the nghost=3 layers next
!  to the processor boundary (m1, m2, n1, or n2) cannot be used yet.
!  In the mean time we can calculate the interior points sufficiently far
!  away from the boundary points. Here we calculate the order in which
!  m and n are executed. At one point, necessary(imn)=.true., which is
!  the moment when all communication must be completed.
!
!   6-jun-02/axel: generalized to allow for ny=1
!  23-nov-02/axel: corrected problem with ny=4 or less
!
      use General
      use Cdata, only: lmpicomm,iproc,ipx,ipy,ipz,lroot
!
!  sets iproc in order that we write in the correct directory
!
!  consistency check
!
      if (ncpus > 1) then
        call stop_it("Inconsistency: MPICOMM=nompicomm, but ncpus >= 2")
      endif
!
!  for single cpu machine, set processor to zero
!
      lmpicomm = .false.
      iproc = 0
      lroot = .true.
      ipx = 0
      ipy = 0
      ipz = 0
!
      call setup_mm_nn()
!
    endsubroutine mpicomm_init
!***********************************************************************
    subroutine initiate_isendrcv_shockbdry(f,ivar1_opt,ivar2_opt)
!
!  for one processor, use periodic boundary conditions
!  but in this dummy routine this is done in finalize_isendrcv_bdry
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer, optional :: ivar1_opt, ivar2_opt
!
      if (NO_WARN) print*,f(1,1,1,1)   !(keep compiler quiet)
!
    endsubroutine initiate_isendrcv_shockbdry
!***********************************************************************
    subroutine finalize_isendrcv_shockbdry(f,ivar1_opt,ivar2_opt)
!
!  apply boundary conditions
!
      use Cparam
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer, optional :: ivar1_opt, ivar2_opt
!
      if (NO_WARN) print*,f(1,1,1,1)   !(keep compiler quiet)
    endsubroutine finalize_isendrcv_shockbdry
!***********************************************************************
    subroutine initiate_isendrcv_bdry(f,ivar1_opt,ivar2_opt)
!
!  for one processor, use periodic boundary conditions
!  but in this dummy routine this is done in finalize_isendrcv_bdry
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer, optional :: ivar1_opt, ivar2_opt
!
      if (NO_WARN) print*,f       !(keep compiler quiet)
!
    endsubroutine initiate_isendrcv_bdry
!***********************************************************************
    subroutine finalize_isendrcv_bdry(f,ivar1_opt,ivar2_opt)
!
!  apply boundary conditions
!
      use Cparam
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer, optional :: ivar1_opt, ivar2_opt
!
      if (NO_WARN) print*,f       !(keep compiler quiet)
    endsubroutine finalize_isendrcv_bdry
!***********************************************************************
    subroutine initiate_shearing(f,ivar1_opt,ivar2_opt)
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer, optional :: ivar1_opt, ivar2_opt
!    
      if (NO_WARN) print*,f       !(keep compiler quiet)
!
    endsubroutine initiate_shearing
!***********************************************************************
    subroutine finalize_shearing(f,ivar1_opt,ivar2_opt)
!
!  for one processor, use periodic boundary conditions
!  but in this dummy routine this is done in finalize_isendrcv_bdry
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer, optional :: ivar1_opt, ivar2_opt
!
      double precision :: deltay_dy, frak, c1, c2, c3, c4, c5, c6
      integer :: ivar1, ivar2, displs
!
      ivar1=1; ivar2=mcom
      if (present(ivar1_opt)) ivar1=ivar1_opt
      if (present(ivar2_opt)) ivar2=ivar2_opt
!
!  Periodic boundary conditions in x, with shearing sheat
!
      if (nygrid==1) then !If 2D
        f( 1:l1-1,:,:,ivar1:ivar2) = f(l2i:l2,:,:,ivar1:ivar2)
        f(l2+1:mx,:,:,ivar1:ivar2) = f(l1:l1i,:,:,ivar1:ivar2)
      else
        deltay_dy=deltay/dy
        displs=int(deltay_dy)
        frak=deltay_dy-displs
        c1 = -          (frak+1.)*frak*(frak-1.)*(frak-2.)*(frak-3.)/120.
        c2 = +(frak+2.)          *frak*(frak-1.)*(frak-2.)*(frak-3.)/24.
        c3 = -(frak+2.)*(frak+1.)     *(frak-1.)*(frak-2.)*(frak-3.)/12.
        c4 = +(frak+2.)*(frak+1.)*frak          *(frak-2.)*(frak-3.)/12.
        c5 = -(frak+2.)*(frak+1.)*frak*(frak-1.)          *(frak-3.)/24.
        c6 = +(frak+2.)*(frak+1.)*frak*(frak-1.)*(frak-2.)          /120.
        f( 1:l1-1,m1:m2,:,ivar1:ivar2) = &
             c1*cshift(f(l2i:l2,m1:m2,:,ivar1:ivar2),-displs+2,2) &
            +c2*cshift(f(l2i:l2,m1:m2,:,ivar1:ivar2),-displs+1,2) &
            +c3*cshift(f(l2i:l2,m1:m2,:,ivar1:ivar2),-displs  ,2) &
            +c4*cshift(f(l2i:l2,m1:m2,:,ivar1:ivar2),-displs-1,2) &
            +c5*cshift(f(l2i:l2,m1:m2,:,ivar1:ivar2),-displs-2,2) &
            +c6*cshift(f(l2i:l2,m1:m2,:,ivar1:ivar2),-displs-3,2)  
        f(l2+1:mx,m1:m2,:,ivar1:ivar2) = &
             c1*cshift(f(l1:l1i,m1:m2,:,ivar1:ivar2), displs-2,2) &
            +c2*cshift(f(l1:l1i,m1:m2,:,ivar1:ivar2), displs-1,2) &
            +c3*cshift(f(l1:l1i,m1:m2,:,ivar1:ivar2), displs  ,2) &
            +c4*cshift(f(l1:l1i,m1:m2,:,ivar1:ivar2), displs+1,2) &
            +c5*cshift(f(l1:l1i,m1:m2,:,ivar1:ivar2), displs+2,2) &
            +c6*cshift(f(l1:l1i,m1:m2,:,ivar1:ivar2), displs+3,2) 
      endif
!
    endsubroutine finalize_shearing
!***********************************************************************
    subroutine radboundary_zx_recv(mrad,idir,Qrecv_zx)
!
!   2-jul-03/tony: dummy created
!
      integer :: mrad,idir
      real, dimension(mx,mz) :: Qrecv_zx
!
      if (NO_WARN) then
         print*,mrad,idir,Qrecv_zx(1,1)
      endif
!
    endsubroutine radboundary_zx_recv
!***********************************************************************
    subroutine radboundary_xy_recv(nrad,idir,Qrecv_xy)
!
!   2-jul-03/tony: dummy created
!
      integer :: nrad,idir
      real, dimension(mx,my) :: Qrecv_xy
!
      if (NO_WARN) then
         print*,nrad,idir,Qrecv_xy(1,1)
      endif
!
    endsubroutine radboundary_xy_recv
!***********************************************************************
    subroutine radboundary_zx_send(mrad,idir,Qsend_zx)
!
!   2-jul-03/tony: dummy created
!
      integer :: mrad,idir
      real, dimension(mx,mz) :: Qsend_zx
!
      if (NO_WARN) then
         print*,mrad,idir,Qsend_zx(1,1)
      endif
!
    endsubroutine radboundary_zx_send
!***********************************************************************
    subroutine radboundary_xy_send(nrad,idir,Qsend_xy)
!
!   2-jul-03/tony: dummy created
!
      integer :: nrad,idir
      real, dimension(mx,my) :: Qsend_xy
!
      if (NO_WARN) then
         print*,nrad,idir,Qsend_xy(1,1)
      endif
!
    endsubroutine radboundary_xy_send
!***********************************************************************
    subroutine radboundary_zx_sendrecv(mrad,idir,Qsend_zx,Qrecv_zx)
!
!   2-jul-03/tony: dummy created
!
      integer :: mrad,idir
      real, dimension(mx,mz) :: Qsend_zx,Qrecv_zx
!
      if (NO_WARN) then
         print*,mrad,idir,Qsend_zx(1,1),Qrecv_zx(1,1)
      endif
!
    endsubroutine radboundary_zx_sendrecv
!***********************************************************************
    subroutine radboundary_zx_periodic_ray(Qrad_zx,tau_zx, &
                                           Qrad_zx_all,tau_zx_all)
!
!  Trivial counterpart of radboundary_zx_periodic_ray() from mpicomm.f90
!
!  19-jul-05/tobi: coded
!
      real, dimension(nx,nz), intent(in) :: Qrad_zx,tau_zx
      real, dimension(nx,nz,0:nprocy-1) :: Qrad_zx_all,tau_zx_all

      Qrad_zx_all(:,:,ipy)=Qrad_zx
      tau_zx_all(:,:,ipy)=tau_zx

    endsubroutine radboundary_zx_periodic_ray
!***********************************************************************
    subroutine mpirecv_real_scl(bcast_array,nbcast_array,proc_src,tag_id)
!   
!  Receive real scalar from other processor.
!
!  02-jul-05/anders: dummy
!
      integer :: nbcast_array
      real :: bcast_array
      integer :: proc_src, tag_id
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc_src, tag_id
!      
    endsubroutine mpirecv_real_scl
!***********************************************************************
    subroutine mpirecv_real_arr(bcast_array,nbcast_array,proc_src,tag_id)
!   
!  Receive real array from other processor.
!
!  02-jul-05/anders: dummy
!
      integer :: nbcast_array
      real, dimension(nbcast_array) :: bcast_array
      integer :: proc_src, tag_id
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc_src, tag_id
!
    endsubroutine mpirecv_real_arr
!***********************************************************************
    subroutine mpirecv_real_arr2(bcast_array,nbcast_array,proc_src,tag_id)
!
!  Receive real array(:,:) from other processor.
!
!  02-jul-05/anders: dummy
!
      integer, dimension(2) :: nbcast_array
      real, dimension(nbcast_array(1),nbcast_array(2)) :: bcast_array
      integer :: proc_src, tag_id
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc_src, tag_id
!
    endsubroutine mpirecv_real_arr2
!***********************************************************************
    subroutine mpirecv_int_scl(bcast_array,nbcast_array,proc_src,tag_id)
!
!  Receive integer scalar from other processor.
!
!  02-jul-05/anders: dummy
!
      integer :: nbcast_array
      integer :: bcast_array
      integer :: proc_src, tag_id
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc_src, tag_id
!      
    endsubroutine mpirecv_int_scl
!***********************************************************************
    subroutine mpirecv_int_arr(bcast_array,nbcast_array,proc_src,tag_id)
!
!  Receive integer array from other processor.
!
!  02-jul-05/anders: dummy
!
      integer :: nbcast_array
      integer, dimension(nbcast_array) :: bcast_array
      integer :: proc_src, tag_id
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc_src, tag_id
!
    endsubroutine mpirecv_int_arr
!***********************************************************************
    subroutine mpisend_real_scl(bcast_array,nbcast_array,proc_rec,tag_id)
!
!  Send real scalar to other processor.
!
!  02-jul-05/anders: dummy
!
      integer :: nbcast_array
      real :: bcast_array
      integer :: proc_rec, tag_id
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc_rec, tag_id
!      
    endsubroutine mpisend_real_scl
!***********************************************************************
    subroutine mpisend_real_arr(bcast_array,nbcast_array,proc_rec,tag_id)
!
!  Receive real array from other processor.
!
!  02-jul-05/anders: dummy
!
      integer :: nbcast_array
      real, dimension(nbcast_array) :: bcast_array
      integer :: proc_rec, tag_id
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc_rec, tag_id
!
    endsubroutine mpisend_real_arr
!***********************************************************************
    subroutine mpisend_real_arr2(bcast_array,nbcast_array,proc_rec,tag_id)
!
!  Receive real array(:,:) from other processor.
!
!  02-jul-05/anders: dummy
!
      integer, dimension(2) :: nbcast_array
      real, dimension(nbcast_array(1),nbcast_array(2)) :: bcast_array
      integer :: proc_rec, tag_id
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc_rec, tag_id
!
    endsubroutine mpisend_real_arr2
!***********************************************************************
    subroutine mpisend_int_scl(bcast_array,nbcast_array,proc_rec,tag_id)
!
!  Send real scalar to other processor.
!
!  02-jul-05/anders: dummy
!
      integer :: nbcast_array
      integer :: bcast_array
      integer :: proc_rec, tag_id
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc_rec, tag_id
!      
    endsubroutine mpisend_int_scl
!***********************************************************************
    subroutine mpisend_int_arr(bcast_array,nbcast_array,proc_rec,tag_id)
!
!  Receive real array from other processor.
!
!  02-jul-05/anders: dummy
!
      integer :: nbcast_array
      integer, dimension(nbcast_array) :: bcast_array
      integer :: proc_rec, tag_id
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc_rec, tag_id
!
    endsubroutine mpisend_int_arr
!***********************************************************************
    subroutine mpibcast_logical_scl(lbcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      logical :: lbcast_array
      integer, optional :: proc
!    
      if (NO_WARN) print*, lbcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_logical_scl
!***********************************************************************
    subroutine mpibcast_logical_arr(lbcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      logical, dimension(nbcast_array) :: lbcast_array
      integer, optional :: proc
!    
      if (NO_WARN) print*, lbcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_logical_arr
!***********************************************************************
    subroutine mpibcast_int_scl(ibcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      integer :: ibcast_array
      integer, optional :: proc
!    
      if (NO_WARN) print*, ibcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_int_scl
!***********************************************************************
    subroutine mpibcast_int_arr(ibcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      integer, dimension(nbcast_array) :: ibcast_array
      integer, optional :: proc
!    
      if (NO_WARN) print*, ibcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_int_arr
!***********************************************************************
    subroutine mpibcast_real_scl(bcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      real :: bcast_array
      integer, optional :: proc
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_real_scl
!***********************************************************************
    subroutine mpibcast_real_arr(bcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      real, dimension(nbcast_array) :: bcast_array
      integer, optional :: proc
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_real_arr
!***********************************************************************
    subroutine mpibcast_double_scl(bcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      double precision :: bcast_array
      integer, optional :: proc
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_double_scl
!***********************************************************************
    subroutine mpibcast_double_arr(bcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      double precision, dimension(nbcast_array) :: bcast_array
      integer, optional :: proc
!
      if (NO_WARN) print*, bcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_double_arr
!***********************************************************************
    subroutine mpibcast_char_scl(cbcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      character :: cbcast_array
      integer, optional :: proc
!
      if (NO_WARN) print*, cbcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_char_scl
!***********************************************************************
    subroutine mpibcast_char_arr(cbcast_array,nbcast_array,proc)
!
      integer :: nbcast_array
      character, dimension(nbcast_array) :: cbcast_array
      integer, optional :: proc
!
      if (NO_WARN) print*, cbcast_array, nbcast_array, proc
!
    endsubroutine mpibcast_char_arr
!***********************************************************************
    subroutine mpiallreduce_max_arr(fmax_tmp,fmax,nreduce)
!
      integer :: nreduce
      real, dimension(nreduce) :: fmax_tmp, fmax
!
      fmax=fmax_tmp
    endsubroutine mpiallreduce_max_arr
!***********************************************************************
    subroutine mpiallreduce_max_scl(fmax_tmp,fmax)
!
      real :: fmax_tmp, fmax
!
      fmax=fmax_tmp
    endsubroutine mpiallreduce_max_scl
!***********************************************************************
    subroutine mpireduce_max_arr(fmax_tmp,fmax,nreduce)
!
      integer :: nreduce
      real, dimension(nreduce) :: fmax_tmp, fmax
!
      fmax=fmax_tmp
    endsubroutine mpireduce_max_arr
!***********************************************************************
    subroutine mpireduce_max_scl(fmax_tmp,fmax)
!
      real :: fmax_tmp, fmax
!
      fmax=fmax_tmp
    endsubroutine mpireduce_max_scl
!***********************************************************************
    subroutine mpireduce_min_arr(fmin_tmp,fmin,nreduce)
!
      integer :: nreduce
      real, dimension(nreduce) :: fmin_tmp, fmin
!
      fmin=fmin_tmp
    endsubroutine mpireduce_min_arr
!***********************************************************************
    subroutine mpireduce_min_scl(fmin_tmp,fmin)
!
      real :: fmin_tmp, fmin
!
      fmin=fmin_tmp
    endsubroutine mpireduce_min_scl
!***********************************************************************
    subroutine mpireduce_sum(fsum_tmp,fsum,nreduce)
!
      integer :: nreduce
      real, dimension(nreduce) :: fsum_tmp,fsum
!
      fsum=fsum_tmp
    endsubroutine mpireduce_sum
!!ajwm see interface block
!***********************************************************************
    subroutine mpireduce_sum_scl(fsum_tmp,fsum)
!
      real :: fsum_tmp,fsum
!
      fsum=fsum_tmp
    endsubroutine mpireduce_sum_scl
!***********************************************************************
    subroutine mpireduce_sum_double_arr(dsum_tmp,dsum,nreduce)
!
      integer :: nreduce
      double precision, dimension(nreduce) :: dsum_tmp,dsum
!
      dsum=dsum_tmp
    endsubroutine mpireduce_sum_double_arr
!***********************************************************************
    subroutine mpireduce_sum_double_scl(dsum_tmp,dsum)
!
      double precision :: dsum_tmp,dsum
!
      dsum=dsum_tmp
    endsubroutine mpireduce_sum_double_scl
!***********************************************************************
    subroutine mpireduce_sum_int_arr(fsum_tmp,fsum,nreduce)
!
!  12-jan-05/anders: dummy coded
!
      integer :: nreduce
      integer, dimension(nreduce) :: fsum_tmp,fsum
!
      fsum=fsum_tmp
!
    endsubroutine mpireduce_sum_int_arr
!***********************************************************************
    subroutine mpireduce_sum_int_scl(fsum_tmp,fsum)
!
!  16-sep-05/anders: adapted from mpireduce_sum_int
!
      integer :: fsum_tmp,fsum
!
      fsum=fsum_tmp
!
    endsubroutine mpireduce_sum_int_scl
!***********************************************************************
    subroutine mpireduce_or_arr(flor_tmp,flor,nreduce)
!
!  17-sep-05/anders: coded
!
      integer :: nreduce
      logical, dimension(nreduce) :: flor_tmp, flor
!
      flor=flor_tmp
!
    endsubroutine mpireduce_or_arr
!***********************************************************************
    subroutine mpireduce_or_scl(flor_tmp,flor)
!
!  17-sep-05/anders: coded
!
      logical :: flor_tmp, flor
!
      flor=flor_tmp
!
    endsubroutine mpireduce_or_scl
!***********************************************************************
    subroutine start_serialize()
    endsubroutine start_serialize
!***********************************************************************
    subroutine end_serialize()
    endsubroutine end_serialize
!***********************************************************************
    subroutine mpibarrier()
    endsubroutine mpibarrier
!***********************************************************************
    subroutine mpifinalize()
    endsubroutine mpifinalize
!***********************************************************************
    function mpiwtime()
!
!  Mimic the MPI_WTIME() timer function. On many machines, the
!  implementation through system_clock() will overflow after about 50
!  minutes, so MPI_WTIME() is better.
!
!   5-oct-2002/wolf: coded
!
      double precision :: mpiwtime
      integer :: count_rate,time
!
      call system_clock(COUNT_RATE=count_rate)
      call system_clock(COUNT=time)

      if (count_rate /= 0) then
        mpiwtime = (time*1.)/count_rate
      else                      ! occurs with ifc 6.0 after long (> 2h) runs
        mpiwtime = 0
      endif
!
    endfunction mpiwtime
!***********************************************************************
    function mpiwtick()
!
!  Mimic the MPI_WTICK() function for measuring timer resolution.
!
!   5-oct-2002/wolf: coded
!
      double precision :: mpiwtick
      integer :: count_rate
!
      call system_clock(COUNT_RATE=count_rate)
      if (count_rate /= 0) then
        mpiwtick = 1./count_rate
      else                      ! occurs with ifc 6.0 after long (> 2h) runs
        mpiwtick = 0
      endif
!
    endfunction mpiwtick
!***********************************************************************
    subroutine die_gracefully()
!
!  Stop... perform any necessary shutdown stuff.
!  29-jun-05/tony: coded
!
      call mpifinalize
      STOP 1                    ! Return nonzero exit status
    endsubroutine die_gracefully
!***********************************************************************
    subroutine stop_it(msg)
!
!  Print message and stop
!  6-nov-01/wolf: coded
!
      character (len=*) :: msg
!      
      if (lroot) write(0,'(A,A)') 'STOPPED: ', msg
      call mpifinalize
      STOP 1                    ! Return nonzero exit status
    endsubroutine stop_it
!***********************************************************************
    subroutine stop_it_if_any(stop_flag,msg)
!
!  Conditionally print message and stop.
!  22-nov-04/wolf: coded
!
      logical :: stop_flag
      character (len=*) :: msg
!
      if (stop_flag) call stop_it(msg)
!
    endsubroutine stop_it_if_any
!***********************************************************************
    subroutine transp(a,var)
!
!  Doing a transpose (dummy version for single processor)
!
!   5-sep-02/axel: adapted from version in mpicomm.f90
!
      real, dimension(nx,ny,nz) :: a
      real, dimension(nz) :: tmp_z
      real, dimension(ny) :: tmp_y
      integer :: i,j
      character :: var
!
      if (ip<10) print*,'transp for single processor'
!
!  Doing x-y transpose if var='y'
!
      if (var=='y') then
!
        if (ny>1) then
          do i=1,ny
            do j=i+1,ny
              tmp_z=a(i,j,:)
              a(i,j,:)=a(j,i,:)
              a(j,i,:)=tmp_z
            enddo
          enddo
        endif
!   
!  Doing x-z transpose if var='z'
!   
      elseif (var=='z') then
!
        if (nz>1) then
          do i=1,nz
            do j=i+1,nz
              tmp_y=a(i,:,j)
              a(i,:,j)=a(j,:,i)
              a(j,:,i)=tmp_y
            enddo
          enddo
        endif
!
      endif
!
    endsubroutine transp
!***********************************************************************
    subroutine fold_df(df,ivar1,ivar2)
!
!  Fold first ghost zone of df into main part of df.
!
!  15-may-2006/anders: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar) :: df
      integer :: ivar1,ivar2
!
      real, dimension (ny,nz) :: df_tmp_yz
      integer :: ivar
!
!  Fold z-direction first (including first ghost zone in x and y).
!
      if (nzgrid/=1) then
        df(l1-1:l2+1,m1-1:m2+1,n1,ivar1:ivar2)= &
            df(l1-1:l2+1,m1-1:m2+1,n1,ivar1:ivar2) + &
            df(l1-1:l2+1,m1-1:m2+1,n2+1,ivar1:ivar2)
        df(l1-1:l2+1,m1-1:m2+1,n2,ivar1:ivar2)= &
            df(l1-1:l2+1,m1-1:m2+1,n2,ivar1:ivar2) + &
            df(l1-1:l2+1,m1-1:m2+1,n1-1,ivar1:ivar2)
        df(l1-1:l2+1,m1-1:m2+1,n1-1,ivar1:ivar2)=0.0
        df(l1-1:l2+1,m1-1:m2+1,n2+1,ivar1:ivar2)=0.0
      endif
!
!  Then fold y-direction (including first ghost zone in x).
!
      if (nygrid/=1) then
        df(l1-1:l2+1,m1,n1:n2,ivar1:ivar2)= &
            df(l1-1:l2+1,m1,n1:n2,ivar1:ivar2) + &
            df(l1-1:l2+1,m2+1,n1:n2,ivar1:ivar2)
        df(l1-1:l2+1,m2,n1:n2,ivar1:ivar2)= &
            df(l1-1:l2+1,m2,n1:n2,ivar1:ivar2) + &
            df(l1-1:l2+1,m1-1,n1:n2,ivar1:ivar2)
!
!  With shearing boundary conditions we must take care that the information is
!  shifted properly before the final fold.
!
        if (lshear) then
          do ivar=ivar1,ivar2
            df_tmp_yz=df(l1-1,m1:m2,n1:n2,ivar)
            call fourier_shift_yz(df_tmp_yz,-deltay)
            df(l1-1,m1:m2,n1:n2,ivar)=df_tmp_yz
            df_tmp_yz=df(l2+1,m1:m2,n1:n2,ivar)
            call fourier_shift_yz(df_tmp_yz,+deltay)
            df(l2+1,m1:m2,n1:n2,ivar)=df_tmp_yz
          enddo
        endif
        df(l1-1:l2+1,m1-1,n1:n2,ivar1:ivar2)=0.0
        df(l1-1:l2+1,m2+1,n1:n2,ivar1:ivar2)=0.0
      endif
!
!  Finally fold the x-direction.
!
      if (nxgrid/=1) then
        df(l1,m1:m2,n1:n2,ivar1:ivar2)=df(l1,m1:m2,n1:n2,ivar1:ivar2) + &
            df(l2+1,m1:m2,n1:n2,ivar1:ivar2) 
        df(l2,m1:m2,n1:n2,ivar1:ivar2)=df(l2,m1:m2,n1:n2,ivar1:ivar2) + &
            df(l1-1,m1:m2,n1:n2,ivar1:ivar2) 
        df(l1-1,m1:m2,n1:n2,ivar1:ivar2)=0.0
        df(l2+1,m1:m2,n1:n2,ivar1:ivar2)=0.0
      endif
!
    endsubroutine fold_df
!***********************************************************************
    subroutine fold_f(f,ivar1,ivar2)
!
!  Fold first ghost zone of f into main part of f.
!
!  14-jun-2006/anders: adapted
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer :: ivar1, ivar2
!
      real, dimension (ny,nz) :: f_tmp_yz
      integer :: ivar
!
!  Fold z-direction first (including first ghost zone in x and y).
!
      if (nzgrid/=1) then
        f(l1-1:l2+1,m1-1:m2+1,n1,ivar1:ivar2)= &
            f(l1-1:l2+1,m1-1:m2+1,n1,  ivar1:ivar2) + &
            f(l1-1:l2+1,m1-1:m2+1,n2+1,ivar1:ivar2)
        f(l1-1:l2+1,m1-1:m2+1,n2,ivar1:ivar2)= &
            f(l1-1:l2+1,m1-1:m2+1,n2,  ivar1:ivar2) + &
            f(l1-1:l2+1,m1-1:m2+1,n1-1,ivar1:ivar2)
        f(l1-1:l2+1,m1-1:m2+1,n1-1,ivar1:ivar2)=0.0
        f(l1-1:l2+1,m1-1:m2+1,n2+1,ivar1:ivar2)=0.0
      endif
!
!  Then fold y-direction (including first ghost zone in x).
!
      if (nygrid/=1) then
        f(l1-1:l2+1,m1,n1:n2,ivar1:ivar2)=f(l1-1:l2+1,m1,n1:n2,ivar1:ivar2) + &
            f(l1-1:l2+1,m2+1,n1:n2,ivar1:ivar2)
        f(l1-1:l2+1,m2,n1:n2,ivar1:ivar2)=f(l1-1:l2+1,m2,n1:n2,ivar1:ivar2) + &
            f(l1-1:l2+1,m1-1,n1:n2,ivar1:ivar2)
!
!  With shearing boundary conditions we must take care that the information is
!  shifted properly before the final fold.
!
        if (lshear) then
          do ivar=ivar1,ivar2
            f_tmp_yz=f(l1-1,m1:m2,n1:n2,ivar)
            call fourier_shift_yz(f_tmp_yz,-deltay)
            f(l1-1,m1:m2,n1:n2,ivar)=f_tmp_yz
            f_tmp_yz=f(l2+1,m1:m2,n1:n2,ivar)
            call fourier_shift_yz(f_tmp_yz,+deltay)
            f(l2+1,m1:m2,n1:n2,ivar)=f_tmp_yz
          enddo
        endif
        f(l1-1:l2+1,m1-1,n1:n2,ivar1:ivar2)=0.0
        f(l1-1:l2+1,m2+1,n1:n2,ivar1:ivar2)=0.0
      endif
!
!  Finally fold the x-direction.
!
      if (nxgrid/=1) then
        f(l1,m1:m2,n1:n2,ivar1:ivar2)=f(l1,m1:m2,n1:n2,ivar1:ivar2) + &
            f(l2+1,m1:m2,n1:n2,ivar1:ivar2) 
        f(l2,m1:m2,n1:n2,ivar1:ivar2)=f(l2,m1:m2,n1:n2,ivar1:ivar2) + &
            f(l1-1,m1:m2,n1:n2,ivar1:ivar2) 
        f(l1-1,m1:m2,n1:n2,ivar1:ivar2)=0.0
        f(l2+1,m1:m2,n1:n2,ivar1:ivar2)=0.0
      endif
!
    endsubroutine fold_f
!***********************************************************************
    subroutine fourier_shift_yz(a_re,shift_y)
!
!  Performs a periodic shift in the y-direction of an entire y-z plane by
!  the amount shift_y. The shift is done in Fourier space for maximum
!  interpolation accuracy.
!
!  19-jul-06/anders: coded
!
      use Cdata, only: ky_fft
!
      real, dimension (ny,nz) :: a_re
      real :: shift_y
!
      complex, dimension(ny) :: ay
      real, dimension(ny,nz) :: a_im
      real, dimension(4*ny+15) :: wsavey
      integer :: n
!
!  Transform to Fourier space.
!
      call cffti(ny,wsavey)
      do n=1,nz
        ay=cmplx(a_re(:,n),0.0)
        call cfftf(ny,ay,wsavey)
        ay(2:ny)=ay(2:ny)*exp(cmplx(0.0,-ky_fft(2:ny)*shift_y))
        a_re(:,n)=real(ay)
        a_im(:,n)=aimag(ay)
      enddo
!
!  Back to real space.
!
      call cffti(ny,wsavey)
      do n=1,nz
        ay=cmplx(a_re(:,n),a_im(:,n))
        call cfftb(ny,ay,wsavey)
        a_re(:,n)=real(ay)/ny
      enddo
!
    endsubroutine fourier_shift_yz
!***********************************************************************
endmodule Mpicomm
