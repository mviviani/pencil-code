! $Id: timestep_rkf.f90,v 1.6 2008-04-03 12:50:50 ajohan Exp $

module Timestep

  use Cparam
  use Cdata

  implicit none

  private

  public :: rk_2n, border_profiles, timestep_autopsy

  ! Parameters for adaptive time stepping
  real, parameter :: eps              = 1e-8
  real, parameter :: safety           = 0.9
  real, parameter :: dt_decrease      = -0.25
  real, parameter :: dt_increase      = -0.20
  real            :: errcon
!
!  border_prof_[x-z] could be of size n[x-z], but having the same
!  length as f() (in the given dimension) gives somehow more natural code.
!
  real, dimension(mx) :: border_prof_x=1.0
  real, dimension(my) :: border_prof_y=1.0
  real, dimension(mz) :: border_prof_z=1.0

  contains

!***********************************************************************
    subroutine rk_2n(f,df,p)
!
!  Runge-Kutta-Fehlberg accurate to 5th order
!  At the moment, itorder can be 1, 2, or 3.
!
!  22-jun-06/tony: coded
!
      use Mpicomm
      use Cdata
      use Messages
!!      use Particles_main
!!      use Interstellar, only: calc_snr_damp_int
!!      use Shear, only: advance_shear
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real :: ds
      real, dimension(1) :: dt1, dt1_local

      real :: errmax, tnew
      real :: dt_temp, dt_next, dt_did
      integer :: j,i

      ldt=.false.

      ! General error condition
      errcon = (5.0/safety)**(1.0/dt_increase)

      if (itorder/=5) &
        call fatal_error('rk_2n','itorder must be 5 for Runge-Kutta-Fehlberg')

!
!  dt_beta_ts may be needed in other modules (like Dustdensity) for fixed dt
!
!      if (.not. ldt) dt_beta_ts=dt*beta_ts
!

      if (linterstellar.or.lshear.or.lparticles) &
            call fatal_error("rk_2n", &
                   "Shear, interstallar and particles are not" // &
                   " yet supported by the adaptive rkf scheme")

      lfirst=.true.
      do i=1,10
        ! Do a Runge-Kutta step
        call rkck(f(:,:,:,1:mvar), df, p, errmax)
        ! Step succeeded so exit
        if (errmax <= safety) exit
        ! Step didn't succeed so decrease the time step
!        print*,"Decreasing"
        dt_temp = safety*dt*(errmax**dt_decrease)
        ! Don't decrease the time step by more than a factor of ten
        dt = sign(max(abs(dt_temp), 0.1*abs(dt)), dt)
        ! New time
        tnew = t+dt
        if (tnew == t) then
          ! Guard against infinitesimal time steps
          print*, 'WARNING: Timestep underflow in rkqs()'
        endif
      end do

!      print*,"errmax, errcon", errmax,errcon
      if (errmax > errcon) then
        ! Increase the time step
        dt_next = safety*dt*(errmax**dt_increase)
      else
        ! But not by more than a factor of 5
        dt_next = 5.0*dt
      endif

      ! Time step that was actually performed
      dt_did = dt

      if (ip<=6) print*,'TIMESTEP: iproc,dt=',iproc,dt  !(all have same dt?)
      ! Update the time
      t = t+dt
      ! Time step to try next time
      dt = dt_next
!
!  Time evolution of grid variables
!  (do this loop in pencils, for cache efficiency)
!
      do j=1,mvar; do n=n1,n2; do m=m1,m2
        f(l1:l2,m,n,j)=f(l1:l2,m,n,j)+df(l1:l2,m,n,j)
      enddo; enddo; enddo
!
    endsubroutine rk_2n
!***********************************************************************
    subroutine rkck(f, df, p, errmax)
    ! Explicit fifth order Runge--Kutta--Fehlberg time stepping
      use Cdata
      use Mpicomm, only: mpiallreduce_max
      use Equ
    ! RK parameters by Cash and Karp
      real, parameter :: b21      = 0.2
      real, parameter :: b31      = 0.075
      real, parameter :: b32      = 0.225
      real, parameter :: b41      = 0.3
      real, parameter :: b42      = -0.9
      real, parameter :: b43      = 1.2
      real, parameter :: b51      = -11.0 / 54.0
      real, parameter :: b52      = 2.5
      real, parameter :: b53      = -70.0 / 27.0
      real, parameter :: b54      = 35.0 / 27.0
      real, parameter :: b61      = 1631.0 / 55296.0
      real, parameter :: b62      = 175.0 / 512.0
      real, parameter :: b63      = 575.0 / 13824.0
      real, parameter :: b64      = 44275.0 / 110592.0
      real, parameter :: b65      = 253.0 / 4096.0
      real, parameter :: c1       = 37.0 / 378.0
      real, parameter :: c2       = 0.0
      real, parameter :: c3       = 250.0 / 621.0
      real, parameter :: c4       = 125.0 / 594.0
      real, parameter :: c5       = 0.0
      real, parameter :: c6       = 512.0 / 1771.0
      real, parameter :: dc1      = c1 - 2825.0 / 27648.0
      real, parameter :: dc2      = c2 - 0.0
      real, parameter :: dc3      = c3 - 18575.0 / 48384.0
      real, parameter :: dc4      = c4 - 13525.0 / 55296.0
      real, parameter :: dc5      = c5 - 277.0 / 14336.0
      real, parameter :: dc6      = c6 - 0.25

      real, dimension (mx,my,mz,mvar), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(out) :: df
      type (pencil_case), intent(inout) :: p
      real, allocatable, dimension(:,:,:,:,:) :: k
