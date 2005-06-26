! $Id: nointerstellar.f90,v 1.15 2005-06-26 20:24:20 mee Exp $
!
!  Dummy module
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: linterstellar = .true.
!
!***************************************************************

module Interstellar

  use Cparam
  use Cdata

  implicit none

  include 'interstellar.inc'

  !namelist /interstellar_init_pars/ dummy
  !namelist /interstellar_run_pars/ dummy
 
  contains

!***********************************************************************
    subroutine register_interstellar()
!
!  19-nov-02/tony: coded
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_nointerstellar called twice')
      first = .false.
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: nointerstellar.f90,v 1.15 2005-06-26 20:24:20 mee Exp $")
!
!      if (nvar > mvar) then
!        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
!        call stop_it('Register_nointerstellar: nvar > mvar')
!      endif
!
    endsubroutine register_interstellar
!***********************************************************************
    subroutine initialize_interstellar(lstarting)
!
!  Perform any post-parameter-read initialization eg. set derived 
!  parameters
!
!  24-nov-02/tony: coded - dummy
!
      logical :: lstarting
!
! (to keep compiler quiet)
      if (NO_WARN) print*,lstarting
!
    endsubroutine initialize_interstellar
!***********************************************************************
    subroutine input_persistent_interstellar(id,lun,done)
!
!  Read in the stored time of the next SNI
!
      integer :: id,lun
      logical :: done
!
      if (NO_WARN) print*,id,lun,done
!
    endsubroutine input_persistent_interstellar
!***********************************************************************
    subroutine output_persistent_interstellar(lun)
!
!  Writes out the time of the next SNI
!
!
      integer :: lun
!
      if (NO_WARN) print*,lun
!
    endsubroutine output_persistent_interstellar
!***********************************************************************
    subroutine rprint_interstellar(lreset,lwrite)
!
!  reads and registers print parameters relevant to entropy
!
!   1-jun-02/axel: adapted from magnetic fields
!
      use Cdata
      use Sub
!
!      integer :: iname
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  write column where which magnetic variable is stored
!
      if (lwr) then
        write(3,*) 'i_taucmin=0'
      endif
!
      if (NO_WARN) print*,lreset
!
    endsubroutine rprint_interstellar
!!***********************************************************************
    subroutine read_interstellar_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat) .and. (NO_WARN)) print*,iostat
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine read_interstellar_init_pars
!***********************************************************************
    subroutine write_interstellar_init_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine write_interstellar_init_pars
!***********************************************************************
    subroutine read_interstellar_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat) .and. (NO_WARN)) print*,iostat
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine read_interstellar_run_pars
!***********************************************************************
    subroutine write_interstellar_run_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      if (NO_WARN) print*,unit
    endsubroutine write_interstellar_run_pars
!***********************************************************************
    subroutine pencil_criteria_interstellar()
! 
!  All pencils that the Interstellar module depends on are specified here.
! 
!  26-03-05/tony: coded
!
!
!     DUMMY
!
    endsubroutine pencil_criteria_interstellar
!***********************************************************************
    subroutine calc_heat_cool_interstellar(df,p,Hmax)
!
!  adapted from calc_heat_cool
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar), intent(in) :: df
      type (pencil_case), intent(in) :: p 
      real, dimension(nx), intent(in) :: Hmax 
!
! (to keep compiler quiet)
      if (NO_WARN) print*,'calc_heat_cool_interstellar',df,p,Hmax
!
    endsubroutine calc_heat_cool_interstellar
!***********************************************************************
    subroutine check_SN(f)
!
!  dummy routine for checking for SNe (interstellar)
!
    use Cdata
!
    real, dimension(mx,my,mz,mvar+maux) :: f
!
! (to keep compiler quiet)
      if (NO_WARN) print*,'SN check',f
!
    endsubroutine check_SN

endmodule interstellar