!      real, dimension(5,mx,my,mx,mvar) :: k
      real, dimension(nx) :: scal, err
      real, intent(inout) :: errmax
      real :: errmaxs
      integer :: j,lll
      char (len=20) :: timestep_scaling='cons_err'


      df=0.
      errmax=0.
      allocate(k(5,mx,my,mz,mvar))
      k=0.

      call pde(f,k(1,:,:,:,:),p)
      do j=1,mvar; do n=n1,n2; do m=m1,m2
          k(1,l1:l2,m,n,j) = dt*k(1,l1:l2,m,n,j)
      !                *border_prof_x(l1:l2)*border_prof_y(m)*border_prof_z(n)

      enddo; enddo; enddo

      lfirst=.false.

      call pde(f+b21*k(1,:,:,:,:), k(2,:,:,:,:),p)
      do j=1,mvar; do n=n1,n2; do m=m1,m2
          k(2,l1:l2,m,n,j) = dt*k(2,l1:l2,m,n,j)
      !                *border_prof_x(l1:l2)*border_prof_y(m)*border_prof_z(n)
      enddo; enddo; enddo



      call pde(f+b31*k(1,:,:,:,:)+&
                       b32*k(2,:,:,:,:), k(3,:,:,:,:),p)
      do j=1,mvar; do n=n1,n2; do m=m1,m2
          k(3,l1:l2,m,n,j) = dt*k(3,l1:l2,m,n,j)
      !                *border_prof_x(l1:l2)*border_prof_y(m)*border_prof_z(n)
      enddo; enddo; enddo


      call pde(f+b41*k(1,:,:,:,:)+&
                       b42*k(2,:,:,:,:)+&
                       b43*k(3,:,:,:,:), k(4,:,:,:,:),p)
      do j=1,mvar; do n=n1,n2; do m=m1,m2
          k(4,l1:l2,m,n,j) = dt*k(4,l1:l2,m,n,j)
      !                *border_prof_x(l1:l2)*border_prof_y(m)*border_prof_z(n)
      enddo; enddo; enddo


      call pde(f+b51*k(1,:,:,:,:)+&
                 b52*k(2,:,:,:,:)+&
                 b53*k(3,:,:,:,:)+&
                 b54*k(4,:,:,:,:), k(5,:,:,:,:),p)
      do j=1,mvar; do n=n1,n2; do m=m1,m2
          k(5,l1:l2,m,n,j) = dt*k(5,l1:l2,m,n,j)
      !                *border_prof_x(l1:l2)*border_prof_y(m)*border_prof_z(n)
      enddo; enddo; enddo


      errmaxs=0.
      call pde(f+b61*k(1,:,:,:,:)+&
                 b62*k(2,:,:,:,:)+&
                 b63*k(3,:,:,:,:)+&
                 b64*k(4,:,:,:,:)+&
                 b65*k(5,:,:,:,:), df,p)
      do j=1,mvar; do n=n1,n2; do m=m1,m2
          df(l1:l2,m,n,j) = dt*df(l1:l2,m,n,j)
      !                *border_prof_x(l1:l2)*border_prof_y(m)*border_prof_z(n)

          err = dc1*k(1,l1:l2,m,n,j) + dc2*k(2,l1:l2,m,n,j) + &
                dc3*k(3,l1:l2,m,n,j) + dc4*k(4,l1:l2,m,n,j) + &
                dc5*k(5,l1:l2,m,n,j) + dc6*df(l1:l2,m,n,j)

          df(l1:l2,m,n,j) = c1*k(1,l1:l2,m,n,j) + c2*k(2,l1:l2,m,n,j) + &
                            c3*k(3,l1:l2,m,n,j) + c4*k(4,l1:l2,m,n,j) + &
                            c5*k(5,l1:l2,m,n,j) + c6*df(l1:l2,m,n,j)

          ! Get the maximum error over the whole field
          !
          select case(timestep_scaling)
          case('per_var_err')
            !
            ! Per variable error
            !    
            scal=  ( &
                 sqrt(f(l1:l2,m,n,1)**2+f(l1:l2,m,n,2)**2)  + &
                 sqrt(k(1,l1:l2,m,n,1)**2 + k(1,l1:l2,m,n,2)**2) + &
                 1e-30)
            errmaxs = max(maxval(abs(err/scal)),errmaxs)
            !scal=  ( &
            !     abs(f(l1:l2,m,n,j))  + abs(k(1,l1:l2,m,n,j)) + 1e-30)
            !errmaxs = max(maxval(abs(err/scal)),errmaxs)
          case('cons_frac_err')
            !
            ! Constant fractional error
            !
            errmaxs = max(maxval(abs(err/f(l1:l2,m,n,j))),errmaxs)
          case('cons_err')
            !
            ! Constant error
            !
            do lll=1,nx
              if (j.eq.ilnrho) then
                scal(lll)=max(1e-8,abs(f(lll+l1-1,n,m,j)))            
              else              
                scal(lll)=max(1e-8,abs(f(lll+l1-1,n,m,j)))            
              endif
            enddo
            errmaxs = max(maxval(abs(err/scal)),errmaxs)
            !
          endselect
          !
        enddo; enddo; enddo
        !
        ! Divide your maximum error by the required accuracy
        !
        errmaxs=errmaxs/eps
        !
      call mpiallreduce_max(errmaxs,errmax)

  end subroutine rkck
!***********************************************************************
    subroutine timestep_autopsy
!
!  After the event, determine where the timestep too short occured
!  Kinda like playing Cluedo... Just without the dice.
!
!  25-aug-04/tony: coded
!
      use Cdata
      use Cparam
      use Mpicomm, only: start_serialize, end_serialize

      real :: dt_local, dt1_max_local, dt1_max_global
      integer :: l
      integer, dimension(1) :: turn

      if (lroot) then
        print*,"-------- General Description of Time Step Failure -----------"
        print*,"  it=",it
        print*,"  t=",t
        print*,"  Detailed breakdown not available for Adaptive Runge--Kutta--Fehlberg scheme"
      endif

! Procs testify in serial
!     call start_serialize
!!        if ( dt >= dt_local ) then
!          print*,"------------------ START OF CONFESSION (", iproc, ") ----------------------"
!            print*,"     "
!            print*,"------------------- END OF CONFESSION -----------------------"
!
!!          endif
!!        endif
!     call end_serialize

    endsubroutine timestep_autopsy
!***********************************************************************
    subroutine border_profiles()
!
!  Position-dependent quenching factor that multiplies rhs of pde
!  by a factor that goes gradually to zero near the boundaries.
!  border_frac is a 3-D array, separately for all three directions.
!  border_frac=1 would affect everything between center and border.
!
      use Cdata

      real, dimension(nx) :: xi
      real, dimension(ny) :: eta
      real, dimension(nz) :: zeta
      real :: border_width,lborder,uborder
!
!  x-direction
!
      border_prof_x(l1:l2)=1

      if ((border_frac_x(1)>0) .and. (.not. lperi(1))) then
        border_width=border_frac_x(1)*Lxyz(1)/2
        lborder=xyz0(1)+border_width
        xi=1-max(lborder-x(l1:l2),0.0)/border_width
        border_prof_x(l1:l2)=min(border_prof_x(l1:l2),xi**2*(3-2*xi))
      endif

      if ((border_frac_x(2)>0) .and. (.not. lperi(1))) then
        border_width=border_frac_x(2)*Lxyz(1)/2
        uborder=xyz1(1)-border_width
        xi=1-max(x(l1:l2)-uborder,0.0)/border_width
        border_prof_x(l1:l2)=min(border_prof_x(l1:l2),xi**2*(3-2*xi))
      endif
!
!  y-direction
!
      border_prof_y(m1:m2)=1

      if ((border_frac_y(1)>0) .and. (.not. lperi(2))) then
        border_width=border_frac_y(1)*Lxyz(2)/2
        lborder=xyz0(2)+border_width
        eta=1-max(lborder-y(m1:m2),0.0)/border_width
        border_prof_y(m1:m2)=min(border_prof_y(m1:m2),eta**2*(3-2*eta))
      endif

      if ((border_frac_y(2)>0) .and. (.not. lperi(2))) then
        border_width=border_frac_y(2)*Lxyz(2)/2
        uborder=xyz1(2)-border_width
        eta=1-max(y(m1:m2)-uborder,0.0)/border_width
        border_prof_y(m1:m2)=min(border_prof_y(m1:m2),eta**2*(3-2*eta))
      endif
!
!  z-direction
!
      border_prof_z(n1:n2)=1

      if ((border_frac_z(1)>0) .and. (.not. lperi(3))) then
        border_width=border_frac_z(1)*Lxyz(3)/2
        lborder=xyz0(3)+border_width
        zeta=1-max(lborder-z(n1:n2),0.0)/border_width
        border_prof_z(n1:n2)=min(border_prof_z(n1:n2),zeta**2*(3-2*zeta))
      endif

      if ((border_frac_z(2)>0) .and. (.not. lperi(3))) then
        border_width=border_frac_z(2)*Lxyz(3)/2
        uborder=xyz1(3)-border_width
        zeta=1-max(z(n1:n2)-uborder,0.0)/border_width
        border_prof_z(n1:n2)=min(border_prof_z(n1:n2),zeta**2*(3-2*zeta))
      endif
!
    endsubroutine border_profiles
!***********************************************************************

endmodule Timestep
